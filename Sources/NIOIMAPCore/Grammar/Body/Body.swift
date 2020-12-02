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

/// A parsed representation of the MIME-IMB body structure information of the message.
/// Recomended reading: RFC 3501 § 2.6.3 and 7.4.2.
public enum BodyStructure: Equatable {
    /// A message that at the top level contains only one part. Note that a "message" body contains a nested
    /// body, which may itself be multipart.
    case singlepart(Singlepart)

    /// A message that at the top level contains one or more parts.
    case multipart(Multipart)
}

extension BodyStructure: RandomAccessCollection {

    /// The `Element` of a `BodyStructure` is `BodyStructure` itself.
    /// For example a multi-part body may be thought of as an array of multi-part bodies.
    public typealias Element = BodyStructure

    /// Message bodies are indexed using `SectionSpecifier.Part`. Consider a multi-part message to be an n-ary tree. Each node
    /// is a separate multi-part, and may contain sub-nodes, each of which is again a multi-part. `SectionSpecifier.Part` is an array
    /// or integers, where each integer represents the position of a sub-node.
    public typealias Index = SectionSpecifier.Part

    /// Because `BodyStructure` is a recursive type, a`SubSequence` is defined as `Slice<BodyStructure>`.
    public typealias SubSequence = Slice<BodyStructure>

    /// Gets the body at the given `position`.
    /// - parameter position: The position of the desired body.
    /// - returns: The body located at the given `position`.
    public subscript(position: SectionSpecifier.Part) -> BodyStructure {

        // TODO: Can we get rid of this guard if we move the checks to SectionSpecifier.Part.init?
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

    /// The index of the first part of the body. Note that single-part and multi-part messages always have at least one part. IN
    /// a single-part message, the only part is the message itself.
    public var startIndex: SectionSpecifier.Part {
        [1]
    }

    /// The last index of the body. Note that this does not go into child nodes, but only considers sibling parts.
    public var endIndex: SectionSpecifier.Part {
        switch self {
        case .singlepart:
            return [2]
        case .multipart(let part):
            return [part.parts.count + 1]
        }
    }

    /// Gets the index before the given index. Note that this does not go into child nodes, but only considers sibling parts.
    /// - parameter i: The index in question.
    /// - returns: The index required to get the previous body part.
    public func index(before i: SectionSpecifier.Part) -> SectionSpecifier.Part {
        guard let first = i.rawValue.first else {
            fatalError("Must contain at least one number")
        }
        return [first - 1]
    }

    /// Gets the index after the given index. Note that this does not go into child nodes, but only considers sibling parts.
    /// - parameter i: The index in question.
    /// - returns: The index required to get the next body.
    public func index(after i: SectionSpecifier.Part) -> SectionSpecifier.Part {
        guard let first = i.rawValue.first else {
            fatalError("Must contain at least one number")
        }
        return [first + 1]
    }
}

// MARK: - Types

extension BodyStructure {

    /// The subtype of a multi-part body.
    public struct MediaSubtype: RawRepresentable, CustomStringConvertible, Equatable {

        /// `multipart/alternative`. For representing the same data as different formats.
        public static var alternative: Self {
            .init("multipart/alternative")
        }

        /// `multipart/mixed`. Used for compound objects consisting of several related body parts.
        public static var related: Self {
            .init("multipart/related")
        }

        /// `multipart/mixed`. Specifies a generic set of mixed data types.
        public static var mixed: Self {
            .init("multipart/mixed")
        }

        /// The subtype as a lowercased string
        public var rawValue: String

        /// See `.rawValue`.
        public var description: String {
            rawValue
        }

        /// Creates a new `MediaSubtype` from the given `String`, which will be lowercased.
        /// - parameter rawValue: The subtype as a `String`. Note that the string will be lowercased.
        public init(rawValue: String) {
            self.rawValue = rawValue.lowercased()
        }

        /// Creates a new `MediaSubtype` from the given `String`, which will be lowercased.
        /// - parameter rawValue: The subtype as a `String`. Note that the string will be lowercased.
        public init(rawValue: String) {
            self.rawValue = rawValue.lowercased()
        }

        /// Creates a new `MediaSubtype` from the given `String`, which will be lowercased.
        /// - parameter rawValue: The subtype as a `String`. Note that the string will be lowercased.
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
