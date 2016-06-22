import Foundation

public func qMain() -> dispatch_queue_t {
    return dispatch_get_main_queue()
}

public func qUtility() -> dispatch_queue_t {
    return dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)
}

public typealias DispatchBlock = () -> ()

// s : second
// ns : nano second
public enum Dispatcher {
    case Sync
    case SyncAfter(s : Double)
    case Async(q : dispatch_queue_t)
    case AsyncAfter(ns : Int64, q : dispatch_queue_t)
    case AsyncAfterWallTime(ns : Int64, q : dispatch_queue_t)
    case BarrierAsync(q : dispatch_queue_t)
    case Main
    case MainAfter(ns : Int64)
    case Utility
    case UtilityAfter(ns : Int64)
    case Custom(c : DispatchBlock -> ())
}

public func dispatch(d : Dispatcher, _ block : DispatchBlock) {
    switch d {
    case .Sync:
        block()
        break
    case .SyncAfter(let s):
        NSThread.sleepForTimeInterval(Double(s))
        dispatch(.Sync, block)
        break
    case .Async(let q):
        dispatch_async(q, block)
        break
    case .AsyncAfter(let ns, let q):
        let t = dispatch_time(DISPATCH_TIME_NOW, ns)
        dispatch_after(t, q, block)
        break
    case .AsyncAfterWallTime(let ns, let q):
        let t = dispatch_walltime(nil, ns)
        dispatch_after(t, q, block)
        break
    case .BarrierAsync(let q):
        dispatch_barrier_async(q, block)
        break
    case .Main:
        dispatch(.Async(q: qMain()), block)
        break
    case .MainAfter(let ns):
        dispatch(.AsyncAfter(ns: ns, q: qMain()), block)
        break
    case .Utility:
        dispatch(.Async(q: qUtility()), block)
        break
    case .UtilityAfter(let ns):
        dispatch(.AsyncAfter(ns: ns, q: qUtility()), block)
        break
    case .Custom(let c):
        c(block)
        break
    }
}

public class CancelToken {
    var cancel : Bool
    public init() { cancel = false }
    public func Cancel() { cancel = true }
    public func Canceled() -> Bool { return cancel }
}

class Context {
    let ct : CancelToken
    let timeout : NSTimeInterval
    let start : NSDate
    
    init(
        ct : CancelToken,
        timeout : NSTimeInterval,
        start : NSDate
    ) {
        self.ct = ct
        self.timeout = timeout
        self.start = start
    }
    
    func isTimeout() -> Bool {
        return timeout > 0 && start.timeIntervalSinceNow > timeout
    }
}

public enum Escape {
    case Success
    case Exception(ErrorType)
    case Cancelled
    case Timeout
}

public class Param<T> {
    let ctx : Context
    public let con : T -> ()
    public let econ : Escape -> ()
    
    init(
        ctx : Context,
        con : T -> () = ignore,
        econ : Escape -> () = ignore
    ) {
        self.ctx = ctx
        self.con = con
        self.econ = econ
    }
}

public class Async<T> {
    private let work : Param<T> -> ()
    
    @warn_unused_result
    public init(_ task : Param<T> -> ()) {
        work = { (p : Param<T>) in
            let ctx = p.ctx
            if ctx.ct.Canceled() {
                p.econ(.Cancelled)
                return
            }
            if ctx.isTimeout() {
                p.econ(.Timeout)
                return
            }
            task(p)
        }
    }
    
    @warn_unused_result
    public convenience init(
        _ task : Param<T> throws -> ()
    ) {
        self.init { (p : Param<T>) in
            do {
                try task(p)
            } catch let e {
                p.econ(.Exception(e))
            }
        }
    }
    
    @warn_unused_result
    public convenience init(
        _ con : () throws -> Async<T>
    ) {
        self.init { p in try con().work(p) }
    }
    
    @warn_unused_result
    public convenience init<R>(
        _ r : R, _ con : R throws -> Async<T>
    ) {
        self.init { p in try con(r).work(p) }
    }
    
    func run(
        ctx : Context,
        econ : Escape -> ()
    ) {
        let con = { (_ : T) in econ(.Success) }
        work(Param<T>(ctx: ctx, con: con, econ: econ))
    }
    
