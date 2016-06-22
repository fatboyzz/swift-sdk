import XCTest
import UtilSW
import QiniuSW

class IOTests: XCTestCase {
    
    func testPutDown() {
        let key = "\(ticks())_\(small.name)"
        let en = Entry(bucket: tc.BUCKET, key: key)
        let p = PutPolicy(scope: en.scope, deadline: deadline(3600))
        let extra = PutExtra()
        
        c.putFile(
            token: c.token(p),
            key: key,
            path: small.path,
            extra: extra
        ).bindRet(.Sync) { r in
            XCTAssert(r.check())
        }.runSync()
        
        let downUrl = publicUrl(domain: tc.DOMAIN, key: key)
        let downPath = "\(testPath)/\(key)"
        
        c.downFile(
            url: downUrl, path: downPath
        ).bind(.Sync) { r -> Async<String> in
            XCTAssert(r.check())
            return QETag.hash(path: downPath)
        }.bindRet(.Sync) { downQETag in
            XCTAssertEqual(downQETag, small.qetag)
        }.runSync()
        
        c.delete(en).runSync()
    }
    
    func testPutCrc() {
        let key = "\(ticks())_\(small.name)"
        let en = Entry(bucket: tc.BUCKET, key: key)
        let p = PutPolicy(scope: en.scope, deadline: deadline(3600))
        var extra = PutExtra()
        extra.checkCrc = .Auto
        
        c.putFile(
            token: c.token(p),
            key: key,
            path: small.path,
            extra: extra
        ).bindRet(.Sync) { r in
            XCTAssert(r.check())
        }.runSync()
        
        c.delete(en).runSync()
    }
    
    func testRPut() {
        let key = "\(ticks())_\(big.name)"
        let en = Entry(bucket: tc.BUCKET, key: key)
        let p = PutPolicy(scope: en.scope, deadline: deadline(3600))
        let extra = RPutExtra()
        
        c.rputFile(
            token: c.token(p),
            key: key,
            path: big.path,
            extra: extra
        ).bindRet(.Sync) { r in
            XCTAssertEqual((try! r.pick()).qetag, big.qetag)
        }.runSync()
        
        c.delete(en).runSync()
    }
}
