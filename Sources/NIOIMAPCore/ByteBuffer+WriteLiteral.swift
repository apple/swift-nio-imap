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
import struct OrderedCollections.OrderedDictionary

extension EncodeBuffer {
    /// Writes an IMAP `string` type as defined by the grammar in RFC 3501.
    /// The function will decide to use either `quoted` or `literal` syntax based
    /// upon what bytes `string` contains, and what encoding types are supported
    /// by the encoding options on `self`.
    /// - parameters:
    ///     - string: The string to write.
    /// - returns: The number of bytes written.
    @discardableResult mutating func writeIMAPString(_ string: String) -> Int {
        self.writeIMAPString(string.utf8)
    }

    /// Writes an IMAP `string` type as defined by the grammar in RFC 3501.
    /// The function will decide to use either `quoted` or `literal` syntax based
    /// upon what bytes `buffer` contains, and what encoding types are supported.
    /// - parameters:
    ///     - buffer: The buffer to write.
    /// - returns: The number of bytes written.
    @discardableResult mutating func writeIMAPString(_ buffer: ByteBuffer) -> Int {
        self.writeIMAPString(buffer.readableBytesView)
    }

    /// Writes an IMAP `string` type as defined by the grammar in RFC 3501.
    /// The function will decide to use either `quoted` or `literal` syntax based
    /// upon what bytes `buffer` contains, and what encoding types are supported.
    /// - parameters:
    ///     - buffer: The buffer to write.
    /// - returns: The number of bytes written.
    @discardableResult mutating func writeIMAPString<T: Collection>(_ bytes: T) -> Int where T.Element == UInt8 {
        guard !self.loggingMode else {
            return self.writeIMAPStringLoggingMode(bytes)
        }

        switch stringEncoding(for: bytes) {
        case .quotedString:
            return writeString("\"") + writeBytes(bytes) + writeString("\"")
        case .serverLiteral:
            return writeString("{\(bytes.count)}\r\n") + writeBytes(bytes)
        case .clientSynchronizingLiteral:
            return writeString("{\(bytes.count)}\r\n") + markStopPoint() + writeBytes(bytes)
        case .clientNonSynchronizingLiteral:
            return writeString("{\(bytes.count)+}\r\n") + writeBytes(bytes)
        }
    }

