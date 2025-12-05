import RealmSwift
import RealmSwiftMacro
import Foundation

@GenCrud
public class User: Object {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var userId: String
    @Persisted var userName: String

    @Persisted var signedUpAt: Date
    @Persisted var signedInAt: Date

    @Persisted var posts: List<Post>

    var allContents: String {
        posts.map { $0.content }.joined(separator: "\n")
    }
}


@GenCrud
public class Post: Object {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var senderId: String
    @Persisted var content: String
    @Persisted var postedAt: Date
}
