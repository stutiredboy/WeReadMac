import CoreData
import os

final class NotesStore {
    static let shared = NotesStore()

    private let logger = Logger(subsystem: "com.wereadmac.app", category: "NotesStore")

    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    init(inMemory: Bool = false) {
        guard let modelURL = Bundle.main.url(forResource: "NotesModel", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to load NotesModel.xcdatamodeld")
        }
        container = NSPersistentContainer(name: "NotesModel", managedObjectModel: model)

        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        } else {
            if let description = container.persistentStoreDescriptions.first {
                // On macOS, data protection is provided by the app sandbox and
                // optional FileVault. We store in Application Support within the
                // sandboxed container, which is the standard secure location.
                description.shouldMigrateStoreAutomatically = true
                description.shouldInferMappingModelAutomatically = true
            }
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                self.logger.error("CoreData store failed to load: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    func saveContext(_ context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            logger.error("Failed to save context: \(error.localizedDescription)")
        }
    }
}
