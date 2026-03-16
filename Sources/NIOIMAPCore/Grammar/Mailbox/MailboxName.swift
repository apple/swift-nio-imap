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
import struct NIO.ByteBufferView

/// The mailbox name exceeded the maximum allowed size.
///
/// See [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501) for mailbox name limitations.
/// The maximum size is typically 1000 bytes.
public struct MailboxTooBigError: Error, Equatable {
    /// The maximum allowed size for a mailbox name, typically 1000 bytes.
    public var maximumSize: Int

    /// The actual size of the mailbox name that exceeded the limit.
    public var actualSize: Int
}

/// A mailbox name contained invalid characters or violated naming constraints.
///
/// This error is raised when a mailbox name contains characters that are not permitted by the IMAP protocol,
/// such as path separators in the display name.
public struct InvalidMailboxNameError: Error, Equatable {
    /// A description of why the mailbox name was considered invalid.
    public var description: String
}

/// A path separator did not meet protocol requirements.
///
/// Path separators in mailbox names have strict requirements defined in
/// [RFC 3501 Section 5.1](https://datatracker.ietf.org/doc/html/rfc3501#section-5.1).
/// The separator must be a single ASCII character.
public struct InvalidPathSeparatorError: Error, Equatable {
    /// A description of why the path separator was considered invalid.
    public var description: String
}

/// A complete mailbox path with an optional delimiter character.
///
/// Mailbox paths use a hierarchical naming convention with an optional path separator character to organize
/// mailboxes into a tree structure. For example, a path like "Sent/Work" would have the name "Sent/Work" with
/// the separator "/" to indicate that "Work" is a child mailbox of "Sent". Path separators are optional, but
/// a simple mailbox like "Inbox" may still have the path separator set to indicate what path separator
/// will be used for nested mailboxes.
///
/// Mailbox names are encoded using [Modified UTF-7](https://datatracker.ietf.org/doc/html/rfc2152)
/// as defined in [RFC 3501 Section 5.1.3](https://datatracker.ietf.org/doc/html/rfc3501#section-5.1.3).
/// The path separator itself must be a single ASCII character.
///
/// ### Example
///
/// ```
/// C: A001 LIST "" "INBOX/Sent/Work"
/// S: * LIST (\NoInferiors) "/" "INBOX/Sent/Work"
/// S: A001 OK LIST completed
/// ```
///
/// The line `* LIST (\NoInferiors) "/" "INBOX/Sent/Work"` creates a ``MailboxPath`` with name bytes
/// representing "INBOX/Sent/Work" and pathSeparator "/" to indicate the hierarchical structure.
///
/// - SeeAlso: ``MailboxName``
public struct MailboxPath: Hashable, Sendable {
    /// The full mailbox path in Modified UTF-7 encoding.
    ///
    /// This name may contain path separator characters and represents the complete hierarchical path
    /// to the mailbox as known to the server. The encoding follows
    /// [RFC 2152](https://datatracker.ietf.org/doc/html/rfc2152) as required by RFC 3501.
    public let name: MailboxName

    // Using this instead of `Character?` to reduce the size of this type.
    // A value of `0` denotes no path separator (i.e. `nil`).
    @usableFromInline
    let _pathSeparator: UInt8

    /// The optional path separator character used to delimit sub-mailboxes.
    ///
    /// If present, this ASCII character (commonly "/" or ".") separates parent and child mailbox names
    /// in the path. Returns `nil` if the mailbox is a top-level mailbox with no hierarchy.
    ///
    /// The separator is determined by the server and is reported in `LIST` responses.
    /// For the special "INBOX" mailbox, the separator may be reported separately from other mailboxes.
    ///
    /// - Returns: The path separator as a `Character`, or `nil` if the mailbox is not hierarchical.
    @inlinable
    public var pathSeparator: Character? {
        (self._pathSeparator == 0) ? nil : Unicode.Scalar(UInt32(self._pathSeparator)).map { Character($0) }
    }

    /// Creates a new `MailboxPath` with the given name and optional path separator.
    ///
    /// This initializer accepts raw bytes and does not perform encoding. Use ``makeRootMailbox(displayName:pathSeparator:)``
    /// to create a new mailbox from a display string with automatic encoding, or ``makeSubMailbox(displayName:)``
    /// to create a hierarchical mailbox path.
    ///
    /// - Parameter name: A ``MailboxName`` containing the mailbox path, typically in Modified UTF-7 encoding
    /// - Parameter pathSeparator: An optional path separator as a single ASCII character
    /// - Throws: ``InvalidPathSeparatorError`` if the path separator is not an ASCII character
    public init(name: MailboxName, pathSeparator: Character? = nil) throws {
        // if a path separator is given, it must be a valid ascii character
        if let pathSeparator, !pathSeparator.isASCII {
            throw InvalidPathSeparatorError(description: "The path separator must be an ascii value")
        }

        self.name = name
        self._pathSeparator = pathSeparator?.asciiValue ?? 0
    }
}

