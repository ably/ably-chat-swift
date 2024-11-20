import Foundation

// Generator utility is for internal use only, so force_cast is fine:
// swiftlint:disable force_cast

/**
 * Unified Test Suite adapter generator for swift Chat SDK
 */
class ChatAdapterGenerator {
    var generatedFileContent = "// GENERATED CONTENT BEGIN\n\n"

    func generate() {
        print("Generating swift code...")
        Schema.json.forEach { generateSchema($0) }
        generatedFileContent += "// GENERATED CONTENT END"
        print(generatedFileContent)
    }

    func generateSchema(_ schema: JSON) {
        guard let objectType = schema.name else {
            return print("Schema should have a name.")
        }
        if let constructor = schema.constructor {
            generateConstructorForType(objectType, schema: constructor, isAsync: false, throwing: false)
        }
        for method in schema.syncMethods?.sortedByKey() ?? [] {
            generateMethodForType(objectType, methodName: method.key, methodSchema: method.value as! JSON, isAsync: false, throwing: true)
        }
        for method in schema.asyncMethods?.sortedByKey() ?? [] {
            generateMethodForType(objectType, methodName: method.key, methodSchema: method.value as! JSON, isAsync: true, throwing: true)
        }
        for field in schema.fields?.sortedByKey() ?? [] {
            generateFieldForType(objectType, fieldName: field.key, fieldSchema: field.value as! JSON)
        }
        for method in schema.listeners?.sortedByKey() ?? [] {
            generateMethodWithCallbackForType(objectType, methodName: method.key, methodSchema: method.value as! JSON, isAsync: true, throwing: false)
        }
    }

    func generateConstructorForType(_ objectType: String, schema: JSON, isAsync _: Bool, throwing _: Bool) {
        let implPath = "\(objectType)"
        if Schema.skipPaths.contains([implPath]) {
            return print("\(implPath) was not yet implemented or requires custom implementation.")
        }
        let methodArgs = schema.args ?? [:]
        let paramsDeclarations = methodArgs.map { element in
            let argSchema = element.value as! JSON
            return "    let \(element.key.bigD()) = try \(altTypeName(argSchema.type!)).from(rpcParams.methodArg(\"\(element.key)\"))"
        }
        let callParams = methodArgs.map { "\($0.key.bigD()): \($0.key.bigD())" }.joined(separator: ", ")
        generatedFileContent +=
            """
            case "\(Schema.noCallPaths.contains([implPath]) ? "~" : "")\(objectType)":
            """
        if !paramsDeclarations.isEmpty {
            generatedFileContent += paramsDeclarations.joined(separator: "\n") + "\n"
        }
        generatedFileContent +=
            """
                let \(altTypeName(objectType).firstLowercased()) = \(altTypeName(objectType))(\(callParams))
                let instanceId = generateId()
                idTo\(altTypeName(objectType))[instanceId] = \(altTypeName(objectType).firstLowercased())
                return try jsonRpcResult(rpcParams.requestId(), "{\\"instanceId\\":\\"\\(instanceId)\\"}")\n

            """
    }