    public func run(
        ct ct : CancelToken = CancelToken(),
        timeout : NSTimeInterval = -1.0,
        econ : Escape -> () = ignore
    ) {
        let ctx = Context(ct : ct, timeout : timeout, start : NSDate())
        run(ctx, econ: econ)
    }
    
    public func runSync(
        ct ct : CancelToken = CancelToken(),
        timeout : NSTimeInterval = -1.0
    ) -> (T?, Escape) {
        let s = Semaphore(0)
        var ret : T? = nil
        var esc : Escape? = nil
        bindRet(.Sync) { t in
            ret = t
        }.run(ct: ct, timeout: timeout) { e in
            esc = e
            s.signal()
        }
        s.wait()
        return (ret, esc!)
    }
}

@warn_unused_result
public func ret<T>(value : T) -> Async<T> {
    return Async<T> { p in p.con(value) }
}

@warn_unused_result
public func dummy() -> Async<()> {
    return ret(())
}

@warn_unused_result
public func delay<T>(
    d : Dispatcher,
    _ con : () throws -> Async<T>
) -> Async<T> {
    return Async<T> { p in
        dispatch(d) { Async<T>(con).work(p) }
    }
}

@warn_unused_result
public func delayRet<T>(
    d : Dispatcher,
    _ con : () throws -> T
) -> Async<T> {
    return delay(d) { return ret(try con()) }
}

public extension Async {
    public func bind<U>(
        d : Dispatcher,
        _ con : T throws -> Async<U>
    ) -> Async<U> {
        return Async<U> { (p : Param<U>) in
            let ncon = { (t : T) in
                dispatch(d) { Async<U>(t, con).work(p) }
            }
            self.work(Param<T>(ctx: p.ctx, con: ncon, econ: p.econ))
        }
    }
    
    public func bindRet<U>(
        d : Dispatcher,
        _ con : T throws -> U
    ) -> Async<U> {
        return bind(d) { t in ret(try con(t)) }
    }
    
    public func bindClean(
        clean : Escape -> ()
    ) -> Async<T> {
        return Async<T> { (p : Param<T>) in
            let necon = { (e : Escape) in clean(e); p.econ(e) }
            self.work(Param<T>(ctx: p.ctx, con: p.con, econ: necon))
        }
    }
}

@warn_unused_result
public func parallel<T>(arr : [Async<T>]) -> Async<[T]> {
    return Async<[T]> { (p : Param) in
        let c = arr.count
        var rs : [T?] = Array(count: c, repeatedValue: nil)
        var finished = Int32(0)
        var failed = Int32(0)
        for i in 0 ..< rs.count {
            arr[i].bindRet(.Sync) { (r : T) in
                rs[i] = .Some(r)
                if OSAtomicIncrement32(&finished) == Int32(c) {
                    p.con(rs.flatMap(id))
                }
            }.run(p.ctx) { e in
                switch e {
                case .Success: break
                default:
                    if OSAtomicIncrement32(&failed) == 1 {
                        p.ctx.ct.Cancel()
                        p.econ(e)
                    }
                }
            }
        }
    }
}

class Worker<T> {
    let arr : [Async<T>]
    var skip : Int32
    var rs : [T?]
    
    init(_ arr : [Async<T>]) {
        self.arr = arr
        skip = 0
        rs = Array(count: arr.count, repeatedValue: nil)
    }
    
    func work() -> Async<()> {
        return delay(.Sync) {
            let index = Int(OSAtomicIncrement32(&self.skip)) - 1
            if index < self.arr.count {
                return self.arr[index].bind(.Sync) { r in
                    self.rs[index] = .Some(r)
                    return self.work()
                }
            } else {
                return ret(())
            }
        }
    }
}

@warn_unused_result
public func serial<T>(arr : [Async<T>]) -> Async<[T]> {
    let w = Worker(arr)
    return w.work().bindRet(.Sync) { _ in
        return w.rs.flatMap(id)
    }
}

@warn_unused_result
public func limitedParallel<T>(
    limit : Int, _ arr : [Async<T>]
) -> Async<[T]> {
    let w = Worker(arr)
    let ws = Array(count: limit, repeatedValue: w.work())
    return parallel(ws).bindRet(.Sync) { _ in
        return w.rs.flatMap(id)
    }
}
