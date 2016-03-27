import Foundation

public struct Base64 {
    static func table(s : String) -> [UInt8] {
        return Array(s.unicodeScalars).map { u in UInt8(u.value) }
    }
    
    static func inv(table : [UInt8]) -> [UInt8] {
        var ret = Array(count: 256, repeatedValue: UInt8(0))
        for (i, e) in table.enumerate() {
            ret[Int(e)] = UInt8(i)
        }
        return ret
    }
    
    static let padding = chr("=")
    static let cr = chr("\r")
    static let lf = chr("\n")
    
    static func clean(u : [UInt8]) -> [UInt8] {
        return u.filter { u in
            u != Base64.cr && u != Base64.lf && u != Base64.padding
        }
    }
    
    static let basic = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    
    static let normalString = basic + "+/"
    static let normalTable = Base64.table(Base64.normalString)
    static let normalInvTable = Base64.inv(Base64.normalTable)
    public static let normal = Base64(
        table: Base64.normalTable, invTable: Base64.normalInvTable
    )
    
    static let urlsafeString = basic + "-_"
    static let urlsafeTable = Base64.table(urlsafeString)
    static let urlsafeInvTable = Base64.inv(normalTable)
    public static let urlsafe = Base64(
        table: Base64.urlsafeTable, invTable: Base64.urlsafeInvTable
    )
    
    let table : [UInt8]
    let invTable : [UInt8]
    
    public func encode(data : [UInt8]) -> [UInt8] {
        let remain = data.count % 3
        let last = data.count - remain
        var ret = [UInt8]()
        ret.reserveCapacity((data.count + 2) / 3 * 4)
        
        for i in 0.stride(to: last, by: 3) {
            let (x, y, z) = (data[i], data[i + 1], data[i + 2])
            let a = x >> 2
            let b = ((x << 4) | (y >> 4)) & 0x3F
            let c = ((y << 2) | (z >> 6)) & 0x3F
            let d = z & 0x3F
            ret.append(table[Int(a)])
            ret.append(table[Int(b)])
            ret.append(table[Int(c)])
            ret.append(table[Int(d)])
        }
        
        switch remain {
        case 1:
            let x = data[last]
            let a = x >> 2
            let b = (x << 4) & 0x3F
            ret.append(table[Int(a)])
            ret.append(table[Int(b)])
            ret.append(Base64.padding)
            ret.append(Base64.padding)
            break
        case 2:
            let (x, y) = (data[last], data[last + 1])
            let a = x >> 2
            let b = ((x << 4) | (y >> 4)) & 0x3F
            let c = (y << 2) & 0x3F
            ret.append(table[Int(a)])
            ret.append(table[Int(b)])
            ret.append(table[Int(c)])
            ret.append(Base64.padding)
            break
        default:
            break
        }
        return ret
    }
    
    public func decode(data : [UInt8]) -> [UInt8] {
        var clean = Base64.clean(data)
        let remain = clean.count % 4
        let last = clean.count - remain
        
        var ret = [UInt8]()
        ret.reserveCapacity((clean.count + 3) / 4 * 3)
        
        for i in 0.stride(to:last, by: 4) {
            let a = invTable[Int(clean[i])]
            let b = invTable[Int(clean[i + 1])]
            let c = invTable[Int(clean[i + 2])]
            let d = invTable[Int(clean[i + 3])]
            ret.append((a << 2) | (b >> 4))
            ret.append((b << 4) | (c >> 2))
            ret.append((c << 6) | d)
        }
        
        switch remain {
        case 2:
            let a = invTable[Int(clean[last])]
            let b = invTable[Int(clean[last + 1])]
            ret.append((a << 2) | (b >> 4))
            break
        case 3:
            let a = invTable[Int(clean[last])]
            let b = invTable[Int(clean[last + 1])]
            let c = invTable[Int(clean[last + 2])]
            ret.append((a << 2) | (b >> 4))
            ret.append((b << 4) | (c >> 2))
            break
        default:
            break
        }

        return ret
    }

}

