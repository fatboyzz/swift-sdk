import Foundation
import UtilSW

let version = "1.0"

let userAgent = { () -> String in
    let info = NSProcessInfo.processInfo()
    let op = info.operatingSystemVersionString
    return "QiniuSwift \(version) \(op)"
}()

public struct Zone {
    let ioHost : String
    let upHost : String
}

public let zones = [
    Zone(ioHost: "http://iovip.qbox.me", upHost: "http://up.qiniu.com"),
    Zone(ioHost: "http://iovip-z1.qbox.me", upHost: "http://up-z1.qiniu.com")
]

public class Config {
    public let accessKey : String
    public let secretKey : String
    
    public let rsHost : String
    public let rsfHost : String
    public let apiHost : String
    
    public let ioHost : String
    public let upHost : String
    
    public init(
        accessKey : String,
        secretKey : String,
        zone : Zone = zones[0]
    ) {
        self.accessKey = accessKey
        self.secretKey = secretKey
        self.rsHost = "http://rs.qbox.me"
        self.rsfHost = "http://rsf.qbox.me"
        self.apiHost = "http://api.qiniu.com"
        self.ioHost = zone.ioHost
        self.upHost = zone.upHost
    }
}

class Mac {
    let accessKey : String
    let secretKey : Bytes
    
    init(_ c : Config) {
        self.accessKey = c.accessKey
        self.secretKey = c.secretKey.toUtf8()
    }
    
    func compute(data : Bytes) -> String {
        return data.hmacsha1(secretKey).base64Urlsafe().toString()
    }
    
    func sign(data : Bytes) -> String {
        return "\(accessKey):\(compute(data))"
    }
    
    func signWithData(data : Bytes) -> String {
        let safe = data.base64Urlsafe()
        return "\(accessKey):\(compute(safe)):\(safe.toString())"
    }
    
    func signWithObject<T>(o : T) -> String {
        return signWithData(objToJson(o).toBytes())
    }
    
    func signRequest(req : NSURLRequest) -> String {
        var buf = "\(req.URL!.pathAndQuery)\n".toUtf8()
        if let body = req.HTTPBody {
            buf.append(body.toBytes())
        }
        return "\(accessKey):\(compute(buf))"
    }
    
    func authorization(req : NSURLRequest) -> String {
        return "QBox \(signRequest(req))"
    }
}

public struct Entry {
    public let bucket : String
    public let key : String
    
    public init(bucket : String, key : String) {
        self.bucket = bucket
        self.key = key
    }
    
    public var scope : String {
        if key.isEmpty {
            return bucket
        } else {
            return "\(bucket):\(key)"
        }
    }
    
    var encoded : String {
        return scope.base64Urlsafe()
    }
}

public class Error : NSObject, ErrorType {
    public var error = ""
    
    public convenience init(_ error : String){
        self.init()
        self.error = error
    }
    
    public override var description: String { return error }
}

public enum Ret<T> {
    case Succ(T)
    case Fail(Error)
    
    public func map<R>(@noescape f : T throws -> R) throws -> Ret<R> {
        switch self {
        case .Succ(let t):
            return .Succ(try f(t))
        case .Fail(let e):
            return .Fail(e)
        }
    }
    
    public func pick() throws -> T {
        switch self {
        case .Succ(let t):
            return t
        case .Fail(let e):
            throw e
        }
    }
    
    public func check() -> Bool {
        switch self {
        case .Succ(_):
            return true
        case .Fail(_):
            return false
        }
    }
    
    public func toOptional() -> Optional<T> {
        switch self {
        case .Succ(let t):
            return .Some(t)
        case .Fail(_):
            return nil
        }
    }
}

func requestUrl(url : String) -> NSMutableURLRequest {
    let req = NSMutableURLRequest(URL: NSURL(string: url)!)
    req.setHeader("User-Agent", userAgent)
    return req
}

public class Client {
    let config : Config
    let mac : Mac
    let session : NSURLSession
    
    public init(_ config : Config) {
        self.config = config
        self.mac = Mac(config)
        let c = NSURLSessionConfiguration.defaultSessionConfiguration()
        c.requestCachePolicy = .ReloadIgnoringLocalCacheData
        self.session = NSURLSession(configuration: c)
    }
    
    public func token<T>(obj : T) -> String {
        return mac.signWithObject(obj)
    }
}

extension Client {
    func responseData(req : NSURLRequest) -> Async<HttpResponseData> {
        return session.responseData(req).bindRet(.Sync)
        { (resp, data) -> HttpResponseData in
            return (resp as! NSHTTPURLResponse, data)
        }
    }
    
    func responseDownload(req : NSURLRequest) -> Async<HttpResponseDownload> {
        return session.responseDownload(req).bindRet(.Sync)
        { (resp, url) -> HttpResponseDownload in
            return (resp as! NSHTTPURLResponse, url)
        }
    }
    
    func responseRet<Succ>(
        zero : Succ, _ req : NSURLRequest
    ) -> Async<Ret<Succ>> {
        return responseData(req).bindRet(.Sync)
        { (resp, data) -> Ret<Succ> in
            if resp.accepted {
                return .Succ(jsonToObj(zero, data))
            } else {
                return .Fail(jsonToObj(Error(), data))
            }
        }
    }
}

