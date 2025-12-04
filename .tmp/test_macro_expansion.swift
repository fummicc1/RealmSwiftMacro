// Test file to verify macro expansion without building RealmSwift

import RealmSwift

@GenCrud
class Todo: Object {
    @Persisted var title: String
    @Persisted var body: String
}

// Expected expansion:
//
// 1. Member expansion (existing static methods - to be removed)
// 2. Peer expansion (new TodoActor):
//
// public actor TodoActor {
//     private let realm: Realm
//     private var notificationToken: NotificationToken?
//
//     public init(configuration: Realm.Configuration = .defaultConfiguration) async throws {
//         self.realm = try await Realm(configuration: configuration)
//     }
//
//     deinit {
//         notificationToken?.invalidate()
//     }
//
//     // MARK: - CRUD Operations
//
//     public func create(title: String, body: String) async throws -> Todo {
//         try await realm.asyncWrite {
//             realm.create(
//                 Todo.self,
//                 value: [
//                     "title": title,
//                     "body": body
//                 ]
//             )
//         }
//     }
//
//     public func update(_ object: Todo, title: String? = nil, body: String? = nil) async throws {
//         try await realm.asyncWrite {
//             var dict: [String: Any] = [:]
//             if let title {
//                 dict["title"] = title
//             }
//             if let body {
//                 dict["body"] = body
//             }
//             realm.create(
//                 Todo.self,
//                 value: dict,
//                 update: .modified
//             )
//         }
//     }
//
//     public func delete(_ object: Todo) async throws {
//         try await realm.asyncWrite {
//             realm.delete(object)
//         }
//     }
//
//     public func list() async throws -> [Todo] {
//         let results = realm.objects(Todo.self)
//         return Array(results)
//     }
//
//     // MARK: - Observation
//
//     public func observe() -> AsyncStream<[Todo]> {
//         let (stream, continuation) = AsyncStream.makeStream(of: [Todo].self)
//
//         let objects = realm.objects(Todo.self)
//
//         self.notificationToken = objects.observe { changes in
//             switch changes {
//             case .initial(let results):
//                 continuation.yield(Array(results))
//             case .update(let results, _, _, _):
//                 continuation.yield(Array(results))
//             case .error:
//                 continuation.finish()
//             }
//         }
//
//         continuation.onTermination = { @Sendable [weak self] _ in
//             Task { [weak self] in
//                 await self?.stopObserving()
//             }
//         }
//
//         return stream
//     }
//
//     private func stopObserving() {
//         notificationToken?.invalidate()
//         notificationToken = nil
//     }
// }
