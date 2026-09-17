//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Synchronization

final class TextEncoder: Encoder {
    init() {
        self.values = Values()
    }

    fileprivate init(values: Values) {
        self.values = values
    }

    func encode<T>(_ value: T) throws -> String where T: Encodable {
        let e = self.copy()
        try value.encode(to: e)
        return e.output
    }

    fileprivate func copy() -> TextEncoder {
        TextEncoder(values: Values(values: self.values.values))
    }

    var codingPath: [CodingKey] = []

    var userInfo: [CodingUserInfoKey: Any] = [:]

    fileprivate let values: Values

    func container<Key>(keyedBy _: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        let c = TextKeyedEncodingContainer<Key>(codingPath: codingPath, values: values)
        return KeyedEncodingContainer(c)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        TextUnkeyedEncodingContainer(codingPath: self.codingPath, values: self.values)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        TextSingleValueEncodingContainer(codingPath: self.codingPath, values: self.values)
    }
}

// MARK: Stored Values

private struct KeyedValue {
    var keyName: String
    var value: Value
}

private indirect enum Value {
    case text(String)
    case sub(Values)
    case keyed(String, Value)
}

private final class Values {
    var values: [Value]
    init(values: [Value] = []) {
        self.values = values
    }
}

extension Values {
    func addNestedValues() -> Values {
        let nestedValues = Values()
        self.values.append(.sub(nestedValues))
        return nestedValues
    }

    func addNestedValues<Key: CodingKey>(for key: Key) -> Values {
        let nestedValues = Values()
        self.values.append(.keyed(key.textOutputKey, .sub(nestedValues)))
        return nestedValues
    }

    func add(text: String) {
        self.values.append(.text(text))
    }

    func add<Key: CodingKey>(text: String, for key: Key) {
        self.values.append(.keyed(key.textOutputKey, .text(text)))
    }
}

extension CodingKey {
    fileprivate var textOutputKey: String {
        // Split words by "_". Uppercase the 1st word.
        stringValue
            .camelCaseComponents
            .filter { !$0.isEmpty }
            .enumerated()
            .map { ($0.0 == 0) ? $0.1.titlecased() : $0.1.lowercased() }
            .joined(separator: " ")
    }
}

extension String {
    fileprivate var camelCaseComponents: [Substring] {
        var result: [Substring] = []
        var idx = startIndex
        var lastStart: Index?
        while idx < endIndex {
            if self[idx].isLetter, self[idx].isUppercase {
                if let s = lastStart {
                    result.append(self[s..<idx])
                }
                lastStart = idx
            } else if lastStart == nil {
                lastStart = idx
            }
            idx = index(after: idx)
        }
        if let s = lastStart, s < idx {
            result.append(self[s..<idx])
        }
        return result
    }
}

extension StringProtocol {
    fileprivate func titlecased() -> String {
        let idx = index(after: startIndex)
        guard idx <= endIndex else { return String(self) }
        return String(self[startIndex..<idx]).uppercased() + String(self[idx..<endIndex])
    }
}

// MARK: Generate Output String

extension TextEncoder {
    private var output: String {
        var result = ""
        self.values.appendOutput(to: &result, indent: 0)
        return result
    }
}

extension Values {
    func appendOutput(to result: inout String, indent: Int) {
        // If some values have more than 1 line, separate them with a newline:
        let needsSeparation = self.values.reduce(false) { $0 || ($1.count > 1) }
        if needsSeparation {
            self.appendSeparatedOutput(to: &result, indent: indent)
        } else {
            self.values.forEach {
                $0.appendOutput(to: &result, indent: indent)
            }
        }
    }

    private func appendSeparatedOutput(to result: inout String, indent: Int) {
        var isFirst = true
        self.values.forEach {
            if isFirst {
                isFirst = false
            } else {
                result.append(String.indentation(indent) + .newline)
            }
            $0.appendOutput(to: &result, indent: indent)
        }
    }
}

extension Value {
    var count: Int {
        switch self {
        case .text:
            return 1
        case .sub(let sub):
            return sub.values.count
        case .keyed: return 1
        }
    }

