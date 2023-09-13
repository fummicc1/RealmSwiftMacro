import RealmSwiftMacro
import RealmSwift

func main() {
    Task {
        // MARK: Create
        let todo = try await Todo.create(
            _id: .generate(),
            name: "Sample name",
            owner: "Sample owner",
            status: "Sample status"
        )
        // MARK: Update
        try await todo.update(name: "Updated name")
        // MARK: Delete
        try await todo.delete()
        // MARK: Get all List
        let todos = try await Todo.list()
        print(todos)
        // MARK: Observe all List
        let (_, stream) = try await Todo.observe()
        for try await todoChange in stream {
            switch todoChange {
            case .initial(let todos):
                print(todos)
            case let .update(updatedTodos, _, _, _):
                print(updatedTodos)
            case .error(let error):
                print(error)
            }
        }
    }
}

main()
