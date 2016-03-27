import Foundation

public class Channel {
    public let fd : Int32
    public let canSeek : Bool
    public let ioType : dispatch_io_type_t
    public let size : Int64
    public let channel : dispatch_io_t
    
    static func canSeek(fd : Int32) -> Bool {
        let pos = lseek(fd, 0, SEEK_CUR)
        return pos != -1
    }
    
    static func ioType(canSeek : Bool) -> dispatch_io_type_t {
        if canSeek {
            return DISPATCH_IO_RANDOM
        } else {
            return DISPATCH_IO_STREAM
        }
    }
    
    static func size(channel : dispatch_io_t) -> Int64 {
        let fd = dispatch_io_get_descriptor(channel)
        var buf = stat()
        fstat(fd, &buf)
        return buf.st_size
    }
    
    public init(fd : Int32) {
        self.fd = fd
        self.canSeek = Channel.canSeek(self.fd)
        self.ioType = Channel.ioType(self.canSeek)
        self.channel = dispatch_io_create(
            self.ioType , self.fd, qUtility(), {err in close(fd)}
        )
        self.size = Channel.size(self.channel)
    }
    
    public convenience init(path : String, oflag : Int32) {
        self.init(fd : open(path, oflag))
    }
    
    deinit {
        dispatch_io_close(channel, DISPATCH_IO_STOP)
    }
    
    public func readAt(
        offset : Int64 = 0, _ count : Int = Int.max
    ) -> Async<DData> {
        return Async<DData> { (p : Param<DData>) in
            var acc = DData()
            dispatch_io_read(
                self.channel, offset, count, qUtility()
            ) { (done, data, err) in
                if err > 0 {
                    p.econ(.Exception(posixError(err)))
                    return
                }
                acc = acc.concat(DData(data))
                if done { p.con(acc) }
            }
        }
    }
    
    public func writeAt(
        offset : Int64 = 0, _ data : DData
    ) -> Async<()> {
        return Async<()> { (p : Param<()>) in
            dispatch_io_write(
                self.channel, offset, data.data, qUtility()
            ) { (done, _, err) in
                if err > 0 {
                    let e = NSError(domain: NSPOSIXErrorDomain, code: Int(err), userInfo: nil)
                    p.econ(.Exception(e))
                    return
                }
                if done { p.con() }
            }
        }
    }
    
    public func copyTo(
        other : Channel, srcOffset : Int64 = 0, dstOffset : Int64 = 0,
        count : Int = Int.max, limit : Int = 1 << 22 // 4M
    ) -> Async<()> {
        if count <= 0 { return ret(()) }
        let reqc = min(count, limit)
        return readAt(srcOffset, reqc).bind(.Sync)
        { (data : DData) in
            let recvc = data.count
            if recvc == 0 { return ret(()) }
            return other.writeAt(dstOffset, data).bind(.Sync)
            {
                return self.copyTo(other,
                    srcOffset: srcOffset + recvc,
                    dstOffset: dstOffset + recvc,
                    count: count - recvc,
                    limit: limit
                )
            }
        }
    }
    
}
