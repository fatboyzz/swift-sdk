import Foundation

public enum LogLevel : String {
    case Info = "Info"
    case Warn = "Warn"
    case Error = "Error"
}

public protocol LogTarget {
    func log(data : NSData)
}

public class LogFile : LogTarget {
    public let fd : Int32
    
    public init(_ fd : Int32) {
        self.fd = fd
    }
    
    public init(_ path : String) {
        fd = open(path, O_CREAT | O_APPEND | O_RDWR, 0o644)
    }
    
    public func log(data: NSData) {
        write(fd, data.bytes, data.count)
    }
}

public class Logger {
    let ts : [LogTarget]
    
    public init(_ ts : [LogTarget]) {
        self.ts = ts
    }
    
    public func add(
        level : LogLevel,
        _ log : String,
        _ file : String = __FILE__,
        _ line : Int = __LINE__,
        _ column : Int = __COLUMN__
    ) {
        let last = file.split("/").last!
        let s = "\(last):\(line):\(column):[\(level.rawValue)]\(log)"
        let data = s.toNSData()
        ts.forEach { $0.log(data) }
    }
}
