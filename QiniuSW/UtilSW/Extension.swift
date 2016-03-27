import Foundation

public extension UInt16 {
    public func toBytes() -> Bytes {
        var ret = Bytes(2)
        ret.data.append(UInt8( self & UInt16(0x00FF)))
        ret.data.append(UInt8((self & UInt16(0xFF00)) >> 8))
        return ret
    }
}

public extension UInt32 {
    public func toBytes() -> Bytes {
        var ret = Bytes(4)
        ret.data.append(UInt8( self & UInt32(0x000000FF)))
        ret.data.append(UInt8((self & UInt32(0x0000FF00)) >> 8))
        ret.data.append(UInt8((self & UInt32(0x00FF0000)) >> 16))
        ret.data.append(UInt8((self & UInt32(0xFF000000)) >> 24))
        return ret
    }
}

public extension NSInputStream {
    public func readUInt16() throws -> UInt16 {
        var buf = Bytes([UInt8](count: 2, repeatedValue: 0))
        if read(&buf.data, maxLength: 2) < 2 {
            throw "readUInt16 fail"
        }
        return buf.toUInt16()
    }
    
    public func readUInt32() throws -> UInt32 {
        var buf = Bytes([UInt8](count: 4, repeatedValue: 0))
        if read(&buf.data, maxLength: 4) < 4 {
            throw "readUInt32 fail"
        }
        return buf.toUInt32()
    }
    
    public func readNSData(size : Int) throws -> NSData {
        let data = NSMutableData(length: size)!
        let p = UnsafeMutablePointer<UInt8>(data.bytes)
        if read(p, maxLength: size) < size {
            throw "readNSData fail"
        }
        return data
    }
}

public extension NSOutputStream {
    
}

public extension Optional {
    public func pick() -> Wrapped {
        return self!
    }
    
    public func check() -> Bool {
        switch self {
        case .None:
            return false
        default:
            return true
        }
    }
}

public extension NSData {
    public var count : Int { return length }
    
    public func toBytes() -> Bytes {
        var data = Array(count: length, repeatedValue: UInt8(0))
        getBytes(&data, length: data.count)
        return Bytes(data)
    }
    
    public func toString(
        encoding : NSStringEncoding = NSUTF8StringEncoding
    ) -> String {
        return String(data: self, encoding: encoding)!
    }
}

extension String : ErrorType {}

public extension String {
    public func toNSData() -> NSData {
        return dataUsingEncoding(NSUTF8StringEncoding)!
    }
    
    public func toUtf8() -> Bytes {
        return Bytes(Array(utf8))
    }
}

public extension SequenceType {
    typealias E = Self.Generator.Element
    
    public func all(@noescape pred : E -> Bool) -> Bool {
        for e in self { if !pred(e) { return false } }
        return true
    }
    
    public func any(@noescape pred : E -> Bool) -> Bool {
        for e in self { if pred(e) { return true } }
        return false
    }
    
    public func distinct<T : Hashable>(projection : E -> T) -> [E] {
        var s = Set<T>()
        var r = [E]()
        for e in self {
            let p = projection(e)
            if !s.contains(p) {
                s.insert(p)
                r.append(e)
            }
        }
        return r
    }
}

