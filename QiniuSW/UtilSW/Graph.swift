import CoreGraphics

extension CGRect {
    public var center : CGPoint {
        get {
            return CGPoint(
                x: origin.x + size.width / CGFloat(2.0),
                y: origin.x + size.height / CGFloat(2.0)
            )
        }
    }
    
    public var diagonal : CGPoint {
        get {
            return CGPoint(
                x: origin.x + size.width,
                y: origin.y + size.height
            )
        }
    }
}

func lerp(a : CGPoint, b : CGPoint, f : CGFloat) -> CGPoint {
    let fa = f
    let fb = 1 - f
    return CGPoint(x: a.x * fa + b.x * fb, y: a.y * fa + b.y * fb)
}