    func appendOutput(to result: inout String, indent: Int) {
        switch self {
        case .text(let text):
            result.append(String.indentation(indent) + text + .newline)
        case .sub(let sub):
            sub.appendOutput(to: &result, indent: indent)  // Don't indent here.
        case .keyed(let key, .text(let text)):
            result.append(String.indentation(indent) + key + ": " + text + .newline)
        case .keyed(let key, .sub(let sub)):
            if sub.values.isEmpty {
                result.append(String.indentation(indent) + key + ":" + .newline)
            } else if sub.values.count == 1, case .some(.text(let text)) = sub.values.first {
                result.append(String.indentation(indent) + key + ": " + text + .newline)
            } else if sub.values.count == 1, case .some(.sub(let subsub)) = sub.values.first {
                result.append(String.indentation(indent) + key + ":" + .newline)
                subsub.appendOutput(to: &result, indent: indent + 1)
            } else {
                result.append(String.indentation(indent) + key + ":" + .newline)
                sub.appendOutput(to: &result, indent: indent + 1)
            }
        case .keyed(_, .keyed):
            fatalError("Value.keyed must not contain sub-key.")
        }
    }
}

private let indentationMemo = Mutex<[String]>([])

extension String {
    fileprivate static func indentation(_ indent: Int) -> String {
        indentationMemo.withLock { memo in
            while memo.count <= indent {
                memo.append(String(repeating: " ", count: memo.count * 4))
            }
            return memo[indent]
        }
    }

    fileprivate static let newline: String = "\n"
}

// MARK: Encoding Containers

private struct TextKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    init(codingPath: [CodingKey], values: Values) {
        self.codingPath = codingPath
        self.values = values
    }

    var codingPath: [CodingKey]
    fileprivate var values: Values

    mutating func encodeNil(forKey key: Key) throws {
        self.values.add(text: "", for: key)
    }

    mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
        switch value {
        case let v as TextOutputEncodable:
            self.values.add(text: v.textOutput, for: key)
            v.textOutputLines.forEach {
                self.values.add(text: $0)
            }
        case let text as String:
            self.values.add(text: text, for: key)
        case let b as Bool:
            self.values.add(text: b ? "true" : "false", for: key)
        case let i as Double:
            self.values.add(text: i.description, for: key)
        case let i as Float:
            self.values.add(text: i.description, for: key)

        case let i as UInt:
            self.values.add(text: i.description, for: key)
        case let i as Int:
            self.values.add(text: i.description, for: key)
        case let i as UInt8:
            self.values.add(text: i.description, for: key)
        case let i as Int8:
            self.values.add(text: i.description, for: key)
        case let i as UInt16:
            self.values.add(text: i.description, for: key)
        case let i as Int16:
            self.values.add(text: i.description, for: key)
        case let i as UInt32:
            self.values.add(text: i.description, for: key)
        case let i as Int32:
            self.values.add(text: i.description, for: key)
        case let i as UInt64:
            self.values.add(text: i.description, for: key)
        case let i as Int64:
            self.values.add(text: i.description, for: key)

        case let i as [Double]:
            self.values.add(text: i.description, for: key)
        case let i as [Float]:
            self.values.add(text: i.description, for: key)

        case let i as [UInt]:
            self.values.add(text: i.description, for: key)
        case let i as [Int]:
            self.values.add(text: i.description, for: key)
        case let i as [UInt8]:
            self.values.add(text: i.description, for: key)
        case let i as [Int8]:
            self.values.add(text: i.description, for: key)
        case let i as [UInt16]:
            self.values.add(text: i.description, for: key)
        case let i as [Int16]:
            self.values.add(text: i.description, for: key)
        case let i as [UInt32]:
            self.values.add(text: i.description, for: key)
        case let i as [Int32]:
            self.values.add(text: i.description, for: key)
        case let i as [UInt64]:
            self.values.add(text: i.description, for: key)
        case let i as [Int64]:
            self.values.add(text: i.description, for: key)

        default:
            let nested = self.values.addNestedValues(for: key)
            let e = TextEncoder(values: nested)
            e.codingPath = self.codingPath + [key]
            try value.encode(to: e)
        }
    }

    mutating func nestedContainer<NestedKey>(
        keyedBy _: NestedKey.Type,
        forKey key: Key
    ) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        let nestedPath = self.codingPath + [key]
        let nestedValues = self.values.addNestedValues(for: key)
        let c = TextKeyedEncodingContainer<NestedKey>(codingPath: nestedPath, values: nestedValues)
        return KeyedEncodingContainer(c)
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let nestedPath = self.codingPath + [key]
        let nestedValues = self.values.addNestedValues(for: key)
        return TextUnkeyedEncodingContainer(codingPath: nestedPath, values: nestedValues)
    }

    mutating func superEncoder() -> Encoder {
        fatalError()
    }

    mutating func superEncoder(forKey _: Key) -> Encoder {
        fatalError()
    }
}

