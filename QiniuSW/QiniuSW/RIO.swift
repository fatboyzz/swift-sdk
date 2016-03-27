import Foundation
import UtilSW

public class RPutChunkSucc : NSObject {
    public var ctx = ""
    public var checksum = ""
    public var crc32 : UInt32 = 0
    public var offset = 0
    public var host = ""
}

public struct RPutProgress {
    public let blockId : Int
    public let blockSize : Int
    public let ret : RPutChunkSucc
}

public func cleanRPutProgresses(ps : [RPutProgress]) -> [RPutProgress] {
    return ps.reverse().distinct({ $0.blockId }).reverse()
}

public struct RPutExtra {
    public var customs = [String : String]()
    public var checkCrc = CheckCrc.No
    public var mimeType = ""
    public var blockSize = 1 << 22 // 4M
    public var chunkSize = 1 << 20 // 1M
    public var tryTimes = 3
    public var worker = 4
    public var progresses = [RPutProgress]()
    public var notify : RPutProgress -> () = ignore
    public init() { }
}

struct RPutBlockCtx {
    let rputCtx : RPutCtx
    let blockId : Int
    let blockSize : Int
    let prev : RPutChunkSucc
    let notify : RPutProgress -> ()
    
    let blockStart : Int64
    let mkblkUrl : String
    
    init(
        _ rputCtx : RPutCtx,
        _ blockId : Int,
        _ blockSize : Int,
        _ prev : RPutChunkSucc,
        _ notify : RPutProgress -> ()
    ) {
        self.rputCtx = rputCtx
        self.blockId = blockId
        self.blockSize = blockSize
        self.prev = prev
        self.notify = notify
        
        self.blockStart = Int64(rputCtx.extra.blockSize) * Int64(blockId)
        self.mkblkUrl = "\(rputCtx.c.config.upHost)/mkblk/\(blockSize)"
    }
    
    func chunkSize(offset : Int) -> Int {
        return min(rputCtx.extra.chunkSize, blockSize - offset)
    }
    
    func bputUrl(s : RPutChunkSucc) -> String {
        return "\(s.host)/bput/\(s.ctx)/\(s.offset)"
    }
    
    func requestChunk(
        url : String, _ offset : Int, _ body : NSData
    ) -> NSMutableURLRequest {
        let req = requestUrl(url)
        req.HTTPMethod = "POST"
        req.setHeader("Content-Type", "application/octet-stream")
        req.setHeader("Authorization", "UpToken \(rputCtx.token)")
        req.setHeader("Content-Length", "\(chunkSize(offset))")
        req.HTTPBody = body
        return req
    }
    
    func progress(ret : RPutChunkSucc) -> RPutProgress {
        return RPutProgress(
            blockId: blockId, blockSize: blockSize, ret: ret
        )
    }
    
    func chunk(
        url : String, _ offset : Int
    ) -> Async<Ret<RPutChunkSucc>> {
        return rputCtx.ch.readAt(self.blockStart, chunkSize(offset))
        .bind(.Sync) { (ddata : DData) in
            let crc32 = ddata.toBytes().crc32IEEE()
            let req = self.requestChunk(url, offset, ddata.toNSData())
            return self.rputCtx.c.responseRet(RPutChunkSucc(), req)
            .bindRet(.Sync) { (ret : Ret<RPutChunkSucc>) in
                switch ret {
                case .Succ(let s):
                    if s.crc32 == crc32 {
                        self.notify(self.progress(s))
                        return ret
                    } else {
                        return .Fail(Error("Invalid chunk crc32"))
                    }
                case .Fail(_):
                    return ret
                }
            }
        }
    }
    
    func loop(times : Int,
        _ prev : RPutChunkSucc, _ cur : Ret<RPutChunkSucc>
    ) -> Async<Ret<RPutChunkSucc>> {
        return delay(.Sync) {
            switch cur {
            case .Succ(let s):
                if s.offset == 0 {
                    return self.chunk(self.mkblkUrl, 0).bind(.Sync)
                    { self.loop(times, s, $0) }
                } else if s.offset == self.blockSize {
                    return ret(cur)
                } else {
                    return self.chunk(self.bputUrl(s), s.offset).bind(.Sync)
                    { self.loop(times, s, $0) }
                }
            case .Fail(_):
                if times < self.rputCtx.extra.tryTimes {
                    return self.loop(times + 1, prev, .Succ(prev))
                } else {
                    return ret(cur)
                }
            }
        }
    }
    
