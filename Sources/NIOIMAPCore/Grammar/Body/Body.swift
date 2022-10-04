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
public enum BodyStructure: Hashable {
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

    public var underestimatedCount: Int {
        // The complete part + sub-parts at level 1:
        1 + subpartCount
    }

    public var isEmpty: Bool { false }

    /// Gets the body at the given `position`.
    ///
    /// This will assert if `position` is not a valid part of this ``BodyStructure``.
    ///
    /// - parameter position: The position of the desired body.
    /// - returns: The body located at the given `position`.
    public subscript(position: SectionSpecifier.Part) -> BodyStructure {
        guard
            let r = subBodyStructure(at: position)
        else { fatalError("Invalid SectionSpecifier.Part \(String(reflecting: position))") }
        return r
    }

    /// Gets the body at the given `position`.
    ///
    /// Returns `nil` if the given part does not exist.
    public func find(_ position: SectionSpecifier.Part) -> BodyStructure? {
        subBodyStructure(at: position)
    }

    /// The index of the first part of the body. Note that single-part and multi-part messages always have at least one part. IN
    /// a single-part message, the only part is the message itself.
    public var startIndex: SectionSpecifier.Part {
        []
    }

    /// The last index of the body. Note that this does not go into child nodes, but only considers sibling parts.
    public var endIndex: SectionSpecifier.Part {
        [subpartCount + 1]
    }

    /// Gets the index before the given index.
    /// - parameter i: The index in question.
    /// - returns: The index required to get the previous body part.
    public func index(before i: SectionSpecifier.Part) -> SectionSpecifier.Part {
        guard
            let last = i.array.last
        else { fatalError("Invalid SectionSpecifier.Part \(String(reflecting: i))") }
        // If the last value is larger than 1, we subtract one from it:
        if last > 1 {
            let sibling = SectionSpecifier.Part(Array(i.array.dropLast()) + [last - 1])
            return lastPart(inside: sibling)
        }
        // The last value is 1.
        let parent = i.dropLast()
        return parent
    }

    /// Gets the index after the given index.
    /// - parameter i: The index in question.
    /// - returns: The index required to get the next body part.
    public func index(after i: SectionSpecifier.Part) -> SectionSpecifier.Part {
        guard
            let bs = self.subBodyStructure(at: i)
        else { fatalError("Invalid SectionSpecifier.Part \(String(reflecting: i))") }
        if bs.subpartCount > 0 {
            return i.appending(1)
        }
        var ii = i
        while let last = ii.array.last {
            let parent = ii.dropLast()
            let siblingCount = self.subBodyStructure(at: parent)!.subpartCount
            // Note: parts are 1-based:
            if last < siblingCount {
                return parent.appending(last + 1)
            }
            ii = parent
        }
        return endIndex
    }
}

extension BodyStructure {
    /// Returns the sub-`BodyStructure` for the given part — or `nil` if the part doesn’t exist.
    private func subBodyStructure(at part: SectionSpecifier.Part) -> BodyStructure? {
        guard
            let first = part.array.first
        else { return self }
        guard
            let sub = subBodyStructure(at: first)
        else { return nil }
        return sub.subBodyStructure(at: part.dropFirst())
    }

    private func subBodyStructure(at index: Int) -> BodyStructure? {
        guard index > 0 else { return nil }
        switch self {
        case .singlepart(let part):
            switch part.kind {
            case .message(let message):
                return message.body.subBodyStructure(at: index) ?? message.body
            default:
                // Other single-part do not have sub-parts.
                return nil
            }
        case .multipart(let part):
            guard index <= part.parts.count else { return nil }
            // SectionSpecifier.Part is 1-based:
            return part.parts[index - 1]
        }
    }
}

// MARK: - Helpers

extension BodyStructure {
    /// Enumerates all sub-parts in this `BodyStructure`.
    ///
    /// For each part, the given `closure` will be called with the part’s `SectionSpecifier.Part` and it’s (sub-) `BodyStructure`.
    ///
    /// The closure will be called with `SectionSpecifier.Part` being ordered ascending.
    public func enumerateParts(_ closure: (SectionSpecifier.Part, BodyStructure) throws -> Void) rethrows {
        try closure([], self)
        try recursiveEnumerateParts(parent: [], closure)
    }

    private func recursiveEnumerateParts(parent: SectionSpecifier.Part, _ closure: (SectionSpecifier.Part, BodyStructure) throws -> Void) rethrows {
        guard self.subpartCount > 0 else { return }
        for part in 1 ... self.subpartCount {
            let spec = SectionSpecifier.Part(Array(parent) + [part])
            let bs = self[[part]]
            try closure(spec, bs)
            try bs.recursiveEnumerateParts(parent: spec, closure)
        }
    }

    public var subpartCount: Int {
        switch self {
        case .singlepart(let part):
            switch part.kind {
            case .message(let message):
                return message.body.subpartCount
            default:
                return 0
            }
        case .multipart(let part):
            return part.parts.count
        }
    }

    private func lastPart(inside part: SectionSpecifier.Part) -> SectionSpecifier.Part {
        var result = part
        while let bs = subBodyStructure(at: result) {
            guard bs.subpartCount > 0 else { break }
            result = result.appending(bs.subpartCount)
        }
        return result
    }
}

// MARK: - Types

extension BodyStructure {
    /// The subtype of a multi-part body.
    public struct MediaSubtype: CustomDebugStringConvertible, Hashable {
        /// When used with a `multipart` type, specifies the same data as different formats.
        public static var alternative: Self {
            .init("alternative")
        }

        /// When used with a `multipart` type, specifies compound objects consisting of several related body parts.
        public static var related: Self {
            .init("related")
        }

        /// When used with a `multipart` type, specifies a generic set of mixed data types.
        public static var mixed: Self {
            .init("mixed")
        }

        /// The subtype as a lowercased string
        internal let stringValue: String

        /// The subtype as a lowercased string
        public var debugDescription: String { stringValue }

        /// Creates a new `MediaSubtype` from the given `String`, which will be lowercased.
        /// - parameter rawValue: The subtype as a `String`. Note that the string will be lowercased.
        public init(_ stringValue: String) {
            self.stringValue = stringValue.lowercased()
        }
    }
}

extension String {
    public init(_ other: BodyStructure.MediaSubtype) {
        self = other.stringValue
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
