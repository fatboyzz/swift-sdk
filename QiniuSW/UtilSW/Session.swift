import Foundation

public typealias ResponseData = (NSURLResponse, NSData)
public typealias HttpResponseData = (NSHTTPURLResponse, NSData)

public typealias ResponseDownload = (NSURLResponse, NSURL)
public typealias HttpResponseDownload = (NSHTTPURLResponse, NSURL)

public class Session {
    let session : NSURLSession

    public init() {
        let c = NSURLSessionConfiguration.defaultSessionConfiguration()
        session = NSURLSession(configuration: c)
    }
    
    public init(c : NSURLSessionConfiguration) {
        session = NSURLSession(configuration: c)
    }
    
    public func responseData(
        req : NSURLRequest
    ) -> Async<ResponseData> {
        return Async<ResponseData> { (p : Param<ResponseData>) in
            self.session.dataTaskWithRequest(req)
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
        return Async<ResponseDownload> { (p : Param<ResponseDownload>) in
            self.session.downloadTaskWithRequest(req)
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
        return Async<ResponseData> { (p : Param<ResponseData>) in
            self.session.uploadTaskWithRequest(req, fromData: data)
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
