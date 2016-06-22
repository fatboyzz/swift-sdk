import Foundation

public class Semaphore {
    let sem : dispatch_semaphore_t
    
    public init(_ value : Int) {
        sem = dispatch_semaphore_create(value)
    }
    
    public func signal() {
        dispatch_semaphore_signal(sem)
    }
    
    public func wait(
        timeout : dispatch_time_t = DISPATCH_TIME_FOREVER
    ) {
        dispatch_semaphore_wait(sem, timeout)
    }
}

public class Mutex {
    let sem : dispatch_semaphore_t
    
    public init() {
        sem = dispatch_semaphore_create(1)
    }
    
    public func lock() {
        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER)
    }
    
    public func unlock() {
        dispatch_semaphore_signal(sem)
    }
}

public func lock<T>(
    m : Mutex, @noescape _ block: () -> T
) -> T {
    m.lock()
    defer { m.unlock() }
    return block()
}

public func lock<T>(
    m : Mutex, @noescape _ block : () throws -> T
) throws -> T {
    m.lock()
    defer { m.unlock() }
    return try block()
}
