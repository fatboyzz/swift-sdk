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

public func fileStat(path path : String) throws -> stat {
    var buf = stat()
    if stat(path, &buf) == -1 {
        throw posixError()
    }
    return buf
}

public func fileStat(fd fd : Int32) throws -> stat {
    var buf = stat()
    if fstat(fd, &buf) == -1 {
        throw posixError()
    }
    return buf
}

public func fileCanSeek(fd fd : Int32) -> Bool {
    return lseek(fd, 0, SEEK_CUR) != -1
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


public protocol ReferenceEquatable : class, Equatable {}

public func ==<T : ReferenceEquatable>(lhs : T, rhs : T) -> Bool {
    return lhs === rhs
}

public class Weak<T : AnyObject> {
    public weak var value : T?
    public init() { self.value = nil }
    public init(_ value : T) { self.value = value }
}

