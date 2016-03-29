import Foundation

extension String {
    func base64Urlsafe() -> String {
        return toUtf8().base64Urlsafe().toString()
    }
}

extension NSMutableDictionary {
    func updateKey(oldKey : AnyObject, newKey : NSCopying) {
        if oldKey.isEqual(newKey) { return }
        if let v = objectForKey(oldKey) {
            removeObjectForKey(oldKey)
            setObject(v, forKey: newKey)
        }
    }
}

extension NSURL {
    var pathAndQuery : String {
        var buf = ""
        if let p = path {
            buf.appendContentsOf(p)
        }
        if let q = query {
            buf.appendContentsOf(q)
        }
        return buf
    }
}

extension NSMutableURLRequest {
    func setHeader(header : String, _ value : String) {
        setValue(value, forHTTPHeaderField: header)
    }
    
    func setRange(first : Int64, _ last : Int64) {
        setHeader("Range", "bytes=\(first)-\(last)")
    }
}

public struct ContentRange {
    let first : Int64
    let last : Int64
    let complete : Int64
}

extension NSHTTPURLResponse {
    var headers : [NSObject : AnyObject] {
        return allHeaderFields
    }
    
    var accepted : Bool {
        return statusCode / 100 == 2
    }
    
    var acceptRange : Bool {
        guard let v = headers["Accept-Ranges"] as? String else {
            return false
        }
        return v == "bytes"
    }
    
    var contentRange : ContentRange {
        let v = headers["Content-Range"] as! String
        let ss = v.split(" -/")
        return ContentRange(
            first: Int64(ss[1])!,
            last: Int64(ss[2])!,
            complete: Int64(ss[3])!
        )
    }
}
