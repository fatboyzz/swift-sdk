import Foundation
import UtilSW

public class StatSucc : NSObject, CustomJobj {
    public var qetag = ""
    public var fsize = 0
    public var putTime = 0
    public var mimeType = ""
    public var endUser = ""
    
    public func toJobj(d: NSMutableDictionary) {
        d.updateKey("qetag", newKey: "hash")
    }
    
    public func fromJobj(d: NSMutableDictionary) {
        d.updateKey("hash", newKey: "qetag")
    }
}

public class FetchSucc : NSObject, CustomJobj {
    public var qetag = ""
    public var key = ""
    
    public func toJobj(d: NSMutableDictionary) {
        d.updateKey("qetag", newKey: "hash")
    }
    
    public func fromJobj(d: NSMutableDictionary) {
        d.updateKey("hash", newKey: "qetag")
    }
}

public enum OpSucc {
    case Call
    case Stat(StatSucc)
}

public enum Op {
    case Stat(Entry)
    case Delete(Entry)
    case Copy(src: Entry, dst: Entry)
    case Move(src: Entry, dst: Entry)
    
    public func toUri() -> String {
        switch self {
        case .Stat(let e): return "/stat/\(e.encoded)"
        case .Delete(let e): return "/delete/\(e.encoded)"
        case .Copy(src: let src, dst: let dst):
            return "/copy/\(src.encoded)/\(dst.encoded)"
        case .Move(src: let src, dst: let dst):
            return "/move/\(src.encoded)/\(dst.encoded)"
        }
    }
}

private func encodeOps(ops : [Op]) -> Bytes {
    return ops.map { op in "op=\(op.toUri())" }
    .joinWithSeparator("&")
    .toUtf8()
}

private func parseItem(op : Op, item : NSDictionary) -> Ret<OpSucc> {
    let code = item.objectForKey("code")! as! Int
    switch (code / 100 == 2 , op) {
    case (false, _):
        let d = item.objectForKey("data")!
        let e = jobjToObj(Error(), d) as! Error
        return .Fail(e)
    case (_, .Stat(_)):
        let d = item.objectForKey("data")!
        let s = jobjToObj(StatSucc(), d) as! StatSucc
        return .Succ(.Stat(s))
    default:
        return .Succ(.Call)
    }
}

extension Client {
    func requestOp(url : String) -> NSMutableURLRequest {
        let req = requestUrl(url)
        req.HTTPMethod = "GET"
        req.setHeader("Content-Type", "application/x-www-form-urlencoded")
        req.setHeader("Authorization", mac.authorization(req))
        return req
    }
    
    private func requestBatch(ops : [Op]) -> NSMutableURLRequest {
        let url = "\(config.rsHost)/batch"
        let req = requestUrl(url)
        req.HTTPMethod = "POST"
        req.HTTPBody = encodeOps(ops).toNSData()
        req.setHeader("Content-Type", "application/x-www-form-urlencoded")
        req.setHeader("Authorization", mac.authorization(req))
        return req
    }
    
    private func rs<S>(zero : S, _ uri : String) -> Async<Ret<S>> {
        let req = requestOp(config.rsHost + uri)
        return responseRet(zero, req)
    }
    
    public func stat(en : Entry) -> Async<Ret<StatSucc>> {
        return rs(StatSucc(), Op.Stat(en).toUri())
    }

    public func delete(en : Entry) -> Async<Ret<()>> {
        return rs((), Op.Delete(en).toUri())
    }

    public func copy(src src : Entry, dst : Entry) -> Async<Ret<()>> {
        return rs((), Op.Copy(src: src, dst: dst).toUri())
    }

    public func move(src src : Entry, dst : Entry) -> Async<Ret<()>> {
        return rs((), Op.Move(src: src, dst: dst).toUri())
    }

    public func fetch(url url : String, dst : Entry) -> Async<Ret<FetchSucc>> {
        let host = config.ioHost
        let fetch = "/fetch/\(url.base64Urlsafe())"
        let to = "/to/\(dst.encoded)"
        let req = requestOp("\(host)\(fetch)\(to)")
        return responseRet(FetchSucc(), req)
    }

    public func changeMime(mime mime : String, en : Entry) -> Async<Ret<()>> {
        let host = config.rsHost
        let chgm = "/chgm/\(en.encoded)"
        let mime = "/mime/\(mime.base64Urlsafe())"
        let req = requestOp("\(host)\(chgm)\(mime)")
        return responseRet((), req)
    }
    
    public func batch(ops : [Op]) -> Async<[Ret<OpSucc>]> {
        let req = requestBatch(ops)
        return responseData(req).bindRet(.Sync)
        { (resp, data) -> [Ret<OpSucc>] in
            if resp.accepted {
                let items = jsonToJobj(data) as! [NSDictionary]
                return zip(ops, items).map(parseItem)
            } else {
                return [Ret<OpSucc>]()
            }
        }
    }
}
