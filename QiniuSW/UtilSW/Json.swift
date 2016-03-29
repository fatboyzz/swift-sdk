import Foundation

public protocol CustomJobj {
    func toJobj(d : NSMutableDictionary)
    func fromJobj(d : NSMutableDictionary)
}

public func jobjToJson(obj : AnyObject) -> NSData {
    let opt = NSJSONWritingOptions()
    return try! NSJSONSerialization.dataWithJSONObject(obj, options: opt)
}

public func jsonToJobj(data : NSData) -> AnyObject {
    let opt = NSJSONReadingOptions.AllowFragments
    return try! NSJSONSerialization.JSONObjectWithData(data, options: opt)
}

public func objToJobj(o : Any) -> AnyObject {
    switch o {
    case _ as Void: return NSNull()
    case let n as Int8: return NSNumber(char: n)
    case let n as Int16: return NSNumber(short: n)
    case let n as Int32: return NSNumber(int: n)
    case let n as Int64: return NSNumber(longLong: n)
    case let n as UInt8: return NSNumber(unsignedChar: n)
    case let n as UInt16: return NSNumber(unsignedShort: n)
    case let n as UInt32: return NSNumber(unsignedInt: n)
    case let n as UInt64: return NSNumber(unsignedLongLong: n)
    case _ as NSNumber: fallthrough
    case _ as NSString: fallthrough
    case _ as NSArray: fallthrough
    case _ as NSDictionary: return o as! AnyObject
    case let nso as NSObject:
        let m = Mirror(reflecting: nso)
        let d = NSMutableDictionary(capacity: Int(m.children.count))
        for c in m.children {
            let jo = objToJobj(c.value)
            d.setValue(jo, forKey: c.label!)
        }
        if let c = nso as? CustomJobj {
            c.toJobj(d)
        }
        return d as NSDictionary
    default:
        return o as! AnyObject
    }
}

public func jobjToObj(o : Any, _ jo : AnyObject) -> AnyObject {
    switch o {
    case _ as NSNumber: fallthrough
    case _ as NSString: fallthrough
    case _ as NSArray: fallthrough
    case _ as NSDictionary:
        return jo
    case let nso as NSObject :
        let m = Mirror(reflecting: nso)
        var d = jo as! NSDictionary
        if let c = nso as? CustomJobj {
            let dd = NSMutableDictionary(dictionary: d)
            c.fromJobj(dd)
            d = dd
        }
        for c in m.children {
            let k = c.label!
            let nexto = nso.valueForKey(k)!
            if let nextjo = d.valueForKey(k) {
                let v = jobjToObj(nexto, nextjo)
                nso.setValue(v, forKey: k)
            }
        }
        return nso
    default:
        return o as! AnyObject
    }
}

public func objToJson<T>(o : T) -> NSData {
    if o as? Void != nil { return NSData() }
    return jobjToJson(objToJobj(o))
}

public func jsonToObj<T>(zero : T, _ data : NSData) -> T {
    if zero as? Void != nil { return () as! T }
    return jobjToObj(zero, jsonToJobj(data)) as! T
}
