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
public enum SectionSpecifier: Equatable {
    case text(_ text: SectionMessageText)
    case part(_ part: Part, text: SectionText?)
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
        
        switch spec {
        case .text(let text):
            return self.writeSectionMessageText(text)
        case .part(let part, text: let text):
            return
                self.writeSectionPart(part) +
                self.writeIfExists(text) { (text) -> Int in
                    self.writeString(".") +
                        self.writeSectionText(text)
                }
        }
    }
    
    @discardableResult mutating func writeSectionPart(_ part: SectionSpecifier.Part) -> Int {
        self.writeArray(part.rawValue, separator: ".", parenthesis: false) { (element, self) in
            self.writeString("\(UInt32(element))")
        }
    }
}