    func generateMethodForType(_ objectType: String, methodName: String, methodSchema: JSON, isAsync: Bool, throwing: Bool) {
        let implPath = "\(objectType).\(methodName)"
        if Schema.skipPaths.contains([implPath]) {
            return print("\(implPath) was not yet implemented or requires custom implementation.")
        }
        let methodArgs = methodSchema.args ?? [:]
        let paramsDeclarations = methodArgs.map { element in
            let argSchema = element.value as! JSON
            return "    let \(element.key.bigD()) = try \(altTypeName(argSchema.type!)).from(rpcParams.methodArg(\"\(element.key)\"))"
        }
        let callParams = methodArgs.map { "\($0.key.bigD()): \($0.key.bigD())" }.joined(separator: ", ")
        let hasResult = methodSchema.result.type != nil && methodSchema.result.type != "void"
        let resultType = altTypeName(methodSchema.result.type ?? "void")
        generatedFileContent +=
            """
            case "\(Schema.noCallPaths.contains([implPath]) ? "~" : "")\(objectType).\(methodName)":\n
            """
        if !paramsDeclarations.isEmpty {
            generatedFileContent += paramsDeclarations.joined(separator: "\n") + "\n"
        }
        generatedFileContent +=
            """
                let refId = try rpcParams.refId()
                guard let \(altTypeName(objectType).firstLowercased())Ref = idTo\(altTypeName(objectType))[refId] else {
                    throw AdapterError.objectNotFound(type: "\(objectType)", refId: refId)
                }
                \(hasResult ? "let \(resultType.firstLowercased()) = " : "")\(throwing ? "try " : "")\(isAsync ? "await " : "")\(altTypeName(objectType).firstLowercased())Ref.\(methodName)(\(callParams)) // \(resultType)\n
            """
        if hasResult {
            if isJsonPrimitiveType(methodSchema.result.type!) {
                generatedFileContent +=
                    """
                        return try jsonRpcResult(rpcParams.requestId(), "{\\"response\\": \\"\\(\(resultType.firstLowercased()))\\"}")\n

                    """
            } else if methodSchema.result.isSerializable {
                generatedFileContent +=
                    """
                        return try jsonRpcResult(rpcParams.requestId(), "{\\"response\\": \\(jsonString(\(resultType.firstLowercased())))}")\n

                    """
            } else {
                generatedFileContent +=
                    """
                        let resultRefId = generateId()
                        idTo\(altTypeName(methodSchema.result.type!))[resultRefId] = \(resultType.firstLowercased())
                        return try jsonRpcResult(rpcParams.requestId(), "{\\"refId\\":\\"\\(resultRefId)\\"}")\n

                    """
            }
        } else {
            generatedFileContent +=
                """
                    return try jsonRpcResult(rpcParams.requestId(), "{}")\n

                """
        }
    }

    func generateFieldForType(_ objectType: String, fieldName: String, fieldSchema: JSON) {
        guard let fieldType = fieldSchema.type else {
            return print("Type information for '\(fieldName)' field is incorrect.")
        }
        let implPath = "\(objectType)#\(fieldName)"
        if Schema.skipPaths.contains([implPath]) {
            return print("\(implPath) was not yet implemented or requires custom implementation.")
        }
        generatedFileContent +=
            """
            case "\(Schema.noCallPaths.contains([implPath]) ? "~" : "")\(implPath)":
                let refId = try rpcParams.refId()
                guard let \(altTypeName(objectType).firstLowercased())Ref = idTo\(altTypeName(objectType))[refId] else {
                    throw AdapterError.objectNotFound(type: "\(objectType)", refId: refId)
                }
                let \(fieldName.bigD()) = \(altTypeName(objectType).firstLowercased())Ref.\(fieldName.bigD()) // \(fieldType)\n
            """

        if fieldSchema.isSerializable {
            if isJsonPrimitiveType(fieldType) {
                generatedFileContent +=
                    """
                        return try jsonRpcResult(rpcParams.requestId(), "{\\"response\\": \\"\\(\(fieldName.bigD()))\\"}")\n

                    """
            } else {
                generatedFileContent +=
                    """
                        return try jsonRpcResult(rpcParams.requestId(), "{\\"response\\": \\(jsonString(\(fieldName.bigD())))}")\n

                    """
            }
        } else {
            generatedFileContent +=
                """
                    let fieldRefId = generateId()
                    idTo\(fieldType)[fieldRefId] = \(fieldName.bigD())
                    return try jsonRpcResult(rpcParams.requestId(), "{\\"refId\\":\\"\\(fieldRefId)\\"}")\n

                """
        }
    }

