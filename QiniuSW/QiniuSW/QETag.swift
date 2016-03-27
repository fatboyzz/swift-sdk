import Foundation
import UtilSW

public struct QETag {

    static func small(ch : Channel) -> Async<String> {
        return ch.readAt(0).bindRet(.Sync) { data -> String in
            let bs = Bytes([UInt8(0x16)]).concat(data.toBytes().sha1())
            return bs.base64Urlsafe().toString()
        }
    }

    static func big(ch : Channel, _ worker : Int) -> Async<String> {
        let total = ch.size
        let blockSize = 1 << 22 // 4M
        let blockCount = Int((total + Int64(blockSize) - 1) / Int64(blockSize))
        
        let works = (0 ..< blockCount).map
        { (blockId : Int) -> Async<Bytes> in
            let blockStart = Int64(blockId) * Int64(blockSize)
            return ch.readAt(blockStart, blockSize).bindRet(.Sync)
                { data -> Bytes in return data.toBytes().sha1() }
        }
        
        return limitedParallel(worker, Bytes(), works).bindRet(.Sync)
        { bs -> String in
            let sha = Bytes.concat(bs).sha1()
            let acc = Bytes([UInt8(0x96)]).concat(sha)
            return acc.base64Urlsafe().toString()
        }
    }

    static let hashThreshold = 1 << 22 // 4M
    
    public static func hash(
        ch ch : Channel, worker : Int = 4
    ) -> Async<String> {
        if ch.size <= Int64(hashThreshold) {
            return small(ch)
        } else {
            return big(ch, worker)
        }
    }
    
    public static func hash(
        path path : String, worker : Int = 4
    ) -> Async<String> {
        return hash(
            ch: Channel(path: path, oflag: O_RDONLY),
            worker : worker
        )
    }

}