/// A type that provides custom text encoding for the ``TextEncoder``.
protocol TextOutputEncodable {
    /// The single-line text representation.
    var textOutput: String { get }
    /// Additional output lines beyond the primary text representation.
    var textOutputLines: [String] { get }
}

private struct TextUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    init(codingPath: [CodingKey], values: Values) {
        self.codingPath = codingPath
        self.values = values
    }

    var codingPath: [CodingKey]
    fileprivate var values: Values

    var count: Int {
        values.values.count
    }

    mutating func encodeNil() throws {
        self.values.add(text: "")
    }

    mutating func encode<T>(_ value: T) throws where T: Encodable {
        switch value {
        case let v as TextOutputEncodable:
            if !v.textOutput.isEmpty {
                self.values.add(text: v.textOutput)
            }
            v.textOutputLines.forEach {
                self.values.add(text: $0)
            }
        case let text as String:
            self.values.add(text: text)
        case let b as Bool:
            self.values.add(text: b ? "true" : "false")
        case let i as Double:
            self.values.add(text: i.description)
        case let i as Float:
            self.values.add(text: i.description)
        case let i as UInt:
            self.values.add(text: i.description)
        case let i as Int:
            self.values.add(text: i.description)
        case let i as UInt8:
            self.values.add(text: i.description)
        case let i as Int8:
            self.values.add(text: i.description)
        case let i as UInt16:
            self.values.add(text: i.description)
        case let i as Int16:
            self.values.add(text: i.description)
        case let i as UInt32:
            self.values.add(text: i.description)
        case let i as Int32:
            self.values.add(text: i.description)
        case let i as UInt64:
            self.values.add(text: i.description)
        case let i as Int64:
            self.values.add(text: i.description)
        default:
            let e = TextEncoder(values: values.addNestedValues())
            e.codingPath = self.codingPath
            try value.encode(to: e)
        }
    }

    mutating func encodeConditional<T>(_ object: T) throws where T: AnyObject, T: Encodable {
        try self.encode(object)
    }

    mutating func encode<T>(contentsOf sequence: T) throws where T: Sequence, T.Element: Encodable {
        let e = TextEncoder(values: values)
        e.codingPath = self.codingPath
        for value in sequence {
            try value.encode(to: e)
        }
    }

    mutating func nestedContainer<NestedKey>(keyedBy _: NestedKey.Type) -> KeyedEncodingContainer<NestedKey>
    where NestedKey: CodingKey {
        let nestedValues = self.values.addNestedValues()
        let c = TextKeyedEncodingContainer<NestedKey>(codingPath: codingPath, values: nestedValues)
        return KeyedEncodingContainer(c)
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let nestedValues = self.values.addNestedValues()
        return TextUnkeyedEncodingContainer(codingPath: self.codingPath, values: nestedValues)
    }

    mutating func superEncoder() -> Encoder {
        fatalError()
    }
}

private struct TextSingleValueEncodingContainer: SingleValueEncodingContainer {
    init(codingPath: [CodingKey], values: Values) {
        self.codingPath = codingPath
        self.values = values
    }

    var codingPath: [CodingKey]
    fileprivate var values: Values

    mutating func encodeNil() throws {
        self.values.add(text: "")
    }

    mutating func encode<T>(_ value: T) throws where T: Encodable {
        switch value {
        case let v as TextOutputEncodable:
            if !v.textOutput.isEmpty {
                self.values.add(text: v.textOutput)
            }
            v.textOutputLines.forEach {
                self.values.add(text: $0)
            }
        case let text as String:
            self.values.add(text: text)
        case let b as Bool:
            self.values.add(text: b ? "true" : "false")
        case let i as Double:
            self.values.add(text: i.description)
        case let i as Float:
            self.values.add(text: i.description)
        case let i as UInt:
            self.values.add(text: i.description)
        case let i as Int:
            self.values.add(text: i.description)
        case let i as UInt8:
            self.values.add(text: i.description)
        case let i as Int8:
            self.values.add(text: i.description)
        case let i as UInt16:
            self.values.add(text: i.description)
        case let i as Int16:
            self.values.add(text: i.description)
        case let i as UInt32:
            self.values.add(text: i.description)
        case let i as Int32:
            self.values.add(text: i.description)
        case let i as UInt64:
            self.values.add(text: i.description)
        case let i as Int64:
            self.values.add(text: i.description)
        default:
            let e = TextEncoder(values: values)
            e.codingPath = self.codingPath
            try value.encode(to: e)
        }
    }
}
