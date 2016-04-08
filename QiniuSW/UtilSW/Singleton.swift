import Foundation

public struct Singleton<T> {
    let gen : () -> T
    var pred = 0
    var value : T? = nil
    
    public init(gen : () -> T) {
        self.gen = gen
    }
    
    public mutating func instance() -> T {
        return withUnsafeMutablePointer(&pred) { p in
            dispatch_once(&pred) {
                self.value = self.gen()
            }
            return value!
        }
    }
}
