import Foundation

public protocol Recorder {
    static func load(path : String) throws -> [NSData]
    func append(data : NSData) throws
}

public class FileRecorder : Recorder {
    public static func load(path : String) throws -> [NSData] {
        let all = NSData(contentsOfFile: path)!
        var ret = [NSData]()
        var offset = 0
        while offset < all.length {
            let lenData = all.subdataWithRange(
                NSRange(offset ..< (offset + 4))
            )
            let len = lenData.toValue() as Int32
            offset += 4
            let data = all.subdataWithRange(
                NSRange(offset ..< offset + Int(len))
            )
            offset += Int(len)
            ret.append(data)
        }
        return ret
    }
    
    let fd : Int32
    
    public init(path : String) {
        fd = open(path, O_APPEND)
    }
    
    deinit {
        close(fd)
    }

    public func append(data : NSData) throws {
        var len = Int32(data.length)
        var v = [iovec](count: 2, repeatedValue: iovec())
        withUnsafeMutablePointer(&len) { p in
            v[0].iov_base = UnsafeMutablePointer<Void>(p)
            v[0].iov_len = sizeofValue(len)
            v[1].iov_base = UnsafeMutablePointer<Void>(data.bytes)
            v[1].iov_len = data.length
            writev(fd, v, Int32(v.count))
        }
    }
}