extension MailboxPath {
    static let maximumMailboxSize = 1_000

    func validateUTF8String(_ buffer: ByteBuffer) -> String? {
        var bytesIterator = buffer.readableBytesView.makeIterator()
        var scalars: [Unicode.Scalar] = []
        var utf8Decoder = UTF8()
        while true {
            switch utf8Decoder.decode(&bytesIterator) {
            case .scalarValue(let v):
                scalars.append(v)
            case .emptyInput:
                return String(String.UnicodeScalarView(scalars))
            case .error:
                return nil
            }
        }
    }

    func decodeBufferToString(_ buffer: ByteBuffer) -> String {
        do {
            return try ModifiedUTF7.decode(buffer)
        } catch {
            return String(bestEffortDecodingUTF8Bytes: buffer.readableBytesView)
        }
    }

    /// Splits the mailbox path into human-readable display components using the path separator.
    ///
    /// This method converts the Modified UTF-7-encoded mailbox name to a display string by splitting on
    /// the path separator. The conversion is lossy and intended for display purposes only. Do not use the
    /// returned components as mailbox names for protocol operations.
    ///
    /// The method uses heuristics to decode the path as either Modified UTF-7 (per RFC 3501) or UTF-8.
    /// Many email clients incorrectly encode mailbox names as UTF-8 instead of the required Modified UTF-7,
    /// so this method attempts to handle both formats gracefully.
    ///
    /// - Parameter omittingEmptySubsequences: If `true` (default), empty components between consecutive
    ///   separators are omitted from the result
    /// - Returns: An array of display strings for each mailbox component in the path
    public func displayStringComponents(omittingEmptySubsequences: Bool = true) -> [String] {
        guard let pathSeparator = self.pathSeparator else {
            return [self.decodeBufferToString(ByteBuffer(bytes: self.name.bytes))]
        }

        assert(pathSeparator.isASCII)
        return self.name.bytes
            .split(separator: pathSeparator.asciiValue!, omittingEmptySubsequences: omittingEmptySubsequences)
            .map { bytes in
                self.decodeBufferToString(ByteBuffer(ByteBufferView(bytes)))
            }
    }

    /// Creates a new root mailbox path from a display name.
    ///
    /// This factory method encodes the display name using Modified UTF-7 (RFC 2152) and validates
    /// that the resulting mailbox name does not contain the path separator character (if provided).
    /// Root mailboxes are top-level mailboxes with no parent hierarchy.
    ///
    /// Use this method when creating new mailboxes from user input, as it handles encoding automatically.
    /// For existing mailboxes received from the server, use the initializer directly.
    ///
    /// - Parameter displayName: A human-readable name for the mailbox (will be UTF-7 encoded)
    /// - Parameter pathSeparator: The optional separator character that delimits the mailbox hierarchy
    /// - Throws: ``MailboxTooBigError`` if the encoded name exceeds 1000 bytes
    /// - Throws: ``InvalidMailboxNameError`` if the display name contains the path separator character
    /// - Returns: A new ``MailboxPath`` for the root mailbox
    public static func makeRootMailbox(displayName: String, pathSeparator: Character? = nil) throws -> MailboxPath {
        guard displayName.utf8.count <= self.maximumMailboxSize else {
            throw MailboxTooBigError(maximumSize: self.maximumMailboxSize, actualSize: displayName.utf8.count)
        }

        if let separator = pathSeparator {
            // the new name should not contain a path separator
            if displayName.contains(separator) {
                throw InvalidMailboxNameError(description: "\(displayName) cannot contain the separator \(separator)")
            }
        }

        let encodedNewName = ModifiedUTF7.encode(displayName)
        return try MailboxPath(name: .init(encodedNewName), pathSeparator: pathSeparator)
    }

