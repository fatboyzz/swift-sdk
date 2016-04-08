import Foundation
import UtilSW

public extension Client {
    public func downFile(url url : String, path : String) -> Async<Ret<()>> {
        let req = requestUrl(url)
        req.HTTPMethod = "GET"
        return responseDownload(req).bindRet(.Sync)
        { (resp, url) in
            if resp.accepted {
                let mgr = NSFileManager.defaultManager()
                try mgr.moveItemAtURL(url, toURL: NSURL(fileURLWithPath: path))
                return .Succ(())
            } else {
                let msg = "Response down with status code \(resp.statusCode)"
                return .Fail(Error(msg))
            }
        }
    }
}
