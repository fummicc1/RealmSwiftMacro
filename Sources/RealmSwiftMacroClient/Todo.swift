import RealmSwift
import RealmSwiftMacro

@GenCrud
public class Todo: Object {
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var name: String
    @Persisted var owner: String
    @Persisted var status: String
    var ignored: String?
}