    /// Creates a nested child mailbox path within this mailbox.
    ///
    /// This method encodes the display name using Modified UTF-7 and appends it as a child to the current
    /// mailbox path. The path separator is inserted between the parent and child names.
    ///
    /// **Important:** This method should only be used when creating new mailboxes that do not yet exist
    /// on the server. For existing mailboxes received from the server, the exact byte sequence of the
    /// mailbox name must be preserved as-is. Re-encoding may produce different bytes if other clients
    /// use non-standard encodings (such as UTF-8 instead of Modified UTF-7), which would create
    /// a different mailbox.
    ///
    /// - Parameter displayName: The name of the child mailbox (will be UTF-7 encoded)
    /// - Throws: ``MailboxTooBigError`` if the resulting path exceeds 1000 bytes
    /// - Throws: ``InvalidMailboxNameError`` if the display name contains the path separator character
    /// - Throws: ``InvalidPathSeparatorError`` if the parent mailbox has no path separator (no hierarchy)
    /// - Returns: A new ``MailboxPath`` representing the child mailbox
    public func makeSubMailbox(displayName: String) throws -> MailboxPath {
        guard let separator = self.pathSeparator else {
            throw InvalidPathSeparatorError(description: "Need a path separator to make a sub mailbox")
        }

        // the new name should not contain a path separator
        if displayName.contains(separator) {
            throw InvalidMailboxNameError(description: "\(displayName) cannot contain the separator \(separator)")
        }

        // if a separator exists, write it after the root mailbox
        var newStorage = ByteBuffer(bytes: self.name.bytes)
        newStorage.writeBytes(separator.utf8)

        var encodedNewName = ModifiedUTF7.encode(displayName)
        newStorage.writeBuffer(&encodedNewName)

        guard newStorage.readableBytes <= Self.maximumMailboxSize else {
            throw MailboxTooBigError(maximumSize: Self.maximumMailboxSize, actualSize: newStorage.readableBytes)
        }

        return try MailboxPath(name: .init(newStorage), pathSeparator: separator)
    }
}

/// A mailbox name represented as a sequence of bytes in Modified UTF-7 encoding.
///
/// A ``MailboxName`` uniquely identifies a specific mailbox on the server but does not include
/// information about the mailbox hierarchy or path separator. In most cases, use ``MailboxPath``
/// instead, which includes both the name and the optional path separator to enable hierarchical
/// mailbox operations.
///
/// ``MailboxName`` is optimized for use as a dictionary key or in comparisons by pre-calculating
/// and caching its hash value. This makes equality checks and hashing very efficient.
///
/// Mailbox names follow [RFC 3501 Section 5.1](https://datatracker.ietf.org/doc/html/rfc3501#section-5.1)
/// and must be encoded in Modified UTF-7 as defined by [RFC 2152](https://datatracker.ietf.org/doc/html/rfc2152).
/// The special mailbox name "INBOX" is case-insensitive per RFC 3501 and is automatically normalized to uppercase.
///
/// For stable mailbox identification across renames, use ``MailboxID`` instead. The `OBJECTID` extension
/// ([RFC 8474](https://datatracker.ietf.org/doc/html/rfc8474)) provides a permanent server-assigned identifier
/// that persists even if the mailbox name changes, and is recommended when the server supports it.
///
/// - SeeAlso: ``MailboxPath``, ``MailboxID``
public struct MailboxName: Sendable {
    /// The special "INBOX" mailbox name.
    ///
    /// INBOX is the default mailbox that all IMAP clients must be able to access.
    /// Per [RFC 3501 Section 5.1](https://datatracker.ietf.org/doc/html/rfc3501#section-5.1),
    /// the name "INBOX" is case-insensitive and is always normalized to uppercase.
    public static let inbox = Self(ByteBuffer(string: "INBOX"))

    /// The raw bytes of the mailbox name, typically in Modified UTF-7 encoding.
    ///
    /// These bytes represent the mailbox name as transmitted in the IMAP protocol.
    /// Use this when encoding/decoding mailbox information for wire transmission.
    public let bytes: [UInt8]

    /// The pre-calculated hash value for this mailbox name.
    ///
    /// The hash is cached for performance when using ``MailboxName`` as a dictionary key
    /// or in hash-based collections. Hash calculation is performed once at initialization time
    /// using the mailbox name bytes.
    ///
    /// - Returns: The hash value as an `Swift/Int`
    @inlinable
    public var hashValue: Int {
        self._hashValue.value
    }

    @usableFromInline
    let _hashValue: HashValue

    /// A Boolean value indicating whether this is the special "INBOX" mailbox.
    ///
    /// Returns `true` if the mailbox name is "INBOX" (case-insensitive), `false` otherwise.
    /// Per [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501), the special mailbox "INBOX"
    /// is case-insensitive and unique per user.
    ///
    /// - Returns: `true` if this is the INBOX mailbox, `false` otherwise
    public var isInbox: Bool {
        self.hashValue == MailboxName.inboxHashValue && self.bytes.count == 5
            && self.bytes.map { $0 & 0xDF }.elementsEqual("INBOX".utf8)
    }

    private static let inboxHashValue: Int = MailboxName.inbox.hashValue

