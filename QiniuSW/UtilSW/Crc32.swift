import Foundation

public struct Crc32 {
    static func makeTable(poly : UInt32) -> [UInt32] {
        var r = Array(count: 256, repeatedValue: UInt32(0))
        for i in 0 ..< 256 {
            var crc = UInt32(i)
            for _ in 0 ..< 8 {
                if crc & 1 == 1 {
                    crc = (crc >> 1) ^ poly
                } else {
                    crc >>= 1
                }
            }
            r[i] = crc
        }
        return r
    }
    
    static let ieeePoly = 0xedb88320 as UInt32
    static let ieeeTable = Crc32.makeTable(ieeePoly)
    public static let ieee = Crc32(table : Crc32.ieeeTable)
    
    let table : [UInt32]
    
    public func sum(seed : UInt32, _ data : [UInt8]) -> UInt32 {
        var crc = ~seed
        for d in data {
            let index = Int(UInt8(crc & 0xFF) ^ d)
            crc = table[index] ^ (crc >> 8)
        }
        return ~crc
    }
}