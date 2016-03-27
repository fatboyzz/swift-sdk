import XCTest
import UtilSW

class JJJ : NSObject {
    var n0 = 0
    var n1 = UInt(1)
    var n2 = UInt32(2)
    var n3 = Int64(3)
    var f = Float(2.5)
    var d = 3.5
    var b = true
    var s = "hello"
    var arr = [1, 2, 3]
}

func == (lhs : JJJ, rhs : JJJ) -> Bool {
    return
        lhs.n0 == rhs.n0 &&
        lhs.n1 == rhs.n1 &&
        lhs.n2 == rhs.n2 &&
        lhs.n3 == rhs.n3 &&
        lhs.f == rhs.f &&
        lhs.d == rhs.d &&
        lhs.b == rhs.b &&
        lhs.s == rhs.s &&
        lhs.arr == rhs.arr
}

class JsonTests: XCTestCase {

    func testJson() {
        let a = JJJ()
        let b = jsonToObj(JJJ(), objToJson(a))
        XCTAssert(a == b)
    }

}
