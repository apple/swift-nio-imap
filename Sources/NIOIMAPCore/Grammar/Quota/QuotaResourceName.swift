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

import struct NIO.ByteBuffer

extension QuotaResource {
    /// The name of a quota resource, such as `STORAGE` or `MESSAGE`.
    ///
    /// [RFC 9208](https://www.rfc-editor.org/rfc/rfc9208.html#section-7) has a single
    /// `resource-name` production, shared by the `QUOTA` response and the `SETQUOTA` command:
    /// ```
    /// resource-name     = "STORAGE" / "MESSAGE" / "MAILBOX" /
    ///                     "ANNOTATION-STORAGE" / resource-name-ext
    /// resource-name-ext = atom
    /// ```
    /// Hence both ``QuotaResource`` and ``QuotaLimit`` name their resource with this type.
    ///
    /// ## Validity
    ///
    /// A name is an `atom`, so it can always be written to the wire as-is. Anything else is
    /// rejected, in one of two ways:
    ///
    /// - ``init(_:)`` returns `nil`. Use it for a name derived from input, which is what keeps a
    ///   name built from untrusted input from injecting arbitrary IMAP into the stream.
    /// - ``init(stringLiteral:)`` traps. A literal is written by the programmer, so an invalid one
    ///   is a bug to be caught on first run rather than handled.
    ///
    /// Note that a string literal picks the trapping initializer: `Name("STORAGE")` is a `Name`,
    /// whereas `Name(someString)` is a `Name?`.
    ///
    /// ## Case handling
    ///
    /// Names are compared case-insensitively, but preserve their original casing when encoded and
    /// decoded — RFC 9208 §7: "Except as noted otherwise, all alphabetic characters are case
    /// insensitive."
    ///
    /// - SeeAlso: [RFC 9208 Section 5](https://www.rfc-editor.org/rfc/rfc9208.html#section-5)
    public struct Name: Hashable, Sendable {
        /// The case-preserved raw string representation of the name.
        let rawValue: String

        /// Creates a resource name from a string, if the string is a valid name.
        ///
        /// A string literal resolves to ``init(stringLiteral:)`` instead, which traps rather than
        /// returning `nil`.
        ///
        /// - parameter string: The name, for example `STORAGE`.
        /// - returns: A new name, or `nil` if `string` is not an `atom`.
        public init?(_ string: String) {
            guard Name.isValidName(string) else { return nil }
            self.rawValue = string
        }

        init(unchecked string: String) {
            assert(Name.isValidName(string))
            self.rawValue = string
        }

        /// Whether the given string is a `resource-name`, i.e. an `atom`.
        static func isValidName(_ string: String) -> Bool {
            string.isIMAPAtom
        }

        /// Performs a case-insensitive equality comparison.
        ///
        /// - parameter lhs: The first name to compare.
        /// - parameter rhs: The second name to compare.
        /// - returns: `true` if the names are equal (case-insensitive), otherwise `false`.
        public static func == (lhs: Name, rhs: Name) -> Bool {
            lhs.rawValue.uppercased() == rhs.rawValue.uppercased()
        }

        /// Hashes the name for use in sets and dictionaries.
        ///
        /// Hashing is case-insensitive, matching `==`.
        ///
        /// - parameter hasher: The hasher to update with this name's hash value.
        public func hash(into hasher: inout Hasher) {
            rawValue.uppercased().hash(into: &hasher)
        }
    }
}

extension String {
    /// Creates a `String` from a ``QuotaResource/Name``.
    ///
    /// - parameter other: The name to convert.
    public init(_ other: QuotaResource.Name) {
        self = other.rawValue
    }
}

extension QuotaResource.Name: CustomDebugStringConvertible {
    /// A debug representation showing the name in IMAP format.
    public var debugDescription: String {
        EncodeBuffer.makeDescription {
            _ = $0.writeQuotaResourceName(self)
        }
    }
}

// MARK: - Convenience

extension QuotaResource.Name {
    /// The `STORAGE` resource: the physical space estimate, in units of 1024 octets, of the
    /// mailboxes governed by the quota root.
    ///
    /// This is an estimate, not the sum of the messages' `RFC822.SIZE` — metadata and compression
    /// can make it differ in either direction. RFC 2087 defined it as that sum; RFC 9208 does not.
    ///
    /// - SeeAlso: [RFC 9208 Section 5.1](https://www.rfc-editor.org/rfc/rfc9208.html#section-5.1)
    public static let storage: Self = "STORAGE"

    /// The `MESSAGE` resource: the number of messages stored within the mailboxes governed by the
    /// quota root.
    ///
    /// - SeeAlso: [RFC 9208 Section 5.2](https://www.rfc-editor.org/rfc/rfc9208.html#section-5.2)
    public static let message: Self = "MESSAGE"

    /// The `MAILBOX` resource: the number of mailboxes governed by the quota root.
    ///
    /// - SeeAlso: [RFC 9208 Section 5.3](https://www.rfc-editor.org/rfc/rfc9208.html#section-5.3)
    public static let mailbox: Self = "MAILBOX"

    /// The `ANNOTATION-STORAGE` resource: the maximum size of all annotations, in units of 1024
    /// octets, associated with all messages in the mailboxes governed by the quota root.
    ///
    /// Annotations are defined in [RFC 5257](https://www.rfc-editor.org/rfc/rfc5257.html).
    ///
    /// - SeeAlso: [RFC 9208 Section 5.4](https://www.rfc-editor.org/rfc/rfc9208.html#section-5.4)
    public static let annotationStorage: Self = "ANNOTATION-STORAGE"
}

// MARK: - String Literal

extension QuotaResource.Name: ExpressibleByStringLiteral {
    /// Creates a resource name from a string literal.
    ///
    /// For example, `let name: QuotaResource.Name = "X-VENDOR"`. A literal is written by the
    /// programmer, not derived from input, so an invalid one is a bug to be caught on first run
    /// rather than handled. Use ``init(_:)`` for anything else.
    ///
    /// Note that a literal argument also resolves here: `Name("STORAGE")` is a `Name`, not a
    /// `Name?`.
    ///
    /// - parameter value: The string literal.
    /// - Precondition: `value` is an `atom`; this traps if it isn't.
    public init(stringLiteral value: String) {
        precondition(Self.isValidName(value), "Invalid quota resource name: \(String(reflecting: value))")
        self.init(unchecked: value)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeQuotaResourceName(_ name: QuotaResource.Name) -> Int {
        self.writeAtom(name.rawValue)
    }
}
