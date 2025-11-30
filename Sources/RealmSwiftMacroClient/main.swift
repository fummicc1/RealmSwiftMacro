import RealmSwiftMacro
import RealmSwift

func main() async throws {
    // Create TodoActor instance
    // The macro generates TodoActor with thread-safe Realm operations
    let todoActor = try await TodoActor()
    
    print("=== ModelActor Pattern Demo ===\n")
    
    // MARK: Create
    print("# Create")
    let todo1 = try await todoActor.create(
        _id: .generate(),
        name: "First Todo",
        owner: "User 1",
        status: "Active"
    )
    print("Created: \(todo1.name)")
    
    let todo2 = try await todoActor.create(
        _id: .generate(),
        name: "Second Todo",
        owner: "User 2",
        status: "Pending"
    )
    print("Created: \(todo2.name)\n")
    
    // MARK: List
    print("# List All Todos")
    let todos = try await todoActor.list()
    todos.forEach { todo in
        print("- [\(todo.status)] \(todo.name) (owner: \(todo.owner))")
    }
    print()
    
    // MARK: Update
    print("# Update")
    try await todoActor.update(todo1, name: "Updated First Todo", status: "Completed")
    print("Updated todo1\n")
    
    // MARK: List after update
    print("# List After Update")
    let updatedTodos = try await todoActor.list()
    updatedTodos.forEach { todo in
        print("- [\(todo.status)] \(todo.name)")
    }
    print()
    
    // MARK: Observe
    print("# Observe Changes")
    print("Starting observation (will add more todos to trigger changes)...\n")
    
    // Start observing in a separate task
    let observationTask = Task {
        var count = 0
        for await todos in await todoActor.observe() {
            count += 1
            print("📢 Change #\(count): \(todos.count) todos")
            if count >= 3 {
                // Exit after 3 observations
                break
            }
        }
    }

    // Give observation time to start
    try await Task.sleep(for: .milliseconds(100))

    // Trigger some changes
    _ = try await todoActor.create(
        _id: .generate(),
        name: "Third Todo",
        owner: "User 3",
        status: "Active"
    )
    try await Task.sleep(for: .milliseconds(100))
    
    _ = try await todoActor.create(
        _id: .generate(),
        name: "Fourth Todo",
        owner: "User 4",
        status: "Active"
    )
    
    // Wait for observation to complete
    await observationTask.value
    print()
    
    // MARK: Delete
    print("# Delete")
    let finalTodos = try await todoActor.list()
    if let todoToDelete = finalTodos.first {
        try await todoActor.delete(todoToDelete)
        print("Deleted: \(todoToDelete.name)")
    }
    
    // MARK: Final List
    print("\n# Final List")
    let remaining = try await todoActor.list()
    print("Remaining todos: \(remaining.count)")
    remaining.forEach { todo in
        print("- [\(todo.status)] \(todo.name)")
    }
    
    print("\n=== Demo Complete ===")
}
