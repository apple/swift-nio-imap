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
public struct SectionSpecifier: Equatable {
    public internal(set) var part: Part
    public internal(set) var kind: Kind

    public init(part: Part = .init(rawValue: []), kind: Kind) {
        if part.rawValue.count == 0 {
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
    public func headerFields(_ fields: [String]) -> SectionSpecifier {
        SectionSpecifier(kind: .headerFields(fields))
    }

    /// `HEADER.FIELDS.NOT` -- a subset of the RFC 2822 header of the message
    public func headerFieldsNot(_ fields: [String]) -> SectionSpecifier {
        SectionSpecifier(kind: .headerFieldsNot(fields))
    }
}

extension SectionSpecifier: Comparable {
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

// MARK: - Types

extension SectionSpecifier {
    /// Specifies a particular body section.
    ///
    /// This corresponds to the part number mentioned in RFC 3501 section 6.4.5.
    ///
    /// Examples are `1`, `4.1`, and `4.2.2.1`.
    public struct Part: RawRepresentable, Hashable, ExpressibleByArrayLiteral {
        public typealias ArrayLiteralElement = Int

        public var rawValue: [Int]

        public init(rawValue: [Int]) {
            self.rawValue = rawValue
        }

        public init(arrayLiteral elements: Int...) {
            self.rawValue = elements
        }
    }

    /// The last part of a body section sepcifier if it’s not a part number.
    public enum Kind: Hashable {
        /// The entire section, corresponding to a section specifier that ends in a part number, e.g. `4.2.2.1`
        case complete
        /// All header fields, corresponding to e.g. `4.2.HEADER`.
        case header
        /// The specified fields, corresponding to e.g. `4.2.HEADER.FIELDS (SUBJECT)`.
        case headerFields([String])
        /// All except the specified fields, corresponding to e.g. `4.2.HEADER.FIELDS.NOT (SUBJECT)`.
        case headerFieldsNot([String])
        /// MIME IMB header, corresponding to e.g. `4.2.MIME`.
        case MIMEHeader
        /// Text body without header, corresponding to e.g. `4.2.TEXT`.
        case text
    }
}

extension SectionSpecifier.Part: Comparable {
    public static func < (lhs: SectionSpecifier.Part, rhs: SectionSpecifier.Part) -> Bool {
        let minSize = min(lhs.rawValue.count, rhs.rawValue.count)
        for i in 0 ..< minSize {
            if lhs.rawValue[i] == rhs.rawValue[i] {
                continue
            } else if lhs.rawValue[i] < rhs.rawValue[i] {
                return true
            } else {
                return false
            }
        }

        // [1.2.3.4] < [1.2.3.4.5]
        if lhs.rawValue.count < rhs.rawValue.count {
            return true
        } else {
            return false
        }
    }
}

extension SectionSpecifier.Kind: Comparable {
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
                self.writeSectionKind(kind, dot: spec.part.rawValue.count > 0 && spec.kind != .complete)
            }
    }

    @discardableResult mutating func writeSectionPart(_ part: SectionSpecifier.Part) -> Int {
        self.writeArray(part.rawValue, separator: ".", parenthesis: false) { (element, self) in
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
