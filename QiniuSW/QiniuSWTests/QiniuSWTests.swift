import XCTest
import UtilSW
import QiniuSW
import CoreData

class QiniuSWTests: XCTestCase {
    
    func testFoo() {
        let foo = { (n : Int) -> Int in
            if n = 0 {
                return 0
            } else {
                return foo(n - 1) * n
            }
        }
        
    }
}