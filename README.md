# RealmSwiftMacro

A Swift macro that automatically generates a thread-safe ModelActor and convenience methods for Realm database CRUD operations.

## Status

[![CI](https://github.com/fumiyatanaka/RealmSwiftMacro/workflows/CI/badge.svg)](https://github.com/fumiyatanaka/RealmSwiftMacro/actions/workflows/ci.yml)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey.svg)](https://github.com/fumiyatanaka/RealmSwiftMacro)

> ⚠️ **Known Issue**: Full package build currently fails due to RealmSwift 10.54.6 SIL verification errors with Swift 6. Macro functionality is fully validated via isolated tests.

## CI Strategy

This project uses a **phased CI approach**:

- **Phase 1 (Current)**: Validates macro compilation and expansion tests
  - ✅ Macro target builds successfully
  - ✅ Macro expansion logic validated
  - ✅ Code quality checks

- **Phase 2 (Future)**: Full integration testing when RealmSwift is compatible
  - ⏳ Complete package build
  - ⏳ Full test suite execution
  - ⏳ Multi-platform testing

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
// Create an actor instance (reusable)
let todoActor = try await TodoActor()

// Or with custom configuration
let config = Realm.Configuration(
    fileURL: URL(fileURLWithPath: "/custom/path"),
    schemaVersion: 1
)
let todoActor = try await TodoActor(configuration: config)

// CRUD operations
let todo = try await todoActor.create(
    _id: .generate(),
    name: "Sample name",
    owner: "Sample owner",
    status: "Active"
)

try await todoActor.update(todo, name: "Updated name", status: "Completed")
try await todoActor.delete(todo)

let todos = try await todoActor.list()
print("Total todos: \(todos.count)")

// Real-time observation
for await todos in todoActor.observe() {
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
let todo = try await Todo.create(
    _id: .generate(),
    name: "Sample name",
    owner: "Sample owner",
    status: "Active"
)

try await todo.update(name: "Updated name", status: "Completed")
try await todo.delete()

let todos = try await Todo.list()
print("Total todos: \(todos.count)")
```

**Note**: For real-time observation, use the ModelActor API (`TodoActor().observe()`)

## How It Works

The `@GenCrud` macro generates:

### 1. ModelActor (PeerMacro)

A dedicated `{ModelName}Actor` with:

- **Thread-safe CRUD operations**:
  - `create(_:)` - Create new objects
  - `update(_:)` - Update existing objects with optional parameters
  - `delete(_:)` - Delete objects
  - `list()` - Retrieve all objects as an array
- **Real-time Observation**:
  - `observe()` - Returns `AsyncStream<[Model]>` for real-time updates
- **Resource Management**:
  - Automatic Realm instance management
  - NotificationToken lifecycle handling

### 2. Convenience Methods (MemberMacro)

Static and instance methods added to your model class:

- `static func create(_:)` - Creates actor internally, calls actor.create()
- `func update(_:)` - Creates actor internally, calls actor.update()
- `func delete()` - Creates actor internally, calls actor.delete()
- `static func list()` - Creates actor internally, calls actor.list()

**Performance Note**: Convenience methods create a new Actor instance for each call. For better performance in scenarios with multiple operations, use the ModelActor API directly.

## Architecture

### Thread Safety

All Realm operations are isolated within the Actor, ensuring thread-safe access:

```swift
actor MyBackgroundProcessor {
    let todoActor: TodoActor

    init() async throws {
        self.todoActor = try await TodoActor()
    }

    func processData() async throws {
        let todos = try await todoActor.list()
        // Safe concurrent access
    }
}
```

### UI Integration

For UI updates, wrap in MainActor:

```swift
Task {
    for await todos in todoActor.observe() {
        await MainActor.run {
            self.updateUI(with: todos)
        }
    }
}
```

## Contributing

Pull requests, bug reports and feature requests are welcome 🚀
