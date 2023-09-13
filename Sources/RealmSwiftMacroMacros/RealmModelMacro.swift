import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

private enum Method: CaseIterable {
    case create
    case update
    case delete

    case list
    case observe

    // TODO: Support cancellation of observation.
    // case cancell
}

public enum RealmSwiftMacroError: Error {
    case didNotFindTypeAnnotationForProperty(VariableDeclSyntax?)
}

public struct RealmModelMacro: MemberMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingMembersOf declaration: some SwiftSyntax.DeclGroupSyntax,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            assertionFailure()
            return []
        }

        let className = classDecl.name.text

        let members = classDecl.memberBlock.members
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }
            .compactMap { decl -> (PatternBindingSyntax, VariableDeclSyntax)? in
                guard let member = decl.bindings.first else {
                    return nil
                }
                if !decl.hasAttribute(name: "Persisted") {
                    return nil
                }
                return (member, decl)
            }

        let memberNames = members.map(\.0).map {
            $0.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
        }

        let typeAnnotations = try members.compactMap { (member, varDecl) -> String? in
            guard let identifier = member.typeAnnotation?.type.as(IdentifierTypeSyntax.self) else {
                throw RealmSwiftMacroError.didNotFindTypeAnnotationForProperty(
                    varDecl
                )
            }
            if let generics = identifier.genericArgumentClause {
                let genericsNames = generics.arguments.compactMap { genericsArg in
                    if let genericsName = genericsArg.argument.as(IdentifierTypeSyntax.self)?.name.text {
                        return genericsName
                    }
                    return nil
                }.joined(separator: ", ")
                return "\(identifier.name.text)<\(genericsNames)>"
            }
            return identifier.name.text
        }

        var codes: [DeclSyntax] = []

        for method in Method.allCases {
            switch method {
            case .create:
                let parameters = zip(memberNames, typeAnnotations).map {
                    "\($0!): \($1)"
                }.joined(separator: ", ")

                let value = memberNames.map {
                    "\"\($0!)\": \($0!)"
                }.joined(separator: ",\n")

                let code: DeclSyntax = """
public static func create(\(raw: parameters)) async throws -> \(raw: className) {
    let realm = try await Realm()
    return try await realm.asyncWrite {
        realm.create(
            \(raw: className).self,
            value: [
                \(raw: value)
            ]
        )
    }
}
"""
                codes.append(code)

            case .update:
                let parameters = zip(memberNames, typeAnnotations).map {
                    "\($0!): \($1)? = nil"
                }.joined(separator: ", ")

                let valueWithoutNil = zip(memberNames, typeAnnotations).map { (memberName, typeAnnotation) in
                    guard let memberName else {
                        return DeclSyntax("")
                    }
                    let decl: DeclSyntax = """
if let \(raw: memberName) {
    self.\(raw: memberName) = \(raw: memberName)
}
"""
                    return decl
                }

                // TODO: traverse primary key and find
                let code: DeclSyntax = """
public func update(\(raw: parameters)) async throws {
    let realm: Realm
    if let _realm = self.realm {
        realm = _realm
    } else {
        realm = try await Realm()
    }
    try await realm.asyncWrite {
        \(raw: valueWithoutNil.map(\.description).joined(separator: "\n"))
    }
}
"""
                codes.append(code)

            case .delete:

                let code: DeclSyntax = """
public func delete() async throws {
    let realm: Realm
    if let _realm = self.realm {
        realm = _realm
    } else {
        realm = try await Realm()
    }
    try await realm.asyncWrite {
        realm.delete(self)
    }
}
"""
                codes.append(code)

                break
            case .list:
                let code: DeclSyntax = """
public static func list() async throws -> Results<\(raw: className)> {
    let realm = try await Realm()
    return realm.objects(\(raw: className).self)
}
"""
                codes.append(code)

            case .observe:
                let code: DeclSyntax = """
public static func observe(actor: any Actor = MainActor.shared) async throws -> (NotificationToken, AsyncStream<RealmCollectionChange<Results<\(raw: className)>>>) {
    let realm = try await Realm()
    let objects = realm.objects(\(raw: className).self)
    var notificationToken: NotificationToken!
    let stream = AsyncStream { continuation in
        notificationToken = objects.observe({ changes in
            continuation.yield(changes)
        })
    }
    return (notificationToken, stream)
}
"""
                codes.append(code)
            }
        }

        return codes
    }
}

private extension VariableDeclSyntax {
    func hasAttribute(name: String) -> Bool {
        let attrNameList = attributes.compactMap { attr -> String? in
            guard let attr = attr.as(AttributeSyntax.self) else {
                return nil
            }
            // Get attributeName
            guard let attrName = attr.attributeName.as(IdentifierTypeSyntax.self)?.name.text else {
                return nil
            }
            return attrName
        } ?? []
        return attrNameList.contains(name)
    }
}
