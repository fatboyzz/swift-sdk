import XCTest
import UtilSW

class EEE : NSObject {
    var e = 0
}

class JJJ : NSObject {
    var n0 = 0
    var n1 = UInt(1)
    var n2 = UInt32(2)
    var n3 = Int64(3)
    var f = Float(2.5)
    var d = 3.5
    var b = true
    var s = "hello"
    var n = NSNumber(integer: 100)
    var arr = [1, 2, 3]
    var kv = [ "foo" : 100, "bar" : 200 ]
    var es = [ EEE(), EEE() ]
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
        lhs.n.integerValue == rhs.n.integerValue &&
        lhs.arr == rhs.arr &&
        lhs.kv["foo"] == rhs.kv["foo"] &&
        lhs.es[0].e == rhs.es[0].e
}

class JsonTests: XCTestCase {

    func testJson() {
        let a = JJJ()
        let b = jsonToJmodel(JJJ(), jmodelToJson(a))
        XCTAssert(a == b)
    }
    
}
