# RealmSwiftMacro

A Swift macro that automatically generates a thread-safe ModelActor and convenience methods for Realm database CRUD operations.

## Status

[![CI](https://github.com/fumiyatanaka/RealmSwiftMacro/workflows/CI/badge.svg)](https://github.com/fumiyatanaka/RealmSwiftMacro/actions/workflows/ci.yml)
[![Swift](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey.svg)](https://github.com/fumiyatanaka/RealmSwiftMacro)

> **Note**: Full package build requires RealmSwift dependencies. Macro functionality is validated via isolated macro target tests.

## Features

- 🎯 **ModelActor Pattern**: Generates a dedicated Actor for each Realm model
- 🔒 **Thread-Safe**: All Realm operations are isolated within the Actor
- 🚀 **Swift Concurrency**: Full support for async/await and AsyncStream
- 📦 **Zero Boilerplate**: Automatic CRUD method generation
- 🔄 **Real-time Observation**: Built-in AsyncStream-based observation
- ♻️ **Resource Management**: Automatic NotificationToken lifecycle management
- 🎨 **Dual API**: Choose between ModelActor or convenient static/instance methods

## Usage

### Define Your Model

```swift
@GenCrud
class Todo: Object {
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var name: String
    @Persisted var owner: String
    @Persisted var status: String
}
```

### API Choice

The `@GenCrud` macro generates two complementary APIs:

## API 1: ModelActor (Recommended)

Best for: Reusable instances, custom configurations, real-time observation

```swift
// Create an actor instance (reusable, synchronous initialization)
let todoActor = TodoActor()

// Or with custom configuration
let config = Realm.Configuration(
    fileURL: URL(fileURLWithPath: "/custom/path"),
    schemaVersion: 1
)
let todoActor = TodoActor(configuration: config)

// CRUD operations
try await todoActor.create(
    _id: .generate(),
    name: "Sample name",
    owner: "Sample owner",
    status: "Active"
)

// Get the created object via list
let todos = try await todoActor.list()
let todo = todos.first!

try await todoActor.update(todo, name: "Updated name", status: "Completed")
try await todoActor.delete(todo)

print("Total todos: \(todos.count)")

// Real-time observation
for await todos in try await todoActor.observe() {
    print("Current todos: \(todos.count)")
    todos.forEach { todo in
        print("- [\(todo.status)] \(todo.name)")
    }
}
```

## API 2: Convenience Methods

Best for: Simple one-off operations, quick prototyping

```swift
// Static/instance methods (creates new actor internally each time)
try await Todo.create(
    _id: .generate(),
    name: "Sample name",
    owner: "Sample owner",
    status: "Active"
)

// Get the created object
let todos = try await Todo.list()
let todo = todos.first!

try await todo.update(name: "Updated name", status: "Completed")
try await todo.delete()

print("Total todos: \(todos.count)")
```

```swift
// Real-time observation is also available via convenience methods
for await todos in try await Todo.observe() {
    print("Current todos: \(todos.count)")
}
```

## How It Works

The `@GenCrud` macro generates:

### 1. ModelActor (PeerMacro)

A dedicated `{ModelName}Actor` with:

- **Thread-safe CRUD operations**:
  - `create(_:)` - Create new objects
  - `update(_:on:)` - Update existing objects with optional parameters and actor isolation
  - `delete(_:on:)` - Delete objects with actor isolation
  - `list(on:)` - Retrieve all objects (defaults to `MainActor.shared`)
- **Real-time Observation**:
  - `observe(on:)` - Returns `AsyncStream<[Model]>` (defaults to `MainActor.shared`)
- **Actor Isolation**:
  - `on actor:` parameter enables safe cross-actor object passing using `ThreadSafeReference`
  - Default to `MainActor.shared` for UI-friendly access
- **Resource Management**:
  - Automatic Realm instance management
  - NotificationToken lifecycle handling

### 2. Convenience Methods (MemberMacro)

Static and instance methods added to your model class:

- `static func create(_:)` - Creates actor internally, calls actor.create()
- `func update(_:on:)` - Creates actor internally, calls actor.update()
- `func delete(on:)` - Creates actor internally, calls actor.delete()
- `static func list(on:)` - Creates actor internally (defaults to `MainActor.shared`)
- `static func observe(on:)` - Creates actor internally (defaults to `MainActor.shared`)

**Performance Note**: Convenience methods create a new Actor instance for each call. For better performance in scenarios with multiple operations, use the ModelActor API directly.

## Architecture

### Actor Execution Model

Operations are executed on different actors depending on their type:

- **Write operations** (`create`, `update`, `delete`): Always executed on the specialized `{Model}Actor`
- **Read operations** (`list`, `observe`): Always executed on `MainActor` (UI-friendly)

This design ensures thread-safe writes while keeping reads optimized for UI updates.

### Thread Safety

All Realm operations are isolated within the Actor, ensuring thread-safe access:

```swift
actor MyBackgroundProcessor {
    let todoActor: TodoActor

    init() {
        self.todoActor = TodoActor()
    }

    func processData() async throws {
        let todos = try await todoActor.list()
        // Safe concurrent access
    }
}
```

### UI Integration

Since `list()` and `observe()` run on MainActor by default, UI updates are straightforward:

```swift
Task {
    for await todos in try await todoActor.observe() {
        // Already on MainActor - direct UI updates are safe
        self.updateUI(with: todos)
    }
}
```

## Contributing

Pull requests, bug reports and feature requests are welcome 🚀
