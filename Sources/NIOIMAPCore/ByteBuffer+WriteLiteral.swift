//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct NIO.ByteBuffer

public struct CapabilityError: Error {
    public var expected: EncodingCapabilities
    public var provided: EncodingCapabilities
}

extension EncodeBuffer {
    @discardableResult mutating func writeIMAPString(_ str: String) -> Int {
        self.writeIMAPString(str.utf8)
    }

    @discardableResult mutating func writeIMAPString(_ str: ByteBuffer) -> Int {
        self.writeIMAPString(str.readableBytesView)
    }

    fileprivate mutating func writeIMAPString<T: Collection>(_ bytes: T) -> Int where T.Element == UInt8 {
        // allSatisfy vs contains because IMO it's a little clearer
        // if more than 70 bytes, always use a literal
        let canUseQuoted = bytes.count <= 70 && bytes.allSatisfy { $0.isQuotedChar }

        if canUseQuoted {
            return self.writeString("\"") + self.writeBytes(bytes) + self.writeString("\"")
        } else {
            return self.writeLiteral(bytes)
        }
    }

    @discardableResult mutating func writeBase64(_ base64: ByteBuffer) -> Int {
        var buffer = base64
        return self.writeBuffer(&buffer)
    }

    @discardableResult mutating func writeLiteral<T: Collection>(_ bytes: T) -> Int where T.Element == UInt8 {
        let length = "{\(bytes.count)}\r\n"
        return self.writeString(length) + self.markStopPoint() + self.writeBytes(bytes)
    }

    @discardableResult mutating func writeLiteral8<T: Collection>(_ bytes: T) -> Int where T.Element == UInt8 {
        self.preconditionCapability(.binary)
        let length = "~{\(bytes.count)}\r\n"
        return
            self.writeString(length) +
            self.markStopPoint() +
            self.writeBytes(bytes)
    }

    @discardableResult mutating func writeNil() -> Int {
        self.writeString("NIL")
    }

    @discardableResult mutating func writeSpace() -> Int {
        self.writeString(" ")
    }

    @discardableResult mutating func writeArray<T>(_ array: [T], separator: String = " ", parenthesis: Bool = true, callback: (T, inout EncodeBuffer) -> Int) -> Int {
        self.writeIfTrue(parenthesis) { () -> Int in
            self.writeString("(")
        } +
            array.enumerated().reduce(0) { (size, row) in
                let (i, element) = row
                return
                    size +
                    callback(element, &self) +
                    self.writeIfTrue(i < array.count - 1) { () -> Int in
                        self.writeString(separator)
                    }
            } +
            self.writeIfTrue(parenthesis) { () -> Int in
                self.writeString(")")
            }
    }

    @discardableResult func writeIfExists<T>(_ value: T?, callback: (inout T) -> Int) -> Int {
        guard var value = value else {
            return 0
        }
        return callback(&value)
    }

    @discardableResult func writeIfTrue(_ value: Bool, callback: () -> Int) -> Int {
        guard value else {
            return 0
        }
        return callback()
    }

    @discardableResult mutating func writeIfArrayHasMinimumSize<T>(array: [T], minimum: Int = 1, callback: ([T], inout EncodeBuffer) throws -> Int) rethrows -> Int {
        guard array.count >= minimum else {
            return 0
        }
        return try callback(array, &self)
    }

    @discardableResult func throwIfMissingCapabilites(_ capabilities: EncodingCapabilities, _ closure: () -> Int) throws -> Int {
        guard self.capabilities.contains(capabilities) else {
            throw CapabilityError(expected: capabilities, provided: self.capabilities)
        }
        return closure()
    }
}
