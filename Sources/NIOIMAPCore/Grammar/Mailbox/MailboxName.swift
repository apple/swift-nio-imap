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

/// The `MailboxName` was too big - typically > 1000 bytes.
public struct MailboxTooBigError: Error, Equatable {
    /// Specifies the maximum size of a `MailboxName`, typically 1000 bytes.
    public var maximumSize: Int

    /// The actual size of the attempted `MailboxName`.
    public var actualSize: Int
}

/// The `MailboxName` was invalid, and probably contained illegal characters.
public struct InvalidMailboxNameError: Error, Equatable {
    /// Information on why the `MailboxName` was considered invalid.
    public var description: String
}

/// The path separator was invalid - path separators have strict requirements. See RFC 3501 for more details.
public struct InvalidPathSeparatorError: Error, Equatable {
    /// Information on why the path separator was considered invalid.
    public var description: String
}

/// Represents a complete mailbox path, delimited by the `pathSeparator`.
/// For example, *foo/bar* is the `MailboxName`, and so "/" would be the `pathSeparator`.
/// Path separators are optional, and so the simple `MailboxName` *foo* has `pathSeparator = nil`.
public struct MailboxPath: Hashable, Sendable {
    /// The full mailbox name, e.g. *foo/bar*
    public let name: MailboxName

    // Using this instead of `Character?` to reduce the size of this type.
    // A value of `0` denotes no path separator (i.e. `nil`).
    @usableFromInline
    let _pathSeparator: UInt8

    /// The path separator, e.g. */* in *foo/bar*
    @inlinable
    public var pathSeparator: Character? {
        (self._pathSeparator == 0) ? nil : Unicode.Scalar(UInt32(self._pathSeparator)).map { Character($0) }
    }

    /// Creates a new `MailboxPath` with the given data.
    /// - Note: Do not use this initialiser to create a root/sub mailbox that requires validation. Instead use `makeRootMailbox(displayName:pathSeparator:)`
    /// - parameter name: The `MailboxName` containing UTF-7 encoded bytes
    /// - parameter pathSeparator: An optional `Character` used to delimit sub-mailboxes. Note that this needs to be an ASCII character.
    /// - throws: `InvalidPathSeparatorError` if the `pathSeparator` is not a valid ascii value.
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

    /// Splits `mailbox` into constituent path components using the `PathSeparator`. Conversion is lossy and
    /// for display purposes only, do not use the return value as a mailbox name.
    /// The conversion to display string using heuristics to determine if the byte stream is the modified version of UTF-7 encoding defined in RFC 2152 (which it should be according to RFC 3501) — or if it is UTF-8 data. Many email clients erroneously encode mailbox names as UTF-8.
    /// - returns: `[String]` containing path components
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

    /// Creates a new root mailbox. The given display string will be encoded according to RFC 2152
    /// and then vlaidate that there are no path separators in the name.
    /// - parameter displayName: The name of the new mailbox
    /// - parameter pathSeparator: The optional separator to delimit sub-mailboxes
    /// - throws: `MailboxTooBigError` if the `displayName` is > 1000 bytes.
    /// - throws: `InvalidMailboxNameError` if the `displayName` contains a `pathSeparator`.
    /// - returns: A new `MailboxPath` containing the given name and separator.
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

    /// Creates a new mailbox path that nested inside the existing path.
    ///
    /// This will encode the display string according to RFC 2152
    /// and make sure that there are no path separators in the name,
    /// and then append the path separator and the name to the
    /// existing path’s name.
    ///
    /// This should _only_ be used in order to create the path / name for a new mailbox
    /// that the client wants to create. It should not be used to create paths that already exist
    /// on the server. The reason is that mailboxes are identified by the exact byte sequence
    /// of their name. Re-assembling a path and doing the required encoding might produce
    /// different byte sequences if another client uses a bogus encoding. Sadly that is rather
    /// common.
    /// - parameter displayName: The name of the sub-mailbox to create, which will be UTF-7 encoded.
    /// - throws: `MailboxTooBigError` if new mailbox path is > 1000 bytes.
    /// - throws: `InvalidMailboxNameError` if the `displayName` contains a `pathSeparator`.
    /// - returns: A new `MailboxPath` containing the given name and separator.
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

/// A mailbox’s name.
///
/// This uniquely identifies a specific mailbox, but does not specify the
/// path separator. In most cases, using a `MailboxPath` should be preferred since
/// `MailboxPath` is able to
/// 1. create a (display) `String` from a path.
/// 2. create a path from a `String` (for new mailboxes created by a user)
/// 3. split a path into its components (to figure out how paths are nested into each other).
///
/// Since it’s common to use `MailboxName` as a key in a dictionary and/or compare
/// `MailboxName` for equality, `MailboxName` will pre-calculate its hash value, and
/// store it. As a result `Hashable` (and `Equatable`) performance is very fast.
public struct MailboxName: Sendable {
    /// Represents an inbox.
    public static let inbox = Self(ByteBuffer(string: "INBOX"))

    /// The raw bytes, readable as `[UInt8]`
    public let bytes: [UInt8]
    /// The hash value.
    ///
    /// We store a pre-calculated hash value to make `Hashable` conformance fast.
    @inlinable
    public var hashValue: Int {
        self._hashValue.value
    }

    @usableFromInline
    let _hashValue: HashValue

    /// `true` if the internal storage reads "INBOX"
    /// otherwise `false`
    public var isInbox: Bool {
        self.hashValue == MailboxName.inboxHashValue && self.bytes.count == 5
            && self.bytes.map { $0 & 0xDF }.elementsEqual("INBOX".utf8)
    }

    private static let inboxHashValue: Int = MailboxName.inbox.hashValue

    /// Creates a new `MailboxName` from the given bytes.
    /// - note: The bytes provided should be UTF-7.
    /// - parameter bytes: The bytes to construct a `MailboxName` from. Note that if any case-insensitive variation of *INBOX* is provided then it will be uppercased.
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
    /// A helper to store a hash value (for `Hashable` conformance) inside
    /// a `UInt32` (i.e. 4 bytes) even on platforms where `Int` is 64 bit.
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
