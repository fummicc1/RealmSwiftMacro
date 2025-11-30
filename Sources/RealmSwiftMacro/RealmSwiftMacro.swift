// The Swift Programming Language
// https://docs.swift.org/swift-book

import Realm
import RealmSwift

/// A macro that generates a thread-safe ModelActor for Realm database CRUD operations.
///
/// The macro creates:
/// 1. A dedicated Actor (`{Model}Actor`) for thread-safe operations
/// 2. Convenience instance/static methods that use the Actor internally
///
/// Example model definition:
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
/// ## API 1: ModelActor (Recommended for complex scenarios)
///
/// ```swift
///     // Create actor instance (reusable)
///     let todoActor = try await TodoActor()
///
///     // CRUD operations
///     let todo = try await todoActor.create(_id: .generate(), name: "Task", owner: "User", status: "Active")
///     try await todoActor.update(todo, name: "Updated")
///     try await todoActor.delete(todo)
///     let todos = try await todoActor.list()
///
///     // Real-time observation
///     for await todos in todoActor.observe() {
///         print("Current: \(todos.count)")
///     }
/// ```
///
/// ## API 2: Convenience Methods (Simple one-off operations)
///
/// ```swift
///     // Static/instance methods (creates new actor internally)
///     let todo = try await Todo.create(_id: .generate(), name: "Task", owner: "User", status: "Active")
///     try await todo.update(name: "Updated")
///     try await todo.delete()
///     let todos = try await Todo.list()
///
///     // Note: For observation, use the Actor API (todoActor.observe())
/// ```
@attached(peer, names: suffixed(Actor))
@attached(member, names: arbitrary)
public macro GenCrud() = #externalMacro(
    module: "RealmSwiftMacroMacros",
    type: "RealmModelMacro"
)
