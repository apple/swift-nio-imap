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

extension EncodeBuffer {
    @discardableResult mutating func writeIMAPString(_ str: String) -> Int {
        self.writeIMAPString(str.utf8)
    }

    @discardableResult mutating func writeIMAPString(_ str: ByteBuffer) -> Int {
        self.writeIMAPString(str.readableBytesView)
    }

    fileprivate mutating func writeIMAPString<T: Collection>(_ bytes: T) -> Int where T.Element == UInt8 {
        switch stringEncoding(for: bytes) {
        case .quotedString:
            return writeString("\"") + writeBytes(bytes) + writeString("\"")
        case .serverLiteral:
            return writeString("{\(bytes.count)}\r\n") + writeBytes(bytes)
        case .clientSynchronizingLiteral:
            return writeString("{\(bytes.count)}\r\n") + markStopPoint() + writeBytes(bytes)
        case .clientNonSynchronizingLiteralPlus:
            return writeString("{\(bytes.count)+}\r\n") + writeBytes(bytes)
        case .clientNonSynchronizingLiteralMinus:
            return writeString("{\(bytes.count)-}\r\n") + writeBytes(bytes)
        }
    }

    enum StringEncoding {
        /// `"foo bar"`
        case quotedString
        /// `{7}CRLFfoo bar` (from server to client)
        case serverLiteral
        /// `{7}CRLF` + `foo bar`
        case clientSynchronizingLiteral
        /// `{7+}CRLFfoo bar`
        case clientNonSynchronizingLiteralPlus
        /// `{7-}CRLFfoo bar`
        case clientNonSynchronizingLiteralMinus
    }

    func stringEncoding<T: Collection>(for bytes: T) -> StringEncoding where T.Element == UInt8 {
        switch mode {
        case .client(options: let options):
            if options.useQuotedString, canUseQuotedString(for: bytes) {
                return .quotedString
            } else if options.useNonSynchronizingLiteralMinus, bytes.count <= 4096 {
                return .clientNonSynchronizingLiteralMinus
            } else if options.useNonSynchronizingLiteralPlus {
                return .clientNonSynchronizingLiteralPlus
            } else {
                return .clientSynchronizingLiteral
            }
        case .server(_, options: let options):
            if options.useQuotedString, canUseQuotedString(for: bytes) {
                return .quotedString
            } else {
                return .serverLiteral
            }
        }
    }

    func canUseQuotedString<T: Collection>(for bytes: T) -> Bool where T.Element == UInt8 {
        // allSatisfy vs contains because IMO it's a little clearer
        // if more than 70 bytes, always use a literal
        return bytes.count <= 70 && bytes.allSatisfy { $0.isQuotedChar }
    }

    @discardableResult mutating func writeBufferAsBase64(_ buffer: ByteBuffer) -> Int {
        let encoded = Base64.encode(bytes: buffer.readableBytesView)
        return self.writeString(encoded)
    }

    @discardableResult mutating func writeLiteral8<T: Collection>(_ bytes: T) -> Int where T.Element == UInt8 {
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

    @discardableResult mutating func writeArray<T>(_ array: [T], prefix: String = "", separator: String = " ", parenthesis: Bool = true, callback: (T, inout EncodeBuffer) -> Int) -> Int {
        self.writeIfTrue(parenthesis) { () -> Int in
            self.writeString("(")
        } +
            array.enumerated().reduce(0) { (size, row) in
                let (i, element) = row
                return
                    size +
                    self.writeString(prefix) +
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
}
