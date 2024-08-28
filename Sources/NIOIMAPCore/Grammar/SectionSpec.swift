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

/// Specifies a section.
///
/// Is used in a `FETCH` command’s `BODY[<section>]<<partial>>` for the `<section>` part.
///
/// Use `SectionSpecifier.complete` for an empty section specifier (i.e. the complete message).
///
/// These are defined in RFC 3501 section 6.4.5.
public struct SectionSpecifier: Hashable, Sendable {
    /// The part of the body.
    public let part: Part

    /// The type of section, e.g. `HEADER`.
    public let kind: Kind

    /// Creates a new *complete* `SectionSpecifier`.
    ///
    /// Note that only certain `kind` values are valid, based on what kind of part `part` refers to.
    /// See the documentation for ``SectionSpecifier.Kind`` for more details.
    ///
    /// - parameter part: The part of the body. Can only be empty if `kind` is not `.MIMEHeader`.
    /// - parameter kind: The type of section, e.g. *HEADER*. Defaults to `.complete`.
    public init(part: Part = .init([]), kind: Kind = .complete) {
        if part.array.count == 0 {
            precondition(kind != .MIMEHeader, "Cannot use MIME with an empty section part")
        }
        self.part = part
        self.kind = kind
    }
}

extension SectionSpecifier {
    /// Corresponds to no specifier, i.e. the complete message (including its headers).
    public static let complete = SectionSpecifier(kind: .complete)

    /// `Header` -- RFC 2822 header of the message
    public static let header = SectionSpecifier(kind: .header)

    /// `TEXT` -- text body of the message, omitting the RFC 2822 header.
    public static let text = SectionSpecifier(kind: .text)

    /// `HEADER.FIELDS` -- a subset of the RFC 2822 header of the message
    public static func headerFields(_ fields: [String]) -> SectionSpecifier {
        SectionSpecifier(kind: .headerFields(fields))
    }

    /// `HEADER.FIELDS.NOT` -- a subset of the RFC 2822 header of the message
    public static func headerFieldsNot(_ fields: [String]) -> SectionSpecifier {
        SectionSpecifier(kind: .headerFieldsNot(fields))
    }
}

extension SectionSpecifier: Comparable {
    /// Compares two `SectionSpecifier` to evaluate if one (`lhs`) is strictly less than the other (`rhs`).
    /// First the parts are compared. If they are equal then the kind is compared.
    /// - parameter lhs: The first `SectionSpecifier`.
    /// - parameter rhs: The second `SectionSpecifier`.
    /// - returns: `true` if `lhs` is considered strictly *less than* `rhs`, otherwise `false.`
    public static func < (lhs: SectionSpecifier, rhs: SectionSpecifier) -> Bool {
        if lhs.part == rhs.part {
            return lhs.kind < rhs.kind
        } else if lhs.part < rhs.part {
            return true
        } else {
            return false
        }
    }
}

extension SectionSpecifier: CustomDebugStringConvertible {
    /// A textual representation of the `SectionSpecifier` that is inline with the IMAP RFC.
    /// E.g. *.MIME*.
    public var debugDescription: String {
        EncodeBuffer.makeDescription {
            $0.writeSectionSpecifier(self)
        }
    }
}

// MARK: - Types

extension SectionSpecifier {
    /// Specifies a particular body section.
    ///
    /// This corresponds to the part number mentioned in RFC 3501 section 6.4.5.
    ///
    /// Examples are `1`, `4.1`, and `4.2.2.1`.
    public struct Part: Hashable, ExpressibleByArrayLiteral, Sendable {
        /// Each element in the array can be thought of as an index of the section identified by the previous element.
        public typealias ArrayLiteralElement = Int

        /// The underlying array of integer components, where each integer is a sub-part of the previous.
        let array: [Int]

        /// Creates a new `Part` from an array of integers..
        /// - parameter rawValue: The array of integers.
        public init(_ array: [Int]) {
            self.array = array
        }

        /// Creates a new `Part` from an array of integers..
        /// - parameter rawValue: The array of integers.
        public init(arrayLiteral elements: Int...) {
            self.array = elements
        }
    }

