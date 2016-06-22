import Foundation
import UtilSW

public class PutPolicy : NSObject, CustomJns {
    public var scope : String
    public var deadline : UInt32 // Unit : second
    public var insertOnly : UInt16 = 0
    public var detectMime : UInt8 = 0
    public var callbackFetchKey : UInt8 = 0
    public var fsizeLimit : Int64 = 0
    public var mimeLimit = ""
    public var saveKey = ""
    public var callbackUrl = ""
    public var callbackHost = ""
    public var callbackBody = ""
    public var callbackBodyType = ""
    public var returnUrl = ""
    public var returnBody = ""
    public var persistentOps = ""
    public var persistentNotifyUrl = ""
    public var persistentPipeline = ""
    public var asyncOps = ""
    public var endUser = ""
    public var checkSum = ""
    
    public init(scope : String, deadline : UInt32) {
        self.scope = scope
        self.deadline = deadline
    }
    
    public func toJns(d: NSMutableDictionary) {
        let emptyKeys = d.allKeys.filter {
            empty(d.objectForKey($0)!)
        }
        d.removeObjectsForKeys(emptyKeys)
    }
    
    public func fromJns(d: NSMutableDictionary) {}
}

public func deadline(expire : NSTimeInterval) -> UInt32 {
    return UInt32(NSDate(timeIntervalSinceNow: expire).timeIntervalSince1970)
}

public enum CheckCrc {
    case No
    case Auto
    case Check
}

public struct PutExtra {
    public var customs = [String : String]()
    public var crc32 : UInt32 = 0
    public var checkCrc = CheckCrc.No
    public var mimeType = ""
    public init() {}
}

public class PutSucc : NSObject, CustomJns {
    public var qetag = ""
    public var key = ""
    
    public func toJns(d: NSMutableDictionary) {
        d.updateKey("qetag", newKey: "hash")
    }
    
    public func fromJns(d: NSMutableDictionary) {
        d.updateKey("hash", newKey: "qetag")
    }
}

enum Part {
    case KVPart(key : String, value : String)
    case DataPart(mime : String, data : NSData)
    
    private func dispositionLine(name : String) -> String {
        var s = "Content-Disposition: form-data; "
        if !name.isEmpty { s.appendContentsOf("name=\"\(name)\"") }
        s.appendContentsOf(crlf)
        return s
    }
    
    private func contentTypeLine(mime : String) -> String {
        var s = "Content-Type: "
        let m = mime.isEmpty ? "application/octet-stream" : mime
        s.appendContentsOf(m)
        s.appendContentsOf(crlf)
        return s
    }
    
    func toData() -> NSData {
        switch self {
        case .KVPart(key: let key, value: let value):
            let dl = dispositionLine(key)
            return "\(dl)\(crlf)\(value)".toUtf8().toNSData()
        case .DataPart(mime: let mime, data: let data):
            let dl = dispositionLine("file")
            let cl = contentTypeLine(mime)
            let head = "\(dl)\(cl)\(crlf)".toUtf8().toNSData()
            let ret = NSMutableData()
            ret.appendData(head)
            ret.appendData(data)
            return ret
        }
    }
}

func requestParts(url : String, _ parts : [Part]) -> NSMutableURLRequest {
    let boundary = NSUUID().UUIDString
    let boundaryLine = "\(crlf)--\(boundary)\(crlf)".toUtf8().toNSData()
    let boundaryEnd = "\(crlf)--\(boundary)--\(crlf)".toUtf8().toNSData()
    let contentType = "multipart/form-data; boundary=\(boundary)"
    let req = requestUrl(url)
    req.HTTPMethod = "POST"
    req.setHeader("Content-Type", contentType)
    let body = NSMutableData()
    for part in parts {
        body.appendData(boundaryLine)
        body.appendData(part.toData())
    }
    body.appendData(boundaryEnd)
    req.HTTPBody = body
    return req
}

struct PutCtx {
    let c : Client
    let token : String
    let key : String
    let data : NSData
    let extra : PutExtra
    
    func crcPart() -> Part? {
        switch extra.checkCrc {
        case .No:
            return .None
        case .Auto:
            let crc32 = data.toBytes().crc32IEEE()
            return .KVPart(key : "crc32", value : "\(crc32)")
        case .Check:
            return .KVPart(key : "crc32", value : "\(extra.crc32)")
        }
    }
    
    func parts() -> [Part] {
        var ps = [Part]()
        ps.append(.KVPart(key: "token", value: token))
        if !key.isEmpty { ps.append(.KVPart(key: "key", value: key)) }
        let customs = extra.customs
            .filter({ (k, v) in k.hasPrefix("x:")})
            .map { (k, v) -> Part in .KVPart(key: k, value: v) }
        ps.appendContentsOf(customs)
        if let crcp = crcPart() { ps.append(crcp) }
        ps.append(.DataPart(mime: extra.mimeType, data: data))
        return ps
    }
    
    func doput() -> Async<Ret<PutSucc>> {
        return delay(.Utility)
        { () -> Async<Ret<PutSucc>> in
            let c = self.c
            let ps = self.parts()
            let req = requestParts(c.config.upHost, ps)
            return c.responseRet(PutSucc(), req)
        }
    }
}

public extension Client {
    public func putData(
        token token : String,
        key : String,
        data : NSData,
        extra : PutExtra
    ) -> Async<Ret<PutSucc>> {
        return PutCtx(c: self, token: token, key: key,
            data: data, extra: extra).doput()
    }
    
    public func put(
        token token : String,
        key : String,
        ch : Channel,
        extra : PutExtra
    ) -> Async<Ret<PutSucc>> {
        return ch.readAt().bind(.Sync)
        { data -> Async<Ret<PutSucc>> in
            let nsdata = data.toNSData()
            return PutCtx(c: self, token: token, key: key,
                data: nsdata, extra: extra).doput()
        }
    }
    
    public func putFile(
        token token : String,
        key : String,
        path : String,
        extra : PutExtra
    ) -> Async<Ret<PutSucc>> {
        let ch = try! Channel(path: path, oflag: O_RDONLY)
        return put(token: token, key: key, ch: ch, extra: extra)
    }
}

public func publicUrl(
    domain domain : String, key : String
) -> String {
    return "http://\(domain)/\(key)"
}

extension Client {
    func attachToken(url : String) -> String {
        return "\(url)&token=\(mac.sign(url.toUtf8()))"
    }
    
    public func privateUrl(
        domain domain : String,
        _ key : String,
        _ deadline : Int32
    ) -> String {
        let url = "\(publicUrl(domain: domain, key: key))?e=\(deadline)"
        return attachToken(url)
    }
}
