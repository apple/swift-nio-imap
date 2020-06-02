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

/// IMAPv4 `section-spec`
public struct SectionSpecifier: Equatable {
    var part: Part
    var kind: Kind
    
    public init(part: Part = .init(rawValue: []), kind: Kind) {
        if part.rawValue.count == 0 {
            precondition(kind != .MIMEHeader, "Cannot use MIME with an empty section part")
            precondition(kind != .complete, "Must specify a part when using complete")
        }
        self.part = part
        self.kind = kind
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
