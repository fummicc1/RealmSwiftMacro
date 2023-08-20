import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import RealmSwiftMacroMacros

let testMacros: [String: Macro.Type] = [
    "realmModel": RealmModelMacro.self,
]

final class RealmSwiftMacroTests: XCTestCase {
    func testMacro() {
    }
}
