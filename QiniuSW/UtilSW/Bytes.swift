import Foundation
import CommonCrypto

public struct Bytes {
    public var data : [UInt8]
    public var count : Int { return data.count }
    
    public init() {
        self.data = [UInt8]()
    }
    
    public init(_ data : [UInt8]) {
        self.data = data
    }
    
    public init(_ capacity : Int) {
        self.data = [UInt8]()
        self.data.reserveCapacity(capacity)
    }
    
    public init<T>(value : T) {
        var v = value
        self.data = withUnsafePointer(&v) { p in
            let bp = UnsafeBufferPointer(
                start: UnsafePointer<UInt8>(p),
                count: sizeof(T.self)
            )
            return [UInt8](bp)
        }
    }
    
    public static func concat<
        BS : SequenceType where BS.Generator.Element == Bytes
    >(bs : BS) -> Bytes {
        let total = bs.reduce(0) { $0 + $1.count }
        var ret = Bytes(total)
        ret.appends(bs)
        return ret
    }
    
    public mutating func append(data : Bytes) {
        self.data.appendContentsOf(data.data)
    }
    
    public mutating func appends<
        BS : SequenceType where BS.Generator.Element == Bytes
    >(datas : BS) {
        for data in datas { append(data) }
    }
    
    public func concat(data : Bytes) -> Bytes {
        var ret = Bytes(count + data.count)
        ret.append(self)
        ret.append(data)
        return ret
    }
    
    public func toValue<T>() -> T {
        let pb = UnsafePointer<UInt8>(data)
        let p = UnsafePointer<T>(pb)
        return p.memory
    }
    
    public func toUInt16() -> UInt16 {
        return UInt16(data[0]) |
        (UInt16(data[1]) << 8)
    }
    
    public func toUInt32() -> UInt32 {
        return UInt32(data[0]) |
        (UInt32(data[1]) << 8) |
        (UInt32(data[2]) << 16) |
        (UInt32(data[3]) << 24)
    }
    
    public func toNSData() -> NSData {
        return NSData(bytes: data, length: data.count)
    }
    
    public func toString(
        encoding : NSStringEncoding = NSUTF8StringEncoding
    ) -> String {
        return String(bytes: data, encoding: encoding)!
    }
    
    public func toDData() -> DData {
        return DData(dispatch_data_create(
            data, data.count, qUtility(), nil
        ))
    }
    
    public func sha1() -> Bytes {
        var buf = Array(
            count: Int(CC_SHA1_DIGEST_LENGTH),
            repeatedValue: UInt8(0)
        )
        CC_SHA1(data, CC_LONG(data.count), &buf)
        return Bytes(buf)
    }
    
    public func hmacsha1(key : Bytes) -> Bytes {
        var buf = Array(
            count: Int(CC_SHA1_DIGEST_LENGTH),
            repeatedValue: UInt8(0)
        )
        CCHmac(
            CCHmacAlgorithm(kCCHmacAlgSHA1),
            key.data, key.data.count,
            data, data.count,
            &buf
        )
        return Bytes(buf)
    }
    
    public func base64Urlsafe() -> Bytes {
        return Bytes(Base64.urlsafe.encode(data))
    }
    
    public func base64Normal() -> Bytes {
        return Bytes(Base64.normal.encode(data))
    }
    
    public func crc32IEEE(seed : UInt32 = 0) -> UInt32 {
        return Crc32.ieee.sum(seed, data)
    }
}

