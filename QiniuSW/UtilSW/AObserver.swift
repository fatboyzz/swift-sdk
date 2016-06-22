import Foundation

// abstract
public class AObserverBase : ReferenceEquatable {
    public func remove() {}
}

/// Always create new `AObserver<T>`
///
/// Store `AObserver<T>` as *weak* reference
///
///     weak var o : AObserver<T>?
///
/// If you want an array of weak value use `Weak<T>`
///
///     weak var os : [Weak<AObserver<T>>]
public class AObserver<T> : AObserverBase {
    weak var subject : ASubject<T>?
    let con : T -> ()
    
    public init(_ d : Dispatcher, con : T -> ()) {
        subject = nil
        self.con = { t in dispatch(d) { con(t) } }
    }
    
    public override func remove() {
        subject?.remove(self)
    }
}

public class ASubject<T> {
    var a : [AObserver<T>]
    let q : dispatch_queue_t

    public init() {
        a = [AObserver<T>]()
        q = dispatch_queue_create(
            "APool", DISPATCH_QUEUE_CONCURRENT
        )
    }

    public func add(o: AObserver<T>) {
        o.subject = self
        dispatch(.BarrierAsync(q: q)) {
            self.a.append(o)
        }
    }
    
    public func remove(o: AObserver<T>) {
        dispatch(.BarrierAsync(q: q)) {
            self.a = self.a.filter { $0 != o }
        }
    }
    
    public func notify(t: T) {
        dispatch(.Async(q: q)) {
            self.a.forEach { $0.con(t) }
        }
    }
}
