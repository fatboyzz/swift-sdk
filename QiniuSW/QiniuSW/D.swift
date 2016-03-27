import Foundation
import UtilSW

public extension Client {
    public func downFile(
        url : String, path : String
    ) -> Async<Ret<()>> {
        let req = requestUrl(url)
        req.HTTPMethod = "GET"
        return responseDownload(req).bindRet(.Sync)
        { (resp, url) in
            if accepted(resp.statusCode) {
                try File.move(src: url.path!, dst: path)
                return .Succ(())
            } else {
                let msg = "Response down with status code \(resp.statusCode)"
                return .Fail(Error(msg))
            }
        }
    }
}
