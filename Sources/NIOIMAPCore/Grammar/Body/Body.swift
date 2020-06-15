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

/// IMAOv4 body
public enum BodyStructure: Equatable {
    case singlepart(Singlepart)
    case multipart(Multipart)
}

extension BodyStructure: RandomAccessCollection {
    
    public typealias Element = BodyStructure
    
    public typealias Index = SectionSpecifier.Part
    
    public typealias SubSequence = Slice<BodyStructure>
    
    public subscript(position: SectionSpecifier.Part) -> BodyStructure {
        _read {
            switch self {
            case .singlepart(let part):
                switch part.type {
                case .basic(let basic):
                    fatalError("Test")
                case .message(let message):
                    fatalError("Test")
                case .text(let text):
                    fatalError("Test")
                }
                
            case .multipart(let part):
                fatalError("Error")
            }
        }
    }
    
    public var startIndex: SectionSpecifier.Part {
        [1] // both singleparts and multiparts always have at least one part
    }
    
    public var endIndex: SectionSpecifier.Part {
        switch self {
        case .singlepart(_):
            return [2]
        case .multipart(let part):
            return [part.parts.count + 1]
        }
    }
    
    public func index(before i: SectionSpecifier.Part) -> SectionSpecifier.Part {
        guard let first = i.rawValue.first else {
            fatalError("Must contain at least one number")
        }
        return [first - 1]
    }
    
    public func index(after i: SectionSpecifier.Part) -> SectionSpecifier.Part {
        guard let first = i.rawValue.first else {
            fatalError("Must contain at least one number")
        }
        return [first + 1]
    }
    
}

// MARK: - Types

extension BodyStructure {
    /// IMAPv4rev1 media-subtype
    public struct MediaSubtype: Equatable {
        var _backing: String

        public static var alternative: Self {
            .init("multipart/alternative")
        }

        public static var related: Self {
            .init("multipart/related")
        }

        public static var mixed: Self {
            .init("multipart/mixed")
        }

        public init(_ string: String) {
            self._backing = string.lowercased()
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeBody(_ body: BodyStructure) -> Int {
        var size = 0
        size += self.writeString("(")
        switch body {
        case .singlepart(let part):
            size += self.writeBodyTypeSinglepart(part)
        case .multipart(let part):
            size += self.writeBodyTypeMultipart(part)
        }
        size += self.writeString(")")
        return size
    }
}
