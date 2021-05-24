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
public struct MailboxPath: Hashable {
    /// The full mailbox name, e.g. *foo/bar*
    public let name: MailboxName

    /// The path separator, e.g. */* in *foo/bar*
    public let pathSeparator: Character?

    /// Creates a new `MailboxPath` with the given data.
    /// - Note: Do not use this initialiser to create a root/sub mailbox that requires validation. Instead use `makeRootMailbox(displayName:pathSeparator:)`
    /// - parameter name: The `MailboxName` containing UTF-7 encoded bytes
    /// - parameter pathSeparator: An optional `Character` used to delimit sub-mailboxes.
    /// - throws: `InvalidPathSeparatorError` if the `pathSeparator` is not a valid ascii value.
    public init(name: MailboxName, pathSeparator: Character? = nil) throws {
        // if a path separator is given, it must be a valid ascii character
        if let pathSeparator = pathSeparator, !pathSeparator.isASCII {
            throw InvalidPathSeparatorError(description: "The path separator must be an ascii value")
        }

        self.name = name
        self.pathSeparator = pathSeparator
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
            return [self.decodeBufferToString(self.name.bytes)]
        }

        assert(pathSeparator.isASCII)
        return self.name.bytes.readableBytesView
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
        guard displayName.utf8.count <= maximumMailboxSize else {
            throw MailboxTooBigError(maximumSize: maximumMailboxSize, actualSize: displayName.utf8.count)
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
        var newStorage = self.name.bytes
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
public struct MailboxName: Hashable {
    /// Represents an inbox.
    public static let inbox = Self(ByteBuffer(string: "INBOX"))

    /// The raw bytes, readable as `[UInt8]`
    public let bytes: ByteBuffer

    /// `true` if the internal storage reads "INBOX"
    /// otherwise `false`
    public var isInbox: Bool {
        bytes.readableBytesView.lazy.map { $0 & 0xDF }.elementsEqual("INBOX".utf8)
    }

    /// Creates a new `MailboxName` from the given bytes.
    /// - note: The bytes provided should be UTF-7.
    /// - parameter bytes: The bytes to construct a `MailboxName` from. Note that if any case-insensitive variation of *INBOX* is provided then it will be uppercased.
    public init(_ bytes: ByteBuffer) {
        let isInbox = bytes.readableBytesView.lazy.map { $0 & 0xDF }.elementsEqual("INBOX".utf8)
        if isInbox {
            self.bytes = ByteBuffer(ByteBufferView("INBOX".utf8))
        } else {
            self.bytes = bytes
        }
    }
}

// MARK: - CustomDebugStringConvertible

extension MailboxName: CustomDebugStringConvertible {
    /// Provides a human-readable description.
    public var debugDescription: String {
        let bytes = self.bytes.readableBytesView.map { $0 & 0xDF }
        return String(decoding: bytes, as: Unicode.UTF8.self)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMailbox(_ mailbox: MailboxName) -> Int {
        self.writeIMAPString(mailbox.bytes)
    }
}
