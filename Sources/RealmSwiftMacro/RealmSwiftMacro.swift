// The Swift Programming Language
// https://docs.swift.org/swift-book

import Realm
import RealmSwift

/// A macro that produces some methods that can help to perform crud on Realm database.
///
/// following code defines `Todo` object which represents simple data stored in Realm.
/// ```swift
///     @GenCrud
///     class Todo: Object {
///         @Persisted(primaryKey: true) var _id: ObjectId
///         @Persisted var name: String
///         @Persisted var owner: String
///         @Persisted var status: String
///     }
/// ```
///
/// Just adding `@GenCrud` macro, crud methods will automatically generates and can be used like the below.
///
/// ```swift
///     // MARK: Create
///     let todo = try await Todo.create(
///         _id: .generate(),
///         name: "Sample name",
///         owner: "Sample owner",
///         status: "Sample status"
///     )
///     // MARK: Update
///     try await todo.update(name: "Updated name")
///     // MARK: Delete
///     try await todo.delete()
///     // MARK: Get all List
///     let todos = try await Todo.list()
///     print(todos)
///     // MARK: Observe all List
///     let stream = try await Todo.observe()
///     for try await todoChange in stream {
///         switch todoChange {
///         case .initial(let todos):
///             print(todos)
///         case let .update(updatedTodos, _, _, _):
///             print(updatedTodos)
///         case .error(let error):
///             print(error)
///         }
///     }
/// ```
@attached(member, names: arbitrary)
public macro GenCrud() = #externalMacro(
    module: "RealmSwiftMacroMacros",
    type: "RealmModelMacro"
)