    private mutating func writeIMAPStringLoggingMode<T: Collection>(_ bytes: T) -> Int where T.Element == UInt8 {
        switch stringEncoding(for: bytes) {
        case .quotedString:
            return writeString(#""∅""#)
        case .serverLiteral:
            return writeString("{\(bytes.count)}\r\n∅")
        case .clientSynchronizingLiteral:
            return writeString("{\(bytes.count)}\r\n") + markStopPoint() + writeString("∅")
        case .clientNonSynchronizingLiteral:
            return writeString("{\(bytes.count)+}\r\n∅")
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
        case clientNonSynchronizingLiteral
    }

    private func stringEncoding<T: Collection>(for bytes: T) -> StringEncoding where T.Element == UInt8 {
        switch mode {
        case .client(options: let options):
            if options.useQuotedString, canUseQuotedString(for: bytes) {
                return .quotedString
            } else if options.useNonSynchronizingLiteralPlus {
                return .clientNonSynchronizingLiteral
            } else if options.useNonSynchronizingLiteralMinus, bytes.count <= 4096 {
                return .clientNonSynchronizingLiteral
            } else {
                return .clientSynchronizingLiteral
            }
        case .server(_, options: let options):
            guard options.useQuotedString, canUseQuotedString(for: bytes) else {
                return .serverLiteral
            }
            return .quotedString
        }
    }

    private func canUseQuotedString<T: Collection>(for bytes: T) -> Bool where T.Element == UInt8 {
        // allSatisfy vs contains because IMO it's a little clearer
        // if more than 70 bytes, always use a literal
        bytes.count <= 70 && bytes.allSatisfy(\.isQuotedChar)
    }

    /// Encodes the given bytes as a Base64 collection, and then writes to `self.`
    /// - parameters:
    ///     - buffer: The `ByteBuffer` to encoded and write.
    /// - returns: The number of bytes written.
    @discardableResult mutating func writeBufferAsBase64(_ buffer: ByteBuffer) -> Int {
        let encoded = Base64.encodeBytes(bytes: buffer.readableBytesView)
        return self.writeBytes(encoded)
    }

    /// Writes a collection of bytes in the `literal8` syntax defined in RFC 3516.
    /// This function allows the `null` byte `\0` to be written.
    /// - parameters:
    ///     - bytes: The raw bytes to write to `self`.
    /// - returns: The number of bytes written.
    @discardableResult mutating func writeLiteral8<T: Collection>(_ bytes: T) -> Int where T.Element == UInt8 {
        let length = "~{\(bytes.count)}\r\n"
        return
            self.writeString(length) + self.markStopPoint() + self.writeBytes(bytes)
    }

    /// Writes the string `"NIL"` to self.
    /// - returns: The number of bytes written, always 3.
    @discardableResult mutating func writeNil() -> Int {
        self.writeString("NIL")
    }

    /// Writes a single space to `self`
    /// - returns: The number of bytes written, always 1.
    @discardableResult mutating func writeSpace() -> Int {
        self.writeString(" ")
    }

    /// Writes the given `collection` as an IMAP array to self using the given `closure` for every element in the collection.
    /// - parameters:
    ///     - array: The elements to write to `self`.
    ///     - prefix: A string to write before anything else, including the parenthesis. This will only be written if `array` has 1 or more elements. Defaults to "".
    ///     - separator: A string to write between each element, defaults to "".
    ///     - suffix: A string to write after anything else, including the parenthesis. This will only be written if `array` has 1 or more elements. Defaults to "".
    ///     - parenthesis: Writes `(` immediately before the first element, and `)` immediately after the last. Enabled by default.
    ///     - writer: The closure to call for each element that writes the element.
    /// - returns: The number of bytes written.
    @discardableResult mutating func writeArray<C, T>(
        _ collection: C,
        prefix: String = "",
        separator: String = " ",
        suffix: String = "",
        parenthesis: Bool = true,
        _ writer: (T, inout EncodeBuffer) -> Int
    ) -> Int where C: RandomAccessCollection, C.Element == T {
        // TODO: This should probably check
        //   collection.count != 0
        // such that an empty collection gets encoded as "()".
        self.write(if: collection.count > 0) {
            self.writeString(prefix)
        }
            + self.write(if: parenthesis) { () -> Int in
                self.writeString("(")
            }
            + collection.enumerated().reduce(0) { (size, row) in
                let (i, element) = row
                return
                    size + writer(element, &self)
                    + self.write(if: i < collection.count - 1) { () -> Int in
                        self.writeString(separator)
                    }
            }
            + self.write(if: parenthesis) { () -> Int in
                self.writeString(")")
            }
            + self.write(if: collection.count > 0) {
                self.writeString(suffix)
            }
    }

    /// Writes the given `OrderedDictionary<Key, Value>` as an IMAP array to self using the given `closure` for every element in the collection.
    /// - parameters:
    ///     - values: The elements to write to `self`.
    ///     - prefix: A string to write before anything else, including the parenthesis. This will only be written if `array` has 1 or more elements. Defaults to "".
    ///     - separator: A string to write between each element, defaults to "".
    ///     - suffix: A string to write after anything else, including the parenthesis. This will only be written if `array` has 1 or more elements. Defaults to "".
    ///     - parenthesis: Writes `(` immediately before the first element, and `)` immediately after the last. Enabled by default.
    ///     - writer: The closure to call for each element that writes the element.
    /// - returns: The number of bytes written.
    @discardableResult mutating func writeOrderedDictionary<K, V>(
        _ values: OrderedDictionary<K, V>,
        prefix: String = "",
        separator: String = " ",
        suffix: String = "",
        parenthesis: Bool = true,
        _ writer: (KeyValue<K, V>, inout EncodeBuffer) -> Int
    ) -> Int {
        // TODO: This should probably check
        //   collection.count != 0
        // such that an empty collection gets encoded as "()".
        self.write(if: values.count > 0) {
            self.writeString(prefix)
        }
            + self.write(if: parenthesis) { () -> Int in
                self.writeString("(")
            }
            + values.enumerated().reduce(0) { (size, row) in
                let (i, element) = row
                return
                    size + writer(.init(key: element.0, value: element.1), &self)
                    + self.write(if: i < values.count - 1) { () -> Int in
                        self.writeString(separator)
                    }
            }
            + self.write(if: parenthesis) { () -> Int in
                self.writeString(")")
            }
            + self.write(if: values.count > 0) {
                self.writeString(suffix)
            }
    }

    /// Writes to self using a closure if the given `value` is non-`nil`. This allows for chaining together writes
    /// when attempting to perform composite writes and return the total number of bytes written.
    /// - parameters:
    ///     - value: The optional field to evaluate.
    ///     - writer: The closure to invoke if `value` is non-`nil`. If `value` exists then it is passed as
    ///     the only argument to this closure.
    /// - returns: The number of bytes written.
    @discardableResult func writeIfExists<T>(_ value: T?, _ writer: (inout T) -> Int) -> Int {
        guard var value = value else {
            return 0
        }
        return writer(&value)
    }

    /// Writes to self using a closure if a condition is met. This allows for chaining together writes
    /// when attempting to perform composite writes and return the total number of bytes written.
    /// - parameters:
    ///     - condition: The condition to evaluate, if `true` then `writer` will be invoked.
    ///     - writer: The closure to invoke if `condition` is met.
    /// - returns: The number of bytes written.
    @discardableResult func write(if condition: Bool, _ writer: () -> Int) -> Int {
        guard condition else {
            return 0
        }
        return writer()
    }
}
