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

public struct RealmModelMacro: MemberMacro, PeerMacro {
    // MARK: - MemberMacro

    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingMembersOf declaration: some SwiftSyntax.DeclGroupSyntax,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
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

        let memberNames = members.map(\.0).compactMap {
            $0.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
        }

        let typeAnnotations = try members.compactMap { (member, varDecl) -> String? in
            guard let identifier = member.typeAnnotation?.type.as(IdentifierTypeSyntax.self) else {
                throw RealmSwiftMacroError.didNotFindTypeAnnotationForProperty(varDecl)
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

        // Generate convenience static methods that use the Actor internally

        // create() method
        let createParameters = zip(memberNames, typeAnnotations).map {
            "\($0): \($1)"
        }.joined(separator: ", ")

        let createArgs = memberNames.map { "\($0): \($0)" }.joined(separator: ", ")

        let createCode: DeclSyntax = """
public static func create(\(raw: createParameters)) async throws -> \(raw: className) {
    let actor = try await \(raw: className)Actor()
    return try await actor.create(\(raw: createArgs))
}
"""
        codes.append(createCode)

        // update() instance method
        let updateParameters = zip(memberNames, typeAnnotations).map {
            "\($0): \($1)? = nil"
        }.joined(separator: ", ")

        let updateArgs = memberNames.map { "\($0): \($0)" }.joined(separator: ", ")

        let updateCode: DeclSyntax = """
public func update(\(raw: updateParameters)) async throws {
    let actor = try await \(raw: className)Actor()
    try await actor.update(self, \(raw: updateArgs))
}
"""
        codes.append(updateCode)

        // delete() instance method
        let deleteCode: DeclSyntax = """
public func delete() async throws {
    let actor = try await \(raw: className)Actor()
    try await actor.delete(self)
}
"""
        codes.append(deleteCode)

        // list() static method
        let listCode: DeclSyntax = """
public static func list() async throws -> [\(raw: className)] {
    let actor = try await \(raw: className)Actor()
    return try await actor.list()
}
"""
        codes.append(listCode)

        return codes
    }

    // MARK: - PeerMacro

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
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
                throw RealmSwiftMacroError.didNotFindTypeAnnotationForProperty(varDecl)
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

        // Generate Actor
        let actorDecl = try generateActor(
            className: className,
            memberNames: memberNames,
            typeAnnotations: typeAnnotations
        )

        return [actorDecl]
    }

    private static func generateActor(
        className: String,
        memberNames: [String?],
        typeAnnotations: [String]
    ) throws -> DeclSyntax {
        // Generate create parameters
        let createParameters = zip(memberNames, typeAnnotations).map {
            "\($0!): \($1)"
        }.joined(separator: ", ")

        let createValues = memberNames.map {
            "\"\($0!)\": \($0!)"
        }.joined(separator: ",\n                ")

        // Generate update parameters
        let updateParameters = zip(memberNames, typeAnnotations).map {
            "\($0!): \($1)? = nil"
        }.joined(separator: ", ")

        let updateAssignments = memberNames.compactMap { memberName -> String? in
            guard let memberName else { return nil }
            return """
if let \(memberName) {
    dict["\(memberName)"] = \(memberName)
}
"""
        }.joined(separator: "\n        ")

        let actorCode: DeclSyntax = """
public actor \(raw: className)Actor {
    private let realm: Realm
    private var notificationToken: NotificationToken?

    public init(configuration: Realm.Configuration = .defaultConfiguration) async throws {
        self.realm = try await Realm(configuration: configuration)
    }

    deinit {
        notificationToken?.invalidate()
    }

    // MARK: - CRUD Operations

    public func create(\(raw: createParameters)) async throws -> \(raw: className) {
        try await realm.asyncWrite {
            realm.create(
                \(raw: className).self,
                value: [
                    \(raw: createValues)
                ]
            )
        }
    }

    public func update(_ object: \(raw: className), \(raw: updateParameters)) async throws {
        try await realm.asyncWrite {
            var dict: [String: Any] = [:]
            \(raw: updateAssignments)
            realm.create(
                \(raw: className).self,
                value: dict,
                update: .modified
            )
        }
    }

    public func delete(_ object: \(raw: className)) async throws {
        try await realm.asyncWrite {
            realm.delete(object)
        }
    }

    public func list() async throws -> [\(raw: className)] {
        let results = realm.objects(\(raw: className).self)
        return Array(results)
    }

    // MARK: - Observation

    public func observe() -> AsyncStream<[\(raw: className)]> {
        let (stream, continuation) = AsyncStream.makeStream(of: [\(raw: className)].self)

        let objects = realm.objects(\(raw: className).self)

        self.notificationToken = objects.observe { changes in
            switch changes {
            case .initial(let results):
                continuation.yield(Array(results))
            case .update(let results, _, _, _):
                continuation.yield(Array(results))
            case .error:
                continuation.finish()
            }
        }

        continuation.onTermination = { @Sendable [weak self] _ in
            Task { [weak self] in
                await self?.stopObserving()
            }
        }

        return stream
    }

    private func stopObserving() {
        notificationToken?.invalidate()
        notificationToken = nil
    }
}
"""

        return actorCode
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
        }
        return attrNameList.contains(name)
    }
}
