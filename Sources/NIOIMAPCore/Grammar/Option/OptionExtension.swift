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

/// The type of option extension, either standard or vendor-specific.
///
/// Option extensions are part of the RFC 4466 extension mechanism that allows servers to advertise
/// additional capabilities without breaking existing clients. Extensions can be either standard
/// atoms (like `QRESYNC`) or vendor-specific tags with a vendor prefix and vendor name
/// (like `X-VENDOR-FEATURE`).
///
/// - SeeAlso: [RFC 4466 IMAP4 Extensions: Collected Extensions](https://datatracker.ietf.org/doc/html/rfc4466)
public enum OptionExtensionKind: Hashable, Sendable {
    /// A standard tag, an `atom`.
    case standard(Standard)

    /// A vendor tag, such as `ACME-SORT`.
    case vendor(Vendor)
}

extension OptionExtensionKind {
    /// An `option-standard-tag`
    /// ([RFC 5258 Section 6](https://datatracker.ietf.org/doc/html/rfc5258#section-6)):
    /// ```
    /// option-standard-tag = atom
    /// ```
    ///
    /// ## Validity
    ///
    /// A tag is written to the wire verbatim, so anything that isn't an `atom` is rejected:
    /// ``init(_:)`` returns `nil`, ``init(stringLiteral:)`` traps.
    public struct Standard: Hashable, Sendable {
        let stringValue: String

        /// Creates a standard tag from a string, if the string is an `atom`.
        ///
        /// A string literal resolves to ``init(stringLiteral:)`` instead, which traps rather than
        /// returning `nil`.
        ///
        /// - parameter stringValue: The tag, for example `REMOTE`.
        /// - returns: A new tag, or `nil` if `stringValue` is not an `atom`.
        public init?(_ stringValue: String) {
            guard stringValue.isIMAPAtom else { return nil }
            self.stringValue = stringValue
        }

        init(unchecked stringValue: String) {
            assert(stringValue.isIMAPAtom)
            self.stringValue = stringValue
        }
    }

    /// An `option-vendor-tag`
    /// ([RFC 5258 Section 6](https://datatracker.ietf.org/doc/html/rfc5258#section-6)):
    /// ```
    /// option-vendor-tag = vendor-token "-" atom
    /// ```
    /// `vendor-token` is taken to be `1*ALPHA`, as the parser reads it. So the tag splits
    /// unambiguously at its first `-`: `ACME-SORT-X` is token `ACME`, name `SORT-X`.
    ///
    /// ## Validity
    ///
    /// A tag is written to the wire verbatim, so anything else is rejected: ``init(_:)`` returns
    /// `nil`, ``init(stringLiteral:)`` traps.
    public struct Vendor: Hashable, Sendable {
        let stringValue: String

        /// The `vendor-token`, for example `ACME` in `ACME-SORT`.
        public var token: String {
            String(self.stringValue[..<self.separatorIndex])
        }

        /// The `atom` after the vendor token, for example `SORT` in `ACME-SORT`.
        public var name: String {
            String(self.stringValue[self.stringValue.index(after: self.separatorIndex)...])
        }

        private var separatorIndex: String.Index {
            self.stringValue.firstIndex(of: Self.separator)!
        }

        private static let separator: Character = "-"

        /// Creates a vendor tag from a string, if the string is a valid `option-vendor-tag`.
        ///
        /// A string literal resolves to ``init(stringLiteral:)`` instead, which traps rather than
        /// returning `nil`.
        ///
        /// - parameter stringValue: The tag, for example `ACME-SORT`.
        /// - returns: A new tag, or `nil` if `stringValue` is not a valid `option-vendor-tag`.
        public init?(_ stringValue: String) {
            guard Self.isValidTag(stringValue) else { return nil }
            self.stringValue = stringValue
        }

        init(unchecked stringValue: String) {
            assert(Self.isValidTag(stringValue))
            self.stringValue = stringValue
        }

        /// Whether the given string is `1*ALPHA "-" atom`.
        static func isValidTag(_ string: String) -> Bool {
            guard let index = string.firstIndex(of: separator) else { return false }
            let token = string[..<index]
            let name = string[string.index(after: index)...]
            return !token.isEmpty && token.utf8.allSatisfy(\.isAlpha) && name.isIMAPAtom
        }
    }
}

extension String {
    /// Creates a `String` from an ``OptionExtensionKind/Standard``.
    public init(_ other: OptionExtensionKind.Standard) {
        self = other.stringValue
    }

    /// Creates a `String` from an ``OptionExtensionKind/Vendor``, for example `ACME-SORT`.
    public init(_ other: OptionExtensionKind.Vendor) {
        self = other.stringValue
    }
}

extension OptionExtensionKind.Standard: ExpressibleByStringLiteral {
    /// Creates a standard tag from a string literal.
    ///
    /// - parameter value: The string literal.
    /// - Precondition: `value` is an `atom`; this traps if it isn't.
    public init(stringLiteral value: String) {
        precondition(value.isIMAPAtom, "Invalid option tag: \(String(reflecting: value))")
        self.init(unchecked: value)
    }
}

extension OptionExtensionKind.Vendor: ExpressibleByStringLiteral {
    /// Creates a vendor tag from a string literal.
    ///
    /// - parameter value: The string literal.
    /// - Precondition: `value` is a valid `option-vendor-tag`; this traps if it isn't.
    public init(stringLiteral value: String) {
        precondition(Self.isValidTag(value), "Invalid option vendor tag: \(String(reflecting: value))")
        self.init(unchecked: value)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeOptionExtension(
        _ option: KeyValue<OptionExtensionKind, OptionValueComp?>
    ) -> Int {
        var size = 0
        switch option.key {
        case .standard(let tag):
            size += self.writeAtom(tag.stringValue)
        case .vendor(let tag):
            size += self.writeOptionVendorTag(tag)
        }

        if let value = option.value {
            size += self.writeSpace()
            size += self.writeOptionValue(value)
        }
        return size
    }

    @discardableResult mutating func writeOptionVendorTag(_ tag: OptionExtensionKind.Vendor) -> Int {
        self.writeAtom(tag.stringValue)
    }
}
