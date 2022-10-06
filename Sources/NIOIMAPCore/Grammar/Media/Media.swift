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

/// Namespaces various related types for API cleanliness
public enum Media {}

extension Media {
    /// An RFC 2045 media type, also known as MIME type.
    public struct MediaType: Hashable {
        public var topLevel: TopLevelType
        public var sub: Subtype

        public init(topLevel: TopLevelType, sub: Subtype) {
            self.topLevel = topLevel
            self.sub = sub
        }
    }
}

extension Media.MediaType {
    public init(topLevel: String, sub: String) {
        self.topLevel = Media.TopLevelType(topLevel)
        self.sub = Media.Subtype(sub)
    }
}

// MARK: - Top-Level Type

extension Media {
    /// The RFC 2045 “top-level type” of a “media type”.
    ///
    /// E.g. for `text/plain`, the top-level type is `text`.
    public struct TopLevelType: CustomDebugStringConvertible, Hashable {
        /// application
        public static let multipart = Self("multipart")

        /// text
        public static let text = Self("text")

        /// application
        public static let application = Self("application")

        /// audio
        public static let audio = Self("audio")

        /// image
        public static let image = Self("image")

        /// message
        public static let message = Self("message")

        /// video
        public static let video = Self("video")

        /// font
        public static let font = Self("font")

        /// The raw lowercased string representation of the type.
        internal let stringValue: String

        /// The type as a lowercased string
        public var debugDescription: String {
            self.stringValue
        }

        /// Creates a new `BasicKind` from a given `String`.
        /// - parameter rawValue: A string that represents the type, note that this will be lowercased.
        public init(_ stringValue: String) {
            self.stringValue = stringValue.lowercased()
        }
    }
}

extension Media.TopLevelType: ExpressibleByStringLiteral {
    public init(stringLiteral: String) {
        self.init(stringLiteral)
    }
}

extension String {
    public init(_ other: Media.TopLevelType) {
        self = other.stringValue
    }
}

// MARK: - Sub-Type

extension Media {
    /// The RFC 2045 “subtype” of a “media type”.
    ///
    /// E.g. for `text/plain`, the subtype is `plain`.
    public struct Subtype: CustomDebugStringConvertible, Hashable {
        /// When used with a `multipart` type, specifies the same data as different formats.
        public static let alternative = Self("alternative")

        /// When used with a `multipart` type, specifies compound objects consisting of several related body parts.
        public static let related = Self("related")

        /// When used with a `multipart` type, specifies a generic set of mixed data types.
        public static var mixed = Self("mixed")

        /// `message` sub-type.
        public static var rfc822 = Self("rfc822")

        /// The subtype as a lowercased string
        internal let stringValue: String

        /// The subtype as a lowercased string
        public var debugDescription: String { self.stringValue }

        /// Creates a new `Media.Subtype` from the given `String`, which will be lowercased.
        /// - parameter rawValue: The subtype as a `String`. Note that the string will be lowercased.
        public init(_ stringValue: String) {
            self.stringValue = stringValue.lowercased()
        }
    }
}

extension Media.Subtype: ExpressibleByStringLiteral {
    public init(stringLiteral: String) {
        self.init(stringLiteral)
    }
}

extension String {
    public init(_ other: Media.Subtype) {
        self = other.stringValue
    }
}

// MARK: -

extension BodyStructure {
    public var mediaType: Media.MediaType {
        switch self {
        case .singlepart(let singlepart):
            switch singlepart.kind {
            case .basic(let basic):
                return basic
            case .message:
                return .init(topLevel: .message, sub: "rfc822")
            case .text(let text):
                return .init(topLevel: .text, sub: text.mediaSubtype)
            }
        case .multipart(let multipart):
            return .init(topLevel: .multipart, sub: multipart.mediaSubtype)
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMediaType(_ media: Media.MediaType) -> Int {
        self.writeMediaTopLevelType(media.topLevel) +
            self.writeSpace() +
            self.writeMediaSubtype(media.sub)
    }

    @discardableResult mutating func writeMediaTopLevelType(_ type: Media.TopLevelType) -> Int {
        self.writeString("\"\(String(type).uppercased())\"")
    }

    @discardableResult mutating func writeMediaSubtype(_ type: Media.Subtype) -> Int {
        self.writeString("\"") +
            self.writeString(String(type).uppercased()) +
            self.writeString("\"")
    }
}