    /// The last part of a body section specifier if it’s not a part number.
    ///
    ///  These correspond to the `HEADER`, `TEXT`, `MIME` part specifiers prefixed
    ///  by a numeric part or the sole specifier.
    ///
    ///  The way these work depends on what kind of part the numeric part refers to.
    ///
    ///  For `message/rfc822` (and for the message itself) these are valid:
    ///   * `.complete` (no suffix)
    ///   * `.header` / `HEADER` (and by extension `.headerFields` and `.headerFieldsNot`)
    ///   * `.text` / `TEXT`
    ///
    ///  For other parts (i.e. non-`message/rfc822` and not the message itself) these are valid:
    ///   * `.complete` (the part without its MIME IMB header)
    ///   * `.MIMEHeader` / `MIME` (the MIME IMB header)
    public enum Kind: Hashable, Sendable {
        /// A section specifier that ends in a part number, e.g. `4.2.2.1`.
        ///
        /// If the numeric part refers to the complete message or a `message/rfc822` part, this
        /// will refer to that _complete_ message.
        ///
        /// For any other part (single- or multi-part), it will refer to that parts
        /// content, i.e. it will _not_ include any of the MIME headers of that part.
        case complete
        /// If the numeric part refers to the complete message or a `message/rfc822` part, this
        /// will refer to that message’s headers.
        case header
        /// The specified fields, corresponding to e.g. `4.2.HEADER.FIELDS (SUBJECT)`.
        case headerFields([String])
        /// All except the specified fields, corresponding to e.g. `4.2.HEADER.FIELDS.NOT (SUBJECT)`.
        case headerFieldsNot([String])
        /// MIME IMB header, corresponding to e.g. `4.2.MIME`.
        ///
        /// This is only valid for a part that is _not_ a `message/rfc822` part. And in those cases,
        /// this refers to the MIME IMB header of that (single- or multi-) part.
        case MIMEHeader
        /// Text body without header, corresponding to e.g. `4.2.TEXT`.
        ///
        /// This is only valid for a part that’s a `message/rfc822` part, e.g. the complete message.
        case text
    }
}

extension Array where Element == Int {
    public init(_ other: SectionSpecifier.Part) {
        self = other.array
    }
}

extension SectionSpecifier.Part: Comparable {
    /// Compares two `Part`s to evaluate if one `Part` (`lhs`) is strictly less than the other (`rhs`).
    /// - parameter lhs: The first `Part` for comparison.
    /// - parameter rhs: The first `Part` for comparison.
    /// - returns: `true` if `lhs` evaluates to strictly less than `rhs`, otherwise `false`.
    public static func < (lhs: SectionSpecifier.Part, rhs: SectionSpecifier.Part) -> Bool {
        let minSize = min(lhs.array.count, rhs.array.count)
        for i in 0 ..< minSize {
            if lhs.array[i] == rhs.array[i] {
                continue
            } else if lhs.array[i] < rhs.array[i] {
                return true
            } else {
                return false
            }
        }

        // [1.2.3.4] < [1.2.3.4.5]
        if lhs.array.count < rhs.array.count {
            return true
        } else {
            return false
        }
    }
}

extension SectionSpecifier.Part: CustomDebugStringConvertible {
    /// Produces a textual representation as period-separated numbers (as defined in the IMAP RFC).
    public var debugDescription: String {
        EncodeBuffer.makeDescription {
            $0.writeSectionPart(self)
        }
    }
}

extension SectionSpecifier.Kind: Comparable {
    /// Compares two `Kind`s to evaluate if one (`lhs`) is strictly less than the other (`rhs`).
    /// - parameter lhs: The first `Kind` to compare.
    /// - parameter rhs: The second `Kind` to compare.
    /// - returns:`true` if `lhs` evaluate to strictly less than `rhs`.
    public static func < (lhs: SectionSpecifier.Kind, rhs: SectionSpecifier.Kind) -> Bool {
        switch (lhs, rhs) {
        case (complete, complete):
            return false
        case (complete, header):
            return true
        case (complete, headerFields):
            return true
        case (complete, headerFieldsNot):
            return true
        case (complete, MIMEHeader):
            return true
        case (complete, text):
            return true
        case (header, complete):
            return true
        case (header, header):
            return true
        case (header, headerFields):
            return true
        case (header, headerFieldsNot):
            return true
        case (header, MIMEHeader):
            return true
        case (header, text):
            return true
        case (headerFields, complete):
            return false
        case (headerFields, header):
            return false
        case (headerFields, headerFields):
            return false
        case (headerFields, headerFieldsNot):
            return false
        case (headerFields, MIMEHeader):
            return false
        case (headerFields, text):
            return true
        case (headerFieldsNot, complete):
            return false
        case (headerFieldsNot, header):
            return false
        case (headerFieldsNot, headerFields):
            return false
        case (headerFieldsNot, headerFieldsNot):
            return false
        case (headerFieldsNot, MIMEHeader):
            return false
        case (headerFieldsNot, text):
            return true
        case (MIMEHeader, complete):
            return false
        case (MIMEHeader, header):
            return true
        case (MIMEHeader, headerFields):
            return true
        case (MIMEHeader, headerFieldsNot):
            return true
        case (MIMEHeader, MIMEHeader):
            return false
        case (MIMEHeader, text):
            return true
        case (text, complete):
            return false
        case (text, header):
            return false
        case (text, headerFields):
            return false
        case (text, headerFieldsNot):
            return false
        case (text, MIMEHeader):
            return false
        case (text, text):
            return false
        }
    }
}

