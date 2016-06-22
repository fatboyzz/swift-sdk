import Foundation
import UtilSW

public class ListItem : NSObject {
    public var key = ""
    public var qetag = ""
    public var fsize : Int64 = 0
    public var putTime : Int64 = 0 // Unit: 100 nano second
    public var mimeType = ""
    public var endUser = ""
}

public class ListSucc : NSObject {
    public var marker = ""
    public var commonPrefixes = [ "" ]
    public var items = [ ListItem() ]
}

extension Client {
    public func list(
        bucket bucket : String,
        limit : Int = 0,
        prefix : String = "",
        delimiter : String = "",
        marker : String = ""
    ) -> Async<Ret<ListSucc>> {
        var query = [String](arrayLiteral: "bucket=\(bucket)")
        if limit > 0 { query.append("limit=\(limit)") }
        if !prefix.isEmpty { query.append("prefix=\(prefix)") }
        if !delimiter.isEmpty { query.append("delimiter=\(delimiter)") }
        if !marker.isEmpty { query.append("marker=\(marker)") }
        let qs = query.joinWithSeparator("&")
        let url = "\(config.rsfHost)/list?\(qs)"
        return responseRet(ListSucc(), requestOp(url))
    }
    
}