    func work() -> Async<Ret<RPutChunkSucc>> {
        return delay(.Utility) {
            self.loop(0, self.prev, .Succ(self.prev))
        }
    }
}

struct RPutCtx {
    let c : Client
    let token : String
    let key : String
    let extra : RPutExtra
    let ch : Channel
    
    let total : Int64
    let blockSize : Int
    let blockCount : Int
    let blockLastSize : Int
    let progresses : [RPutProgress]
    let notify : RPutProgress -> ()
    
    init(_ c : Client,
        _ token : String,
        _ key : String,
        _ extra : RPutExtra,
        _ ch : Channel
    ) {
        self.c = c
        self.token = token
        self.key = key
        self.extra = extra
        self.ch = ch
        
        self.total = ch.size
        self.blockSize = extra.blockSize
        self.blockCount = Int((ch.size + Int64(blockSize - 1)) / Int64(blockSize))
        self.blockLastSize = ch.size - Int64(blockSize) * Int64(blockCount - 1)
        self.progresses = cleanRPutProgresses(extra.progresses)
        
        let notifyLock = Mutex()
        self.notify = { (p : RPutProgress) in
            lock(notifyLock) { extra.notify(p) }
        }
    }
    
    func blockSizeOfId(blockId : Int) -> Int {
        return blockId == blockCount - 1 ? blockSize : blockLastSize
    }
    
    func chunkOfId(blockId : Int) -> RPutChunkSucc {
        if let index = progresses.indexOf({ $0.blockId == blockId }) {
            return progresses[index].ret
        } else {
            return RPutChunkSucc()
        }
    }
    
    func workOfId(blockId : Int) -> Async<Ret<RPutChunkSucc>> {
        return RPutBlockCtx(self, blockId, blockSizeOfId(blockId),
            chunkOfId(blockId), notify).work()
    }
    
    func mkfile(ss : [RPutChunkSucc]) -> Async<Ret<PutSucc>> {
        let host = c.config.upHost
        let mkfile = "/mkfile/\(total)"
        let key = "/key/\(self.key.base64Urlsafe())"
        let mime = extra.mimeType
        let mimeType = mime.isEmpty ? "" : "/mimeType/\(mime)"
        let customs = extra.customs
            .filter({ (k, v) in k.hasPrefix("x:")})
            .map { (k, v) in "/\(k)/\(v)" }
            .joinWithSeparator("")
        let url = "\(host)\(mkfile)\(key)\(mimeType)\(customs)"
        let req = requestUrl(url)
        req.HTTPMethod = "POST"
        req.setHeader("Content-Type", "text/plain")
        req.setHeader("Authorization", "UpToken \(token)")
        req.HTTPBody = ss.map({ $0.ctx })
            .joinWithSeparator(",").toUtf8().toNSData()
        return c.responseRet(PutSucc(), req)
    }
    
    func rput() -> Async<Ret<PutSucc>> {
        let limit = min(extra.worker, blockCount)
        let works = (0 ..< blockCount).map(workOfId)
        return limitedParallel(limit, Ret<RPutChunkSucc>(), works)
        .bind(.Sync) { rets -> Async<Ret<PutSucc>> in
            if rets.all({ $0.check() }) {
                let ss = rets.flatMap({ $0.toOptional() })
                return self.mkfile(ss)
            } else {
                return ret(.Fail(Error("Block not all done")))
            }
        }
    }
}

public extension Client {
    public func rput(
        token token : String,
        key : String,
        channel : Channel,
        extra : RPutExtra
    ) -> Async<Ret<PutSucc>> {
        return RPutCtx(self, token, key, extra, channel).rput()
    }
    
    public func rputFile(
        token token : String,
        key : String,
        path : String,
        extra : RPutExtra
    ) -> Async<Ret<PutSucc>> {
        let ch = Channel(path: path, oflag: O_RDONLY)
        return rput(token: token, key: key, channel: ch, extra: extra)
    }
}

