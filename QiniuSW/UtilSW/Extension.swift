import Foundation

public extension NSInputStream {
    public func readValue<T>() throws -> T {
        let size = sizeof(T.self)
        var buf = Bytes(count: size)
        if read(&buf.data, maxLength: size) < size {
            throw "readValue fail"
        }
        return buf.toValue()
    }
    
    public func readNSData(size : Int = Int.max) throws -> NSData {
        let data = NSMutableData(length: size)!
        let p = UnsafeMutablePointer<UInt8>(data.bytes)
        let ret = read(p, maxLength: size)
        if ret < 0 {
            throw "readNSData fail"
        }
        if ret < size {
            return data.subdataWithRange(NSRange(0 ..< ret))
        }
        return data
    }
}

public extension NSOutputStream {
    public func writeValue<T>(value : T) throws {
        let size = sizeof(T.self)
        var buf = Bytes(value: value)
        if write(&buf.data, maxLength: size) < size {
            throw "writeValue fail"
        }
    }
    
    public func writeNSData(data : NSData) throws {
        let p = UnsafePointer<UInt8>(data.bytes)
        if write(p, maxLength: data.count) < data.count {
            throw "writeNSData fail"
        }
    }
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
        return Bytes(data: data)
    }
    
    public func toString(
        encoding : NSStringEncoding = NSUTF8StringEncoding
    ) -> String {
        return String(data: self, encoding: encoding)!
    }
    
    public func toValue<T>() -> T {
        let p = UnsafePointer<T>(bytes)
        return p.memory
    }
    
    public func toDData() -> DData {
        return DData(dispatch_data_create(
            bytes, count, qUtility(), nil
        ))
    }
}

extension String : ErrorType {}

public extension String {
    public func toNSData() -> NSData {
        return dataUsingEncoding(NSUTF8StringEncoding)!
    }
    
    public func toUtf8() -> Bytes {
        return Bytes(data: Array(utf8))
    }
    
    public func split(set : String) -> [String] {
        return unicodeScalars.split {
            set.unicodeScalars.contains($0)
        }.map(String.init)
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

public typealias ResponseData = (NSURLResponse, NSData)
public typealias HttpResponseData = (NSHTTPURLResponse, NSData)

public typealias ResponseDownload = (NSURLResponse, NSURL)
public typealias HttpResponseDownload = (NSHTTPURLResponse, NSURL)

extension NSURLSession {
    public func responseData(
        req : NSURLRequest
    ) -> Async<ResponseData> {
        return Async<ResponseData>
        { (p : Param<ResponseData>) in
            self.dataTaskWithRequest(req)
            { (data, resp, err) in
                if err != nil {
                    p.econ(.Exception(err!))
                    return
                }
                p.con(resp!, data!)
            }.resume()
        }
    }
    
    public func responseDownload(
        req : NSURLRequest
    ) -> Async<ResponseDownload> {
        return Async<ResponseDownload>
        { (p : Param<ResponseDownload>) in
            self.downloadTaskWithRequest(req)
            { (url, resp, err) in
                if err != nil {
                    p.econ(.Exception(err!))
                    return
                }
                p.con(resp!, url!)
            }.resume()
        }
    }
    
    public func reponseUpload(
        req : NSURLRequest, data : NSData?
    ) -> Async<ResponseData> {
        return Async<ResponseData>
        { (p : Param<ResponseData>) in
            self.uploadTaskWithRequest(req, fromData: data)
            { (data, resp, err) in
                if err != nil {
                    p.econ(.Exception(err!))
                    return
                }
                p.con(resp!, data!)
            }.resume()
        }
    }
}
