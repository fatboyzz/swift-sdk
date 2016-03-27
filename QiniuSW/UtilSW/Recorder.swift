import Foundation

public class Recorder {
    let ch : Channel
    
    public init(path : String) {
        ch = Channel.init(path: path, oflag: O_APPEND)
    }
    
    public static func load(path : String) throws -> [NSData] {
        let input = NSInputStream(data: NSData(contentsOfFile: path)!)
        var ret = [NSData]()
        while input.hasBytesAvailable {
            let size = try input.readUInt32()
            let data = try input.readNSData(Int(size))
            ret.append(data)
        }
        return ret
    }

    public func append(data : NSData) {
        
    }
}