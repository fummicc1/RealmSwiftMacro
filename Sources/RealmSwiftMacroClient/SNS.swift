import RealmSwift
import RealmSwiftMacro
import Foundation

@GenCrud
class User: Object {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var userId: String
    @Persisted var userName: String

    @Persisted var signedUpAt: Date
    @Persisted var signedInAt: Date

    @Persisted var posts: List<Post>
}


@GenCrud
class Post: Object {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var senderId: String
    @Persisted var content: String
    @Persisted var postedAt: Date
}
