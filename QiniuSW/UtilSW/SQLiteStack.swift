import Foundation
import CoreData

public class SQLiteStack {
    public let modelUrl : NSURL
    public let storeUrl : NSURL
    public let model : NSManagedObjectModel
    public let coordinator : NSPersistentStoreCoordinator
    private let context : NSManagedObjectContext

    public init(modelUrl : NSURL, storeUrl : NSURL) {
        self.modelUrl = modelUrl
        self.storeUrl = storeUrl
        model = NSManagedObjectModel(contentsOfURL: modelUrl)!
        coordinator = NSPersistentStoreCoordinator(
            managedObjectModel: model
        )
        context = NSManagedObjectContext(
            concurrencyType: .PrivateQueueConcurrencyType
        )
        context.mergePolicy = NSMergePolicy(
            mergeType: .MergeByPropertyStoreTrumpMergePolicyType
        )
        context.persistentStoreCoordinator = self.coordinator
        context.performBlock {
            try! self.coordinator.addPersistentStoreWithType(
                NSSQLiteStoreType,
                configuration: nil,
                URL: self.storeUrl,
                options: nil
            )
        }
    }
    
    // DO NOT return NSManagedObject in block, they are not thread safe
    public func perform<T>(
        block : NSManagedObjectContext throws -> T
    ) -> Async<T> {
        let ctx = self.context
        return delayRet(.Custom(c: ctx.performBlock)) {
            try block(ctx)
        }
    }

    // DO NOT return NSManagedObject in block, they are not thread safe
    public func performSave<T>(
        block : NSManagedObjectContext throws -> T
    ) -> Async<T> {
        return perform { ctx throws in
            let ret = try block(ctx)
            if ctx.hasChanges {
                try ctx.save()
            }
            return ret
        }
    }
}

public func entityName<T : NSManagedObject>(t : T.Type) -> String {
    let c = class_getName(t)
    let s = String(CString: c, encoding: NSUTF8StringEncoding)!
    return s.split(".").last!
}

extension NSManagedObjectContext {
    public func create<T : NSManagedObject>(t : T.Type) -> T {
        return NSEntityDescription.insertNewObjectForEntityForName(
            entityName(t), inManagedObjectContext: self
        ) as! T
    }
}

