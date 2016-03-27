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
}