// MARK: - Helpers

extension SectionSpecifier.Part {
    /// Returns a `Part` containing all but the initial part number.
    ///
    /// If the `Part` is empty (i.e. the complete message), it returns the empty
    /// `Part` / complete message specifier.
    public func dropFirst() -> SectionSpecifier.Part {
        SectionSpecifier.Part(Array(self.array.dropFirst()))
    }

    /// Returns a `Part` containing all but the last part number.
    ///
    /// If the `Part` is empty (i.e. the complete message), it returns the empty
    /// `Part` / complete message specifier.
    public func dropLast() -> SectionSpecifier.Part {
        SectionSpecifier.Part(Array(self.array.dropLast()))
    }

    /// Returns a `Part` that has the given part number appended.
    public func appending(_ element: Int) -> SectionSpecifier.Part {
        SectionSpecifier.Part(self.array + [element])
    }

    /// Returns `true` if the `other` part is nested inside this `Part`. Returns `false` otherwise.
    public func isSubPart(of other: SectionSpecifier.Part) -> Bool {
        let a = Array(self)
        let b = Array(other)
        guard
            b.count < a.count,
            b != a
        else { return false }
        return zip(a, b).allSatisfy { $0.0 == $0.1 }
    }

    /// Returns `true` if the `other` part is a directly below this `Part`, e.g. `2.1` is a child of `2`, and `2` is a child of the top-level part. Returns `false` otherwise.
    public func isChildPart(of other: SectionSpecifier.Part) -> Bool {
        guard
            self.array.count == other.array.count + 1
        else { return false }
        let a = Array(self).dropLast(1)
        let b = Array(other)[...]
        return b == a
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSectionBinary(_ binary: SectionSpecifier.Part) -> Int {
        self.writeString("[") +
            self.writeSectionPart(binary) +
            self.writeString("]")
    }

    @discardableResult mutating func writeSection(_ section: SectionSpecifier?) -> Int {
        self.writeString("[") +
            self.writeIfExists(section) { (spec) -> Int in
                self.writeSectionSpecifier(spec)
            } +
            self.writeString("]")
    }

    @discardableResult mutating func writeSectionSpecifier(_ spec: SectionSpecifier?) -> Int {
        guard let spec = spec else {
            return 0 // do nothing
        }

        return self.writeSectionPart(spec.part)
            + self.writeIfExists(spec.kind) { (kind) -> Int in
                self.writeSectionKind(kind, dot: spec.part.array.count > 0 && spec.kind != .complete)
            }
    }

    @discardableResult mutating func writeSectionPart(_ part: SectionSpecifier.Part) -> Int {
        self.writeArray(part.array, separator: ".", parenthesis: false) { (element, self) in
            self.writeString("\(UInt32(element))")
        }
    }

    @discardableResult mutating func writeSectionKind(_ kind: SectionSpecifier.Kind, dot: Bool) -> Int {
        let size = dot ? self.writeString(".") : 0
        switch kind {
        case .MIMEHeader:
            return size + self.writeString("MIME")
        case .header:
            return size + self.writeString("HEADER")
        case .headerFields(let list):
            return size +
                self.writeString("HEADER.FIELDS ") +
                self.writeHeaderList(list)
        case .headerFieldsNot(let list):
            return size +
                self.writeString("HEADER.FIELDS.NOT ") +
                self.writeHeaderList(list)
        case .text:
            return size + self.writeString("TEXT")
        case .complete:
            return 0
        }
    }
}
