import Foundation

public protocol CustomJns {
    func toJns(d : NSMutableDictionary)
    func fromJns(d : NSMutableDictionary)
}

public func jnsToJson(obj : AnyObject) -> NSData {
    let opt = NSJSONWritingOptions()
    return try! NSJSONSerialization.dataWithJSONObject(obj, options: opt)
}

public func jsonToJns(data : NSData) -> AnyObject {
    let opt = NSJSONReadingOptions.AllowFragments
    return try! NSJSONSerialization.JSONObjectWithData(data, options: opt)
}

public func jmodelToJns(o : Any) -> AnyObject {
    switch o {
    case is Void: return NSNull()
    case let n as Int8: return NSNumber(char: n)
    case let n as Int16: return NSNumber(short: n)
    case let n as Int32: return NSNumber(int: n)
    case let n as Int64: return NSNumber(longLong: n)
    case let n as UInt8: return NSNumber(unsignedChar: n)
    case let n as UInt16: return NSNumber(unsignedShort: n)
    case let n as UInt32: return NSNumber(unsignedInt: n)
    case let n as UInt64: return NSNumber(unsignedLongLong: n)
    case let n as NSNumber: return n
    case let s as NSString: return s
    case let src as NSArray:
        let dst = NSMutableArray(capacity: src.count)
        for e in src {
            dst.addObject(jmodelToJns(e))
        }
        return dst
    case let src as NSDictionary:
        let dst = NSMutableDictionary(capacity: src.count)
        for (k, v) in src {
            dst.setObject(jmodelToJns(v), forKey: k as! NSCopying)
        }
        return dst
    case let nso as NSObject:
        let m = Mirror(reflecting: nso)
        let d = NSMutableDictionary(capacity: Int(m.children.count))
        for c in m.children {
            d.setValue(jmodelToJns(c.value), forKey: c.label!)
        }
        if let c = nso as? CustomJns {
            c.toJns(d)
        }
        return d
    default:
        return NSNull()
    }
}

public func jnsToJmodel(o : Any, _ jo : AnyObject) -> Any {
    switch o {
    case is Void: return ()
    case is Int8: return (jo as! NSNumber).charValue
    case is Int16: return (jo as! NSNumber).shortValue
    case is Int32: return (jo as! NSNumber).intValue
    case is Int64: return (jo as! NSNumber).longLongValue
    case is UInt8: return (jo as! NSNumber).unsignedCharValue
    case is UInt16: return (jo as! NSNumber).unsignedShortValue
    case is UInt32: return (jo as! NSNumber).unsignedIntValue
    case is UInt64: return (jo as! NSNumber).unsignedIntegerValue
    case is NSNumber: return jo as! NSNumber
    case is NSString: return jo as! NSString
    case let a as NSArray:
        let p = a[0]
        let src = jo as! NSArray
        let dst = NSMutableArray(capacity: src.count)
        for e in src {
            let v = jnsToJmodel(p, e) as! AnyObject
            dst.addObject(v)
        }
        return dst
    case let d as NSDictionary:
        let p = d.allValues[0]
        let src = jo as! NSDictionary
        let dst = NSMutableDictionary(capacity: src.count)
        for (k, v) in src {
            dst.setObject(
                jnsToJmodel(p, v) as! AnyObject,
                forKey: k as! NSCopying
            )
        }
        return dst
    case let nso as NSObject:
        let dst = nso.dynamicType.init()
        let m = Mirror(reflecting: dst)
        var src = jo as! NSDictionary
        if let c = dst as? CustomJns {
            let dd = NSMutableDictionary(dictionary: src)
            c.fromJns(dd)
            src = dd
        }
        for c in m.children {
            let k = c.label!
            let nexto = dst.valueForKey(k)!
            if let nextjo = src.objectForKey(k) {
                let v = jnsToJmodel(nexto, nextjo)
                dst.setValue(v as? AnyObject, forKey: k)
            } else {
                if nexto is NSArray {
                    dst.setValue(NSArray(), forKey: k)
                }
                if nexto is NSDictionary {
                    dst.setValue(NSDictionary(), forKey: k)
                }
            }
        }
        return dst
    default:
        return ()
    }
}

public func jmodelToJson<T>(o : T) -> NSData {
    if o is Void { return NSData() }
    return jnsToJson(jmodelToJns(o))
}

public func jsonToJmodel<T>(zero : T, _ data : NSData) -> T {
    if zero is Void { return () as! T }
    return jnsToJmodel(zero, jsonToJns(data)) as! T
}
