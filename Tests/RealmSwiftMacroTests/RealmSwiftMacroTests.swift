import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import RealmSwiftMacroMacros

let testMacros: [String: Macro.Type] = [
    "realmModel": RealmModelMacro.self,
]

final class RealmSwiftMacroTests: XCTestCase {
    func testMacro() {
        assertMacroExpansion(
            """
@GenCrud
class Todo: Object {
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var name: String
    @Persisted var owner: String
    @Persisted var status: String
    var ignored: String?
}
""",
            expandedSource: """
class Todo: Object {
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var name: String
    @Persisted var owner: String
    @Persisted var status: String
    var ignored: String?

    public static func create(_id: ObjectId, name: String, owner: String, status: String) async throws -> Todo {
        let realm = try await Realm()
        return try await realm.asyncWrite {
            realm.create(
                Todo.self,
                value: [
                    "_id": _id,
                    "name": name,
                    "owner": owner,
                    "status": status
                ]
            )
        }
    }

    public func update(_id: ObjectId? = nil, name: String? = nil, owner: String? = nil, status: String? = nil) async throws {
        let realm: Realm
        if let _realm = self.realm {
            realm = _realm
        } else {
            realm = try await Realm()
        }
        try await realm.asyncWrite {
            var dict: [String: Any] = [:]
            if let _id {
        dict["_id"] = _id
            }
            if let name {
                dict["name"] = name
            }
            if let owner {
                dict["owner"] = owner
            }
            if let status {
                dict["status"] = status
            }
            realm.create(
                Todo.self,
                value: dict,
                update: .modified
            )
        }
    }

    public func delete() async throws {
        let realm: Realm
        if let _realm = self.realm {
            realm = _realm
        } else {
            realm = try await Realm()
        }
        try await realm.asyncWrite {
            realm.delete(self)
        }
    }

    public static func list() async throws -> Results<Todo> {
        let realm = try await Realm()
        return realm.objects(Todo.self)
    }

    public static func observe(actor: any Actor = MainActor.shared) async throws -> (NotificationToken, AsyncStream<RealmCollectionChange<Results<Todo>>>) {
        let realm = try await Realm()
        let objects = realm.objects(Todo.self)
        var notificationToken: NotificationToken!
        let stream = AsyncStream { continuation in
            notificationToken = objects.observe({ changes in
                continuation.yield(changes)
            })
        }
        return (notificationToken, stream)
    }
}
"""
            ,
            macros: ["GenCrud": RealmModelMacro.self]
        )
    }
}
