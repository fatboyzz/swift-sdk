import Foundation

public func ignore<T>(_ : T) {}
public func id<T>(t : T) -> T { return t }

public func posixError(
    code : Int32, userInfo : [NSObject:AnyObject]? = nil
) -> NSError {
    return NSError(
        domain: NSPOSIXErrorDomain,
        code: Int(code),
        userInfo: userInfo
    )
}

public func posixError(
    userInfo : [NSObject:AnyObject]? = nil
) -> NSError {
    return NSError(
        domain: NSPOSIXErrorDomain,
        code: Int(errno),
        userInfo: userInfo
    )
}

public func uninited<T>() -> T {
    return UnsafeMutablePointer<T>.alloc(sizeof(T.self)).move()
}

public func empty(obj : Any) -> Bool {
    switch obj {
    case let n as Int: return n == 0
    case let n as Int8: return n == 0
    case let n as Int16: return n == 0
    case let n as Int32: return n == 0
    case let n as Int64: return n == 0
    case let n as UInt: return n == 0
    case let n as UInt8: return n == 0
    case let n as UInt16: return n == 0
    case let n as UInt32: return n == 0
    case let n as UInt64: return n == 0
    case let f as Float: return f == 0
    case let d as Double: return d == 0
    case let n as NSNumber: return n == 0
    case let s as NSString: return s.length == 0
    case let a as NSArray: return a.count == 0
    case let d as NSDictionary: return d.count == 0
    case let o as NSObject: return o == NSNull()
    default: return false
    }
}


