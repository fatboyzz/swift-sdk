import Foundation

public func ignore<T>(_ : T) {}
public func id<T>(t : T) -> T { return t }

public func chr(u : UnicodeScalar) -> UInt8 {
    return UInt8(u.value)
}

public func ord(u : UInt8) -> UnicodeScalar {
    return UnicodeScalar(u)
}

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
