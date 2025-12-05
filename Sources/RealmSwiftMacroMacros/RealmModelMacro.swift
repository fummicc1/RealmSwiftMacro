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
        conformingTo protocols: [SwiftSyntax.TypeSyntax],
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
public static func create(\(raw: createParameters)) async throws {
    let actor = \(raw: className)Actor()
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
public func update(\(raw: updateParameters), on actor: (any Actor)? = #isolation) async throws {
    let actor = \(raw: className)Actor()
    try await actor.update(self, \(raw: updateArgs), on: actor)
}
"""
        codes.append(updateCode)

        // delete() instance method
        let deleteCode: DeclSyntax = """
public func delete(on actor: (any Actor)? = #isolation) async throws {
    let actor = \(raw: className)Actor()
    try await actor.delete(self, on: actor)
}
"""
        codes.append(deleteCode)

        // list() static method
        let listCode: DeclSyntax = """
public static func list(on actor: isolated any Actor = MainActor.shared) async throws -> [\(raw: className)] {
    let actor = \(raw: className)Actor()
    return try await actor.list(on: actor)
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
        memberNames: [String],
        typeAnnotations: [String]
    ) throws -> DeclSyntax {
        // Generate create parameters
        let createParameters = zip(memberNames, typeAnnotations).map {
            "\($0): \($1)"
        }.joined(separator: ", ")

        let createValues = memberNames.map {
"""
                "\($0)": \($0),
"""
        }.joined(separator: "\n")

        // Generate update parameters
        let updateParameters = zip(memberNames, typeAnnotations).map {
            "\($0): \($1)? = nil"
        }.joined(separator: ", ")

        let updateAssignments = memberNames.compactMap { memberName -> String in
            return """
            if let \(memberName) {
                safeObject.\(memberName) = \(memberName)
            }
"""
        }.joined(separator: "\n")

        let actorCode: DeclSyntax = """
public actor \(raw: className)Actor {
    private let realmConfiguration: Realm.Configuration

    public init(configuration: Realm.Configuration = .defaultConfiguration) {
        self.realmConfiguration = configuration
    }

    // MARK: - CRUD Operations

    public func create(\(raw: createParameters)) async throws {
        let realm = try await Realm(
            configuration: realmConfiguration,
            actor: self
        )
        try await realm.asyncWrite {
            realm.create(
                \(raw: className).self,
                value: [
\(raw: createValues)
                ]
            )
        }
    }

    public func update(_ object: \(raw: className), \(raw: updateParameters), on actor: (any Actor)? = #isolation) async throws {
        let ref = await makeThreadSafeReference(of: object, on: actor)
        let realm = try await Realm(
            configuration: realmConfiguration,
            actor: self
        )
        try await realm.asyncWrite {
            let safeObject = realm.resolve(ref)!
\(raw: updateAssignments)
        }
    }

    public func delete(_ object: \(raw: className), on actor: (any Actor)? = #isolation) async throws {
        let ref = await makeThreadSafeReference(of: object, on: actor)
        let realm = try await Realm(
            configuration: realmConfiguration,
            actor: self
        )
        let safeObject = realm.resolve(ref)!
        try await realm.asyncWrite {
            realm.delete(safeObject)
        }
    }

    public func list(on actor: isolated any Actor = MainActor.shared) async throws -> [\(raw: className)] {
        let realm = try await Realm(
            configuration: realmConfiguration,
            actor: actor
        )
        let results = realm.objects(\(raw: className).self)
        return Array(results)
    }

    // MARK: - Observation

    public func observe(on actor: isolated any Actor = MainActor.shared) async throws -> AsyncStream<[\(raw: className)]> {
        let realm = try await Realm(
            configuration: realmConfiguration,
            actor: actor
        )
        let (stream, continuation) = AsyncStream.makeStream(of: [\(raw: className)].self)
        let objects = realm.objects(\(raw: className).self)

        let notificationToken = objects.observe { changes in
            switch changes {
            case .initial(let results):
                continuation.yield(Array(results))
            case .update(let results, _, _, _):
                continuation.yield(Array(results))
            case .error:
                continuation.finish()
            }
        }

        continuation.onTermination = { _ in
            notificationToken.invalidate()
        }

        return stream
    }

    // MARK: - Private
    private func makeThreadSafeReference(of object: \(raw: className), on actor: isolated (any Actor)?) -> ThreadSafeReference<\(raw: className)> {
        ThreadSafeReference(to: object)
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
