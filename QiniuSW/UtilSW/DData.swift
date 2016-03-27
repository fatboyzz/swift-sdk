import Foundation

public struct DData {
    let data : dispatch_data_t
    
    public var count : Int {
        return dispatch_data_get_size(data)
    }
    
    public init() {
        self.data = dispatch_data_empty
    }
    
    public init(_ data : dispatch_data_t) {
        self.data = data
    }
    
    public func toBytes() -> Bytes {
        var dst = Array(count: count, repeatedValue: UInt8(0))
        dispatch_data_apply(data)
        { (_, offset, src, count) -> Bool in
            memcpy(&dst[offset], src, count)
            return true
        }
        return Bytes(dst)
    }
    
    public func toNSData() -> NSData {
        let dst = NSMutableData(length: count)!
        let p = UnsafeMutablePointer<()>(dst.bytes)
        dispatch_data_apply(data)
        { (_, offset, src, count) -> Bool in
            memcpy(p.advancedBy(offset), src, count)
            return true
        }
        return dst
    }
    
    public func concat(other : DData) -> DData {
        return DData(dispatch_data_create_concat(data, other.data))
    }
}

