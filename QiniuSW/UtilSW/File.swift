import Foundation

public struct File {
    public static func exist(path : String) -> Bool {
        return access(path, F_OK) == 0
    }
    
    public static func move(src src : String, dst : String) throws {
        if rename(src, dst) != 0 { throw posixError() }
    }
}
