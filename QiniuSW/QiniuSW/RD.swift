import Foundation
import UtilSW

public class RDownChunkSucc : NSObject {
    public var offset = 0
}

public class RDownProgress : NSObject {
    public var blockId = 0
    public var blockSize = 0
    public var ret = RDownChunkSucc()
}

public func cleanRDownProgresses(ps : [RDownProgress]) -> [RDownProgress] {
    return ps.reverse().distinct({ $0.blockId }).reverse()
}

public struct RDownExtra {
    public var blockSize = 1 << 22 // 4M
    public var chunkSize = 1 << 20 // 1M
    public var tryTimes = 3
    public var worker = 2
    public var progresses = [RDownProgress]()
    public var notify : RDownProgress -> () = ignore
    public init() { }
}

struct RDownBlockCtx {
    let rdownCtx : RDownCtx
    let blockId : Int
    let blockSize : Int
    let prev : RDownChunkSucc
    
    let notify : RDownProgress -> ()
    let blockStart : Int64
    
    init(
        _ rdownCtx : RDownCtx,
        _ blockId : Int,
        _ blockSize : Int,
        _ prev : RDownChunkSucc
    ) {
        self.rdownCtx = rdownCtx
        self.blockId = blockId
        self.blockSize = blockSize
        self.prev = prev
        self.notify = rdownCtx.extra.notify
        self.blockStart = Int64(blockId) * Int64(rdownCtx.extra.blockSize)
    }
    
    func chunkSize(offset : Int) -> Int {
        return min(rdownCtx.extra.chunkSize, blockSize - offset)
    }
    
    func requestRange(offset : Int, _ length : Int) -> NSURLRequest {
        let req = requestUrl(rdownCtx.url)
        req.HTTPMethod = "GET"
        let first = blockStart + Int64(offset)
        let last = first + Int64(length) - 1
        req.setRange(first, last)
        return req
    }
    
    func progress(offset : Int) -> RDownProgress {
        let p = RDownProgress()
        p.blockId = blockId
        p.blockSize = blockSize
        p.ret = RDownChunkSucc()
        p.ret.offset = offset
        return p
    }
    
    func chunk(offset : Int) -> Async<Ret<RDownChunkSucc>> {
        let req = requestRange(offset, chunkSize(offset))
        return rdownCtx.c.responseDownload(req)
        .bind(.Sync) { (resp, url) in
            if !resp.accepted {
                let msg = "Response chunk with status code \(resp.statusCode)"
                return ret(.Fail(Error(msg)))
            }
            let src = try! Channel(path: url.path!, oflag: O_RDONLY)
            let size = src.size
            return src.copyTo(
                self.rdownCtx.ch,
                srcOffset: 0,
                dstOffset: self.blockStart + Int64(offset)
            ).bindRet(.Sync) {
                let p = self.progress(offset + Int(size))
                self.notify(p)
                return .Succ(p.ret)
            }
        }
    }
    
    func loop(
        times : Int, _ prev : RDownChunkSucc, _ cur : Ret<RDownChunkSucc>
    ) -> Async<Ret<RDownChunkSucc>> {
        return delay(.Sync) {
            switch cur {
            case .Succ(let s):
                if s.offset == self.blockSize {
                    return ret(cur)
                } else {
                    return self.chunk(s.offset)
                    .bind(.Sync) { self.loop(times, s, $0) }
                }
            case .Fail(_):
                if times < self.rdownCtx.extra.tryTimes {
                    return self.loop(times + 1, prev, .Succ(prev))
                } else {
                    return ret(cur)
                }
            }
        }
    }
    
    func work() -> Async<Ret<RDownChunkSucc>> {
        return delay(.Utility) {
            self.loop(0, self.prev, .Succ(self.prev))
        }
    }
}

struct RDownCtx {
    let c : Client
    let url : String
    let ch : Channel
    let extra : RDownExtra
    let length : Int64
    
    let blockSize : Int
    let blockCount : Int
    let blockLastSize : Int
    let progresses : [RDownProgress]
    
    init(
        c : Client,
        url : String,
        ch : Channel,
        extra : RDownExtra,
        length : Int64
    ) {
        self.c = c
        self.url = url
        self.ch = ch
        self.extra = extra
        self.length = length
        
        self.blockSize = extra.blockSize
        self.blockCount =
            Int((length + Int64(blockSize - 1)) / Int64(blockSize))
        self.blockLastSize =
            Int(length - Int64(blockSize) * Int64(blockCount - 1))
        self.progresses = cleanRDownProgresses(extra.progresses)
    }
    
    func blockSizeOfId(blockId : Int) -> Int {
        return blockId == blockCount - 1 ? blockLastSize : blockSize
    }
    
    func chunkOfId(blockId : Int) -> RDownChunkSucc {
        if let index = progresses.indexOf({ $0.blockId == blockId }) {
            return progresses[index].ret
        } else {
            return RDownChunkSucc()
        }
    }
    
    func workOfId(blockId : Int) -> Async<Ret<RDownChunkSucc>> {
        return RDownBlockCtx(
            self, blockId, blockSizeOfId(blockId), chunkOfId(blockId)
        ).work()
    }
    
    func rdown() -> Async<Ret<()>> {
        let limit = min(extra.worker, blockCount)
        let works = (0 ..< blockCount).map(workOfId)
        return limitedParallel(limit, works).bindRet(.Sync) { rets in
            if (rets.all({ $0.check() })) {
                return .Succ(())
            } else {
                let msg = "Block not all done"
                return .Fail(Error(msg))
            }
        }
    }
}

extension Client {
    func responseDummy(url : String) -> Async<Ret<ContentRange>> {
        let req = requestUrl(url)
        req.HTTPMethod = "GET"
        req.setRange(0, 0)
        return responseData(req).bindRet(.Sync)
        { (resp, _) in
            if !resp.accepted {
                let msg = "Response dummy with status code \(resp.statusCode)"
                return .Fail(Error(msg))
            } else if !resp.acceptRange {
                let msg = "Response dummy do not have header Accept-Ranges:bytes"
                return .Fail(Error(msg))
            }
            return .Succ(resp.contentRange)
        }
    }

    public func rdown (
        url url : String,
        extra : RDownExtra,
        ch : Channel
    ) -> Async<Ret<()>> {
        return responseDummy(url).bind(.Sync) { r in
            switch r {
            case .Succ(let cr):
                return RDownCtx(c: self, url: url, ch: ch,
                    extra: extra, length: cr.complete).rdown()
            case .Fail(let e):
                return ret(.Fail(e))
            }
        }
    }
    
    public func rdownFile(
        url url : String,
        extra : RDownExtra,
        path : String
    ) -> Async<Ret<()>> {
        return rdown(
            url: url,
            extra: extra,
            ch: try! Channel(path: path, oflag: O_CREAT | O_WRONLY)
        )
    }
}

