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
    /// upon what `bytes` contains, and what encoding types are supported.
    /// - parameters:
    ///     - bytes: The bytes to write.
    /// - returns: The number of bytes written.
    @discardableResult mutating func writeIMAPString<T: Collection>(_ bytes: T) -> Int where T.Element == UInt8 {
        guard !self.loggingMode else {
            return self.writeIMAPStringLoggingMode(bytes)
        }

        switch stringEncoding(for: bytes) {
        case .quotedString:
            return writeQuotedIMAPString(bytes)
        case .serverLiteral:
            return writeLiteralHeader(byteCount: bytes.count) + writeBytes(bytes)
        case .clientSynchronizingLiteral:
            return writeLiteralHeader(byteCount: bytes.count) + markStopPoint() + writeBytes(bytes)
        case .clientNonSynchronizingLiteral:
            return writeLiteralHeader(byteCount: bytes.count, synchronization: .nonSynchronizing) + writeBytes(bytes)
        }
    }

    /// Whether a literal header is the synchronizing or the non-synchronizing form.
    enum LiteralSynchronization {
        /// `{123}`: synchronizing. A client waits for a continuation request before sending the bytes; a server
        /// sends them right away.
        case synchronizing
        /// `{123+}`: non-synchronizing, RFC 7888 `LITERAL+` and `LITERAL-`. The client sends the bytes right away.
        case nonSynchronizing
    }

    /// The grammar production of a literal.
    enum LiteralKind {
        /// `{123}`: RFC 3501 `literal`.
        case literal
        /// `~{123}`: RFC 3516 `literal8`, which may contain NUL.
        case literal8
    }

    /// Writes the header of an IMAP literal — `{123}CRLF`, or one of its variants.
    /// - parameters:
    ///     - byteCount: The number of bytes that will follow the header.
    ///     - synchronization: `.nonSynchronizing` writes `{123+}` instead of `{123}`.
    ///     - kind: `.literal8` writes the `~` prefix before the `{`.
    /// - returns: The number of bytes written.
    @discardableResult mutating func writeLiteralHeader(
        byteCount: Int,
        synchronization: LiteralSynchronization = .synchronizing,
        kind: LiteralKind = .literal
    ) -> Int {
        var size = 0
        switch kind {
        case .literal:
            break
        case .literal8:
            size += self.writeByte(UInt8(ascii: "~"))
        }
        size += self.writeByte(UInt8(ascii: "{"))
        size += self.writeDecimal(byteCount)
        switch synchronization {
        case .synchronizing:
            size += self.writeString("}\r\n")
        case .nonSynchronizing:
            size += self.writeString("+}\r\n")
        }
        return size
    }

    /// Writes `bytes` as `quoted`, escaping `\` and `"`.
    ///
    /// - Precondition: Every byte is a `TEXT-CHAR`; no check is made.
    mutating func writeQuotedIMAPString<T: Collection>(_ bytes: T) -> Int where T.Element == UInt8 {
        guard !loggingMode else {
            return self.writeRedactedByteCount(bytes.count)
        }
        // Escape into a stack buffer, then copy once: a write per byte would dominate the cost of
        // encoding a quoted mailbox name.
        //
        // Every byte grows to at most two, plus the two surrounding quotes. `shouldUseQuotedString`
        // caps the input at 70 bytes, so this is a small allocation, but the bound above holds
        // whatever it decides.
        let quote = UInt8(ascii: "\"")
        let escape = UInt8(ascii: "\\")
        let count = bytes.count
        return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: 2 * count + 2) { quoted in
            var index = quoted.startIndex
            quoted[index] = quote
            index += 1
            for byte in bytes {
                if byte == escape || byte == quote {
                    quoted[index] = escape
                    index += 1
                }
                quoted[index] = byte
                index += 1
            }
            quoted[index] = quote
            index += 1
            // `appendBytes` rather than `writeBytes`: redaction has already been decided. In logging
            // mode `writeIMAPString` diverts to `writeIMAPStringLoggingMode` before choosing an
            // encoding, so this function is never reached — the guard above is belt and braces.
            return self.appendBytes(UnsafeRawBufferPointer(UnsafeBufferPointer(rebasing: quoted[..<index])))
        }
    }

    private mutating func writeIMAPStringLoggingMode<T: Collection>(_ bytes: T) -> Int where T.Element == UInt8 {
        switch stringEncoding(for: bytes) {
        case .quotedString:
            return writeString(#""∅""#)
        case .serverLiteral:
            return writeLiteralHeader(byteCount: bytes.count) + writeString("∅")
        case .clientSynchronizingLiteral:
            return writeLiteralHeader(byteCount: bytes.count) + markStopPoint() + writeString("∅")
        case .clientNonSynchronizingLiteral:
            return writeLiteralHeader(byteCount: bytes.count, synchronization: .nonSynchronizing) + writeString("∅")
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
            if options.useQuotedString, shouldUseQuotedString(for: bytes) {
                return .quotedString
            } else if options.useNonSynchronizingLiteralPlus {
                return .clientNonSynchronizingLiteral
            } else if options.useNonSynchronizingLiteralMinus, bytes.count <= 4096 {
                return .clientNonSynchronizingLiteral
            } else {
                return .clientSynchronizingLiteral
            }
        case .server(_, options: let options):
            guard options.useQuotedString, shouldUseQuotedString(for: bytes) else {
                return .serverLiteral
            }
            return .quotedString
        }
    }

    private func shouldUseQuotedString<T: Collection>(for bytes: T) -> Bool where T.Element == UInt8 {
        // If more than 70 bytes, always use a literal:
        guard bytes.count <= 70 else { return false }
        // We’ll allow anything ASCII that’s not a control characters.
        // But `\` and `"` will need quoting. If there are too many of those,
        // fall back to using a literal. We also don't allow non-ASCII
        // UTF8, because the test would be very convoluted (we only
        // see bytes here).
        var escapeCount = 0
        return bytes.allSatisfy {
            guard 0x20 <= $0 && $0 <= 0x7e else { return false }
            guard $0 != 0x5c && $0 != 0x22 else {
                escapeCount += 1
                return escapeCount < 6
            }
            return true
        }
    }

    /// Encodes the given bytes as Base64, and then writes them to `self`.
    /// - parameters:
    ///     - bytes: The bytes to encode and write.
    /// - returns: The number of bytes written.
    @discardableResult mutating func writeBytesAsBase64(_ bytes: some Collection<UInt8>) -> Int {
        let encoded = Base64.encodeBytes(bytes: bytes)
        return self.writeBytes(encoded)
    }

    /// Encodes the given raw message bytes as Base64, and then writes them to `self`.
    /// - parameters:
    ///     - region: The bytes to encode and write.
    /// - returns: The number of bytes written.
    @discardableResult mutating func writeBytesAsBase64(_ region: IMAPBuffer) -> Int {
        let encoded = region.withUnsafeBytes { Base64.encodeBytes(bytes: $0.bindMemory(to: UInt8.self)) }
        return self.writeBytes(encoded)
    }

    /// Writes a collection of bytes in the `literal8` syntax defined in RFC 3516.
    /// Allows the `null` byte `\0` to be written.
    /// - parameters:
    ///     - bytes: The raw bytes to write to `self`.
    /// - returns: The number of bytes written.
    @discardableResult mutating func writeLiteral8<T: Collection>(_ bytes: T) -> Int where T.Element == UInt8 {
        self.writeLiteralHeader(byteCount: bytes.count, kind: .literal8) + self.markStopPoint() + self.writeBytes(bytes)
    }

    /// Writes the string `"NIL"` to self.
    /// - returns: The number of bytes written, always 3.
    @discardableResult mutating func writeNil() -> Int {
        self.writeString("NIL")
    }

    /// Writes a single space to `self`
    /// - returns: The number of bytes written, always 1.
    @discardableResult mutating func writeSpace() -> Int {
        self.writeByte(UInt8(ascii: " "))
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
        write(if: collection.count > 0) {
            self.writeString(prefix)
        }
            + write(if: parenthesis) { () -> Int in
                self.writeString("(")
            }
            + collection.enumerated().reduce(0) { (size, row) in
                let (i, element) = row
                return
                    size + writer(element, &self)
                    + write(if: i < collection.count - 1) { () -> Int in
                        self.writeString(separator)
                    }
            }
            + write(if: parenthesis) { () -> Int in
                self.writeString(")")
            }
            + write(if: collection.count > 0) {
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
        write(if: values.count > 0) {
            self.writeString(prefix)
        }
            + write(if: parenthesis) { () -> Int in
                self.writeString("(")
            }
            + values.enumerated().reduce(0) { (size, row) in
                let (i, element) = row
                return
                    size + writer(.init(key: element.0, value: element.1), &self)
                    + write(if: i < values.count - 1) { () -> Int in
                        self.writeString(separator)
                    }
            }
            + write(if: parenthesis) { () -> Int in
                self.writeString(")")
            }
            + write(if: values.count > 0) {
                self.writeString(suffix)
            }
    }

}

// MARK: - Conditional writes

// Free functions, not `EncodeBuffer` methods: a method call `self.write(if: …) { self.write… }`
// borrows `self` while the closure mutates it, so the compiler copies the buffer and the first write
// inside the closure pays for copy-on-write. On a segmented sink, that is a new segment per
// conditional write.

/// Writes using a closure if the given `value` is non-`nil`. This allows for chaining together writes
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

/// Writes using a closure if a condition is met. This allows for chaining together writes
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
