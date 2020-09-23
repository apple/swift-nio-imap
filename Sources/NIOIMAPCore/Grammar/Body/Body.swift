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
        guard let first = position.rawValue.first, first > 0 else {
            preconditionFailure("Part must contain a first number > 0")
        }

        switch self {
        case .singlepart(let part):
            switch part.kind {
            case .basic:
                return self
            case .message(let message):
                return message.body
            case .text:
                return self
            }

        case .multipart(let part):
            guard first <= part.parts.count else {
                fatalError("\(first) is out of range")
            }
            if position.rawValue.count == 1 {
                return part.parts[first - 1]
            } else {
                let subPosition = SectionSpecifier.Part(rawValue: Array(position.rawValue.dropFirst()))
                return part.parts[first - 1][subPosition]
            }
        }
    }

    public var startIndex: SectionSpecifier.Part {
        [1] // both singleparts and multiparts always have at least one part
    }

    public var endIndex: SectionSpecifier.Part {
        switch self {
        case .singlepart:
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
    public struct MediaSubtype: RawRepresentable, CustomStringConvertible, Equatable {
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue.lowercased()
        }

        public static var alternative: Self {
            .init("multipart/alternative")
        }

        public static var related: Self {
            .init("multipart/related")
        }

        public static var mixed: Self {
            .init("multipart/mixed")
        }

        public var description: String {
            rawValue
        }

        public init(_ rawValue: String) {
            self.init(rawValue: rawValue)
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
            size += self.writeBodySinglepart(part)
        case .multipart(let part):
            size += self.writeBodyMultipart(part)
        }
        size += self.writeString(")")
        return size
    }
}
