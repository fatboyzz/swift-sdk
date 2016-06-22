import Foundation

public class Channel {
    public let fd : Int32
    public let canSeek : Bool
    public let ioType : dispatch_io_type_t
    public let size : Int64
    public let channel : dispatch_io_t
    
    public init(fd : Int32) {
        self.fd = fd
        canSeek = fileCanSeek(fd: fd)
        ioType = canSeek ? DISPATCH_IO_RANDOM : DISPATCH_IO_STREAM
        channel = dispatch_io_create(
            self.ioType , self.fd, qUtility(), { _ in close(fd) }
        )
        size = try! fileStat(fd: fd).st_size
    }
    
    public convenience init(
        path : String,
        oflag : Int32,
        mode : mode_t = 0o644
    ) throws {
        let fd = open(path, oflag, mode)
        if fd < 0 { throw posixError() }
        self.init(fd : fd)
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
                    p.econ(.Exception(posixError(err)))
                    return
                }
                if done { p.con() }
            }
        }
    }
    
    public func copyTo(
        dst : Channel,
        srcOffset : Int64 = 0,
        dstOffset : Int64 = 0,
        count : Int64 = Int64.max,
        limit : Int = 1 << 22, // 4M
        notify : (block : Int) -> () = ignore
    ) -> Async<()> {
        if count <= 0 { return dummy() }
        let reqc = Int(min(count, Int64(limit)))
        return readAt(srcOffset, reqc).bind(.Sync)
        { (data : DData) in
            let recvc = data.count
            if recvc == 0 { return dummy() }
            return dst.writeAt(dstOffset, data).bind(.Sync) {
                notify(block: recvc)
                return self.copyTo(dst,
                    srcOffset: srcOffset + recvc,
                    dstOffset: dstOffset + recvc,
                    count: count - recvc,
                    limit: limit,
                    notify: notify
                )
            }
        }
    }
}