    func generateMethodWithCallbackForType(_ objectType: String, methodName: String, methodSchema: JSON, isAsync: Bool, throwing: Bool) {
        let implPath = "\(objectType).\(methodName)"
        if Schema.skipPaths.contains([implPath]) {
            return print("\(implPath) was not yet implemented or requires custom implementation.")
        }
        let methodArgs = methodSchema.args ?? [:]
        let paramsSignatures = methodArgs.compactMap { element in
            let argName = element.key
            let argType = (element.value as! JSON).type!
            if argType != "callback" {
                return (declaration: "    let \(argName.bigD()) = try \(altTypeName(argType)).from(rpcParams.methodArg(\"\(argName)\"))",
                        usage: "\(argName.bigD()): \(argName.bigD())")
            } else {
                return nil
            }
        }
        let callParams = (paramsSignatures.map(\.usage) + ["bufferingPolicy: .unbounded"]).joined(separator: ", ")
        generatedFileContent +=
            """
            case "\(Schema.noCallPaths.contains([implPath]) ? "~" : "")\(objectType).\(methodName)":\n
            """
        if !paramsSignatures.isEmpty {
            generatedFileContent += paramsSignatures.map(\.declaration).joined(separator: "\n") + "\n"
        }
        generatedFileContent +=
            """
                let refId = try rpcParams.refId()
                guard let \(altTypeName(objectType).firstLowercased())Ref = idTo\(altTypeName(objectType))[refId] else {
                    throw AdapterError.objectNotFound(type: "\(objectType)", refId: refId)
                }
                let subscription = \(throwing ? "try " : "")\(isAsync ? "await " : "")\(altTypeName(objectType).firstLowercased())Ref.\(altMethodName(methodName))(\(callParams))\n
            """
        generatedFileContent += generateCallback(methodSchema.callback, isAsync: false, throwing: false)
        generatedFileContent +=
            """
                let resultRefId = generateId()
                idTo\(altTypeName(methodSchema.result.type!))[resultRefId] = subscription
                return try jsonRpcResult(rpcParams.requestId(), "{\\"refId\\":\\"\\(resultRefId)\\"}")\n

            """
    }

    func generateCallback(_ callbackSchema: JSON, isAsync _: Bool, throwing _: Bool) -> String {
        let callbackArgs = callbackSchema.args ?? [:]
        let paramsSignatures = callbackArgs.prefix(1).compactMap { element in // code below simplifies it to just one callback parameter
            let argName = element.key
            let argType = (element.value as! JSON).type!
            let isOptional = (element.value as! JSON).isOptional
            return (declaration: "\(altTypeName(argType))" + (isOptional ? "?" : ""), usage: "\(argName.bigD())")
        }
        let paramsDeclaration = paramsSignatures.map(\.declaration).joined(separator: ", ")
        let paramsUsage = paramsSignatures.map(\.usage).joined(separator: ", ")
        var result =
            """
                let webSocket = webSocket
                let callback: (\(paramsDeclaration)) async throws -> \(altTypeName(callbackSchema.result.type!)) = {\n
            """
        if (callbackArgs.first?.value as? JSON)?.isOptional ?? false {
            result +=
                """
                        if let param = $0 {
                            try await webSocket.send(text: jsonRpcCallback(rpcParams.callbackId(), "\\(jsonString(param))"))
                        } else {
                            try await webSocket.send(text: jsonRpcCallback(rpcParams.callbackId(), "{}"))
                        }\n
                """
        } else {
            result +=
                """
                        try await webSocket.send(text: jsonRpcCallback(rpcParams.callbackId(), "\\(jsonString($0))"))\n
                """
        }
        result +=
            """
                }
                Task {
                    for await \(paramsUsage) in subscription {
                        try await callback(\(paramsUsage))
                    }
                }\n
            """
        return result
    }
}

private extension JSON {
    var name: String? { self["name"] as? String }
    var type: String? { self["type"] as? String }
    var args: JSON? { self["args"] as? JSON }
    var result: JSON { self["result"] as! JSON }
    var isSerializable: Bool { self["serializable"] as? Bool ?? false }
    var isOptional: Bool { self["optional"] as? Bool ?? false }
    var constructor: JSON? { self["konstructor"] as? JSON }
    var fields: JSON? { self["fields"] as? JSON }
    var syncMethods: JSON? { self["syncMethods"] as? JSON }
    var asyncMethods: JSON? { self["asyncMethods"] as? JSON }
    var listeners: JSON? { self["listeners"] as? JSON }
    var listener: JSON? { self["listener"] as? JSON }
    var callback: JSON { args!.listener! }
}

// swiftlint:enable force_cast
