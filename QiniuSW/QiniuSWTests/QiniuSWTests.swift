import XCTest
import UtilSW
@testable import QiniuSW

class QiniuSWTests: XCTestCase {
    
    func testFoo() {
        let k : Int = 0
        let m = Mirror.init(reflecting: k)
        print(m.children.map({ (label, value) in label! }))
    }
    
}
