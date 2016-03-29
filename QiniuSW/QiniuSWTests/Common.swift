import Foundation
import UtilSW
import QiniuSW

class TestConfig : NSObject {
    var ACCESS_KEY = ""
    var SECRET_KEY = ""
    var BUCKET = ""
    var DOMAIN = ""
}

let testPathKey = "QiniuTestPath"
    
let testPath = { () -> String in
    let bundle = NSBundle(forClass: QiniuSWTests.self)
    return bundle.infoDictionary![testPathKey] as! String
}()
    
let testConfig = "\(testPath)/TestConfig.json"

let tc = { () -> TestConfig in
    let data = NSData(contentsOfFile: testConfig)!
    return jsonToObj(TestConfig(), data)
}()

let c = { () -> Client in
    let config = Config(
        accessKey: tc.ACCESS_KEY,
        secretKey: tc.SECRET_KEY
    )
    return Client(config)
}()

func ticks() -> Int {
    return Int(NSDate().timeIntervalSince1970 * 1000)
}

class RandomData {
    let name : String
    let path : String
    let entry : Entry
    let channel : Channel
    let qetag : String
    
    static func genData(path : String, size : Int) -> Bool {
        if File.exist(path) { return false }
        let ch = Channel(fd: creat(path, 0o644))
        let r = try! Channel(path: "/dev/random", oflag: O_RDONLY)
        r.copyTo(ch, count: size).runSync()
        return true
    }
    
    init(name : String, size : Int) {
        self.name = name
        self.path = "\(testPath)/\(name)"
        self.entry = Entry(bucket: tc.BUCKET, key: name)
        RandomData.genData(path, size: size)
        self.channel = try! Channel(path: path, oflag: O_RDONLY)
        var qetag = ""
        QETag.hash(ch: self.channel)
        .bindRet(.Sync) { qetag = $0 }
        .runSync()
        self.qetag = qetag
    }
}

let small = RandomData(name: "small.dat", size: 1 << 20) // 1M
let big = RandomData(name: "big.dat", size: 1 << 23) // 8M

