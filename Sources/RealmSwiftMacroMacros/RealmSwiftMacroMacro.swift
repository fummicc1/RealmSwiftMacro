import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct RealmSwiftMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        RealmModelMacro.self,
    ]
}
