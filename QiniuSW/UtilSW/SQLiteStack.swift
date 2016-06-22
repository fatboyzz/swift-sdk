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

public func entityTypeToName<T : NSManagedObject>(
    entity : T.Type
) -> String {
    let c = class_getName(entity)
    let s = String(CString: c, encoding: NSUTF8StringEncoding)!
    return s.split(".").last!
}

extension NSFetchRequest {
    public convenience init<T : NSManagedObject>(
        entity : T.Type, _ pred : NSPredicate? = nil
    ) {
        self.init(entityName: entityTypeToName(entity))
        predicate = pred
    }
}

extension NSManagedObjectContext {
    public func create<T : NSManagedObject>(entity : T.Type) -> T {
        return NSEntityDescription.insertNewObjectForEntityForName(
            entityTypeToName(entity), inManagedObjectContext: self
        ) as! T
    }
    
    public func fetch<T : NSManagedObject>(
        entity : T.Type, _ pred : NSPredicate? = nil
    ) throws -> [T] {
        let req = NSFetchRequest(entityName: entityTypeToName(entity))
        req.predicate = pred
        return (try executeFetchRequest(req)) as! [T]
    }
    
    public func fetch<T : NSManagedObject>(
        entity : T.Type, _ id : NSManagedObjectID
    ) -> T {
        return objectWithID(id) as! T
    }
    
    public func delete(id : NSManagedObjectID) {
        deleteObject(objectWithID(id))
    }
    
    public func delete(ids : [NSManagedObjectID]) throws {
        let req = NSBatchDeleteRequest(objectIDs: ids)
        try executeRequest(req)
    }
}