    /// Creates a new mailbox name from a sequence of bytes.
    ///
    /// The bytes provided should represent a mailbox name in Modified UTF-7 encoding as per
    /// [RFC 3501 Section 5.1.3](https://datatracker.ietf.org/doc/html/rfc3501#section-5.1.3).
    /// The special mailbox name "INBOX" is case-insensitive and will be automatically normalized to uppercase
    /// to ensure consistent equality comparisons and hash values.
    ///
    /// - Parameter bytes: The mailbox name bytes, typically in Modified UTF-7 encoding
    public init(_ bytes: [UInt8]) {
        let isInbox = bytes.lazy.map { $0 & 0xDF }.elementsEqual("INBOX".utf8)
        let b: [UInt8]
        if isInbox {
            b = Array("INBOX".utf8)
        } else {
            b = bytes
        }
        self.bytes = b
        self._hashValue = b.withUnsafeBytes {
            HashValue($0)
        }
    }
}

extension MailboxName {
    /// A helper to store a hash value (for ``Swift/Hashable`` conformance) inside
    /// a ``Swift/UInt32`` (i.e. 4 bytes) even on platforms where ``Swift/Int`` is 64 bit.
    @usableFromInline
    struct HashValue: Sendable {
        @usableFromInline
        let _value: UInt32

        init(_ bytes: UnsafeRawBufferPointer) {
            self._value = bytes.withMemoryRebound(to: UInt8.self) {
                murmur($0)
            }
        }

        @inlinable
        var value: Int {
            let a = UInt64(_value)
            return Int(truncatingIfNeeded: Int64(bitPattern: (a << 32) | a))
        }
    }
}

private func murmur(_ bytes: UnsafeBufferPointer<UInt8>) -> UInt32 {
    let c1: UInt64 = 0x87c3_7b91_1142_53d5
    let c2: UInt64 = 0x4cf5_ad43_2745_937f

    var byteIterator = bytes.makeIterator()
    func next() -> UInt64? {
        guard
            let a = byteIterator.next()
        else { return nil }
        var result = UInt64(a)
        for _ in 1..<8 {
            guard let b = byteIterator.next() else { break }
            result = result << 8 | UInt64(b)
        }
        return result
    }

    func rotl64(_ x: UInt64, _ r: UInt64) -> UInt64 {
        (x << r) | (x >> (64 - r))
    }

    func fmix64(_ k: inout UInt64) {
        k ^= k >> 33
        k = k &* 0xff51_afd7_ed55_8ccd as UInt64
        k ^= k >> 33
        k = k &* 0xc4ce_b9fe_1a85_ec53 as UInt64
        k ^= k >> 33
    }

    var h1: UInt64 = 0x220f_a127_22e8_87a4
    var h2 = h1
    while var k1 = next() {
        var k2: UInt64 = next() ?? 0

        k1 = k1 &* c1
        k1 = rotl64(k1, 31)
        k1 = k1 &* c2
        h1 ^= k1

        h1 = rotl64(h1, 27)
        h1 = h1 &+ h2
        h1 = h1 &* 5 &+ 0x52dc_e729

        k2 = k2 &* c2
        k2 = rotl64(k2, 33)
        k2 = k2 &* c1
        h2 ^= k2

        h2 = rotl64(h2, 31)
        h2 = h1 &+ h1
        h2 = h2 &* 5 &+ 0x3849_5ab5
    }

    let len = UInt64(clamping: bytes.count)
    h1 ^= len
    h2 ^= len

    h1 = h1 &+ h2
    h2 = h2 &+ h1

    fmix64(&h1)
    fmix64(&h2)

    h1 = h1 &+ h2
    h2 = h2 &+ h1

    let a = h1 ^ h2
    return UInt32(truncatingIfNeeded: a ^ (a >> 32))
}

extension MailboxName {
    public init(_ bytes: ByteBuffer) {
        self = bytes.withUnsafeReadableBytes { buffer in
            MailboxName(Array(buffer.bindMemory(to: UInt8.self)))
        }
    }
}

// MARK: - Hashable

extension MailboxName: Hashable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        // Compare the digest first, since it’s a lot cheaper to compare:
        guard lhs.hashValue == rhs.hashValue else { return false }
        return lhs.bytes == rhs.bytes
    }

    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.hashValue)
    }
}

// MARK: - CustomDebugStringConvertible

extension MailboxName: CustomDebugStringConvertible {
    /// Provides a human-readable description.
    public var debugDescription: String {
        String(bestEffortDecodingUTF8Bytes: self.bytes)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMailbox(_ mailbox: MailboxName) -> Int {
        self.writeIMAPString(mailbox.bytes)
    }
}
