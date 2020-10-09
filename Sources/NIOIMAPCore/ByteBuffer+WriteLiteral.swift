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
    /// Writes an IMAP `string` type as defined by the grammar in RFC 3501.
    /// The function will decide to use either `quoted` or `literal` syntax based
    /// upon what bytes `str` contains, and what encoding types are supported.
    /// - parameters:
    ///     - str: The string to write.
    /// - returns: The number of bytes written `self`.
    @discardableResult mutating func writeIMAPString(_ str: String) -> Int {
        self.writeIMAPString(str.utf8)
    }

    /// Writes an IMAP `string` type as defined by the grammar in RFC 3501.
    /// The function will decide to use either `quoted` or `literal` syntax based
    /// upon what bytes `str` contains, and what encoding types are supported.
    /// - parameters:
    ///     - str: The string to write.
    /// - returns: The number of bytes written `self`.
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

    fileprivate enum StringEncoding {
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

    fileprivate func stringEncoding<T: Collection>(for bytes: T) -> StringEncoding where T.Element == UInt8 {
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

    fileprivate func canUseQuotedString<T: Collection>(for bytes: T) -> Bool where T.Element == UInt8 {
        // allSatisfy vs contains because IMO it's a little clearer
        // if more than 70 bytes, always use a literal
        return bytes.count <= 70 && bytes.allSatisfy { $0.isQuotedChar }
    }

    /// Encodes the given bytes as a Base64 collection, and then writes to `self.`
    /// - parameters:
    ///     - buffer: The `ByteBuffer` to encoded and write.
    /// - returns: The number of bytes written to `self`.
    @discardableResult mutating func writeBufferAsBase64(_ buffer: ByteBuffer) -> Int {
        let encoded = Base64.encode(bytes: buffer.readableBytesView)
        return self.writeString(encoded)
    }

    /// Writes a collection of bytes in the `literal8` syntax defined in RFC 3516.
    /// This function allows the `null` byte `\0` to be written.
    /// - parameters:
    ///     - bytes: The raw bytes to write to `self`.
    /// - returns: The number of bytes written to `self`.
    @discardableResult mutating func writeLiteral8<T: Collection>(_ bytes: T) -> Int where T.Element == UInt8 {
        let length = "~{\(bytes.count)}\r\n"
        return
            self.writeString(length) +
            self.markStopPoint() +
            self.writeBytes(bytes)
    }

    /// Writes the string `"NILL"` to self.
    /// - returns: The number of bytes written to self, always 3.
    @discardableResult mutating func writeNil() -> Int {
        self.writeString("NIL")
    }

    /// Writes a single space to `self`
    /// - returns: The number of bytes written to self, always 1.
    @discardableResult mutating func writeSpace() -> Int {
        self.writeString(" ")
    }

    /// Writes to self using the given `closure` for every element in the given `array`. Several convenience exist
    /// including writing a prefix, suffix, and a per-element separator.
    /// - parameters:
    ///     - array: The array to write to `self`.
    ///     - prefix: A string to before anything else. This will only be written if `array` has 1 or more elements.
    ///     - separator: A string to write inbetween each element.
    ///     - suffix: A string to write after everything else, including the paranethesis (if enabled).
    ///     - parenthesis: Writes `(` immediately before the first element, and `)` immediately after the last.
    ///     - closure: The closure to for each element in the given `array`.
    /// - returns: The number of bytes written to self.
    @discardableResult mutating func writeArray<T>(_ array: [T], prefix: String = "", separator: String = " ", suffix: String = "", parenthesis: Bool = true, closure: (T, inout EncodeBuffer) -> Int) -> Int {
        self.writeIfTrue(array.count > 0) {
            self.writeString(prefix)
        } +
            self.writeIfTrue(parenthesis) { () -> Int in
                self.writeString("(")
            } +
            array.enumerated().reduce(0) { (size, row) in
                let (i, element) = row
                return
                    size +
                    closure(element, &self) +
                    self.writeIfTrue(i < array.count - 1) { () -> Int in
                        self.writeString(separator)
                    }
            } +
            self.writeIfTrue(parenthesis) { () -> Int in
                self.writeString(")")
            } +
            self.writeIfTrue(array.count > 0) {
                self.writeString(suffix)
            }
    }

    /// Writes to self using a callback if the given `value` is non-`nil`. This allows for chaining together writes
    /// when attempting to perform composite writes and return the total number of bytes written.
    /// - parameters:
    ///     - value: The optional field to evaluate.
    ///     - closure: The closure to invoke if `value` is non-`nil`. If `value` exists then it is passed as
    ///     the only argument to this closure.
    /// - returns: The number of bytes written to self.
    @discardableResult func writeIfExists<T>(_ value: T?, closure: (inout T) -> Int) -> Int {
        guard var value = value else {
            return 0
        }
        return closure(&value)
    }

    /// Writes to self using a callback if a condition is met. This allows for chaining together writes
    /// when attempting to perform composite writes and return the total number of bytes written.
    /// - parameters:
    ///     - condition: The condition to evaluate, if `true` then `callback` will be invoked.
    ///     - closure: The closure to invoke if `condition` is met.
    /// - returns: The number of bytes written to self.
    @discardableResult func writeIfTrue(_ condition: Bool, closure: () -> Int) -> Int {
        guard condition else {
            return 0
        }
        return closure()
    }

    /// Invokes the given `closure` if the given `array` size is great than or equal to `minimum`.
    /// - parameters:
    ///     - array: The array who's size to evaluate.
    ///     - minimum: The minimum number of elements that `array` must have for `closure` to be invoked.
    ///     - closure: The closure to invoke if `array` has a size great than or equal to `minimum`.
    ///     the only argument to this closure.
    /// - returns: The number of bytes written to self.
    @discardableResult func writeIfArrayHasMinimumSize<T>(_ array: [T], minimum: Int = 1, closure: ([T]) throws -> Int) rethrows -> Int {
        guard array.count >= minimum else {
            return 0
        }
        return try closure(array)
    }
}
