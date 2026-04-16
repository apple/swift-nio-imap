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

/// Namespace grouping MIME media type related types.
///
/// This namespace organizes MIME media type components as defined in [RFC 2045](https://datatracker.ietf.org/doc/html/rfc2045).
public enum Media {}

extension Media {
    /// A MIME media type consisting of a top-level type and subtype.
    ///
    /// MIME media types (also called MIME types or content types) identify the format of message part content.
    /// Each media type is composed of a top-level type (e.g., `text`, `image`, `application`) and a subtype
    /// (e.g., `plain`, `html`, `jpeg`), separated by a slash in standard notation (e.g., `text/plain`).
    ///
    /// Media types are defined in [RFC 2045 Section 5](https://datatracker.ietf.org/doc/html/rfc2045#section-5) and
    /// are included in message body structures retrieved via the `BODYSTRUCTURE` FETCH attribute.
    ///
    /// ### Example
    ///
    /// ```
    /// C: A001 FETCH 1 (BODYSTRUCTURE)
    /// S: * 1 FETCH (BODYSTRUCTURE ("text" "html" ("charset" "utf-8") NIL NIL "7bit" 2048 50))
    /// S: A001 OK FETCH completed
    /// ```
    ///
    /// The top-level type `"text"` and subtype `"html"` form a ``MediaType`` representing `text/html`.
    ///
    /// - SeeAlso: [RFC 2045 Section 5](https://datatracker.ietf.org/doc/html/rfc2045#section-5)
    /// - SeeAlso: ``TopLevelType``
    /// - SeeAlso: ``Subtype``
    public struct MediaType: Hashable, Sendable {
        /// The top-level type component (e.g., `text`, `image`, `application`).
        public var topLevel: TopLevelType

        /// The subtype component (e.g., `plain`, `html`, `jpeg`).
        public var sub: Subtype

        /// Creates a media type from top-level type and subtype components.
        ///
        /// - parameter topLevel: The top-level type component.
        /// - parameter sub: The subtype component.
        public init(topLevel: TopLevelType, sub: Subtype) {
            self.topLevel = topLevel
            self.sub = sub
        }
    }
}

extension Media.MediaType {
    /// Creates a media type from string components.
    ///
    /// This is a convenience initializer that creates ``TopLevelType`` and ``Subtype`` instances
    /// from the provided strings, which are automatically lowercased.
    ///
    /// - parameter topLevel: The top-level type as a string (e.g., `"text"`, `"image"`).
    /// - parameter sub: The subtype as a string (e.g., `"plain"`, `"html"`).
    public init(topLevel: String, sub: String) {
        self.topLevel = Media.TopLevelType(topLevel)
        self.sub = Media.Subtype(sub)
    }
}

// MARK: - Top-Level Type

extension Media {
    /// The top-level type component of a MIME media type.
    ///
    /// The top-level type is the first component of a media type (e.g., `text` in `text/plain`).
    /// Standard top-level types are registered with IANA and are case-insensitive, normalized to lowercase.
    ///
    /// Defined in [RFC 2045 Section 5](https://datatracker.ietf.org/doc/html/rfc2045#section-5) with types
    /// registered at [IANA MIME Types](https://www.iana.org/assignments/media-types/media-types.xhtml).
    ///
    /// - SeeAlso: [RFC 2045 Section 5](https://datatracker.ietf.org/doc/html/rfc2045#section-5)
    public struct TopLevelType: CustomDebugStringConvertible, Hashable, Sendable {
        /// The `multipart` top-level type, used for messages containing multiple parts.
        ///
        /// Examples: multipart/mixed, multipart/alternative, multipart/related.
        public static let multipart = Self("multipart")

        /// The `text` top-level type, used for text-based content.
        ///
        /// Examples: text/plain, text/html, text/csv.
        public static let text = Self("text")

        /// The `application` top-level type, used for application-specific content.
        ///
        /// Examples: application/json, application/pdf, application/octet-stream.
        public static let application = Self("application")

        /// The `audio` top-level type, used for audio content.
        ///
        /// Examples: audio/mpeg, audio/wav.
        public static let audio = Self("audio")

        /// The `image` top-level type, used for image content.
        ///
        /// Examples: image/jpeg, image/png, image/gif.
        public static let image = Self("image")

        /// The `message` top-level type, used for encapsulated message content.
        ///
        /// Examples: message/rfc822 (encapsulated email messages), message/delivery-status.
        public static let message = Self("message")

        /// The `video` top-level type, used for video content.
        ///
        /// Examples: video/mpeg, video/quicktime.
        public static let video = Self("video")

        /// The `font` top-level type, used for font data.
        ///
        /// Examples: font/ttf, font/woff.
        public static let font = Self("font")

        /// The top-level type as a lowercase string.
        internal let stringValue: String

        /// The top-level type as a lowercase string.
        ///
        /// - Returns: The type name in lowercase (e.g., `"text"`, `"image"`, `"multipart"`).
        public var debugDescription: String {
            self.stringValue
        }

        /// Creates a top-level type from a string.
        ///
        /// The provided string is automatically lowercased to normalize the type value. This allows
        /// case-insensitive comparison between type values.
        ///
        /// - parameter stringValue: The type name as a string (e.g., `"TEXT"`, `"Image"`, `"text"`). Will be lowercased.
        public init(_ stringValue: String) {
            self.stringValue = stringValue.lowercased()
        }
    }
}

extension Media.TopLevelType: ExpressibleByStringLiteral {
    /// Creates a top-level type from a string literal.
    ///
    /// This allows direct initialization like `let topLevel: Media.TopLevelType = "text"`.
    /// The string literal is automatically lowercased.
    ///
    /// - parameter stringLiteral: The type name as a string literal (e.g., `"text"`, `"image"`).
    public init(stringLiteral: String) {
        self.init(stringLiteral)
    }
}

extension String {
    /// Creates a `String` from a ``Media/TopLevelType``.
    ///
    /// - parameter other: The top-level type to convert.
    public init(_ other: Media.TopLevelType) {
        self = other.stringValue
    }
}

// MARK: - Sub-Type

extension Media {
    /// The subtype component of a MIME media type.
    ///
    /// The subtype is the second component of a media type (e.g., `plain` in `text/plain`).
    /// Subtypes are case-insensitive, normalized to lowercase, and are specific to their top-level type.
    ///
    /// Defined in [RFC 2045](https://datatracker.ietf.org/doc/html/rfc2045) with subtypes registered at
    /// [IANA MIME Types](https://www.iana.org/assignments/media-types/media-types.xhtml).
    ///
    /// - SeeAlso: [RFC 2045](https://datatracker.ietf.org/doc/html/rfc2045)
    public struct Subtype: CustomDebugStringConvertible, Hashable, Sendable {
        /// The `multipart/alternative` subtype, specifying the same data in different formats.
        ///
        /// Clients should display the most appropriate alternative according to user preferences.
        public static let alternative = Self("alternative")

        /// The `multipart/related` subtype, specifying related body parts (e.g., HTML with embedded images).
        ///
        /// Parts in a multipart/related message are typically related to one another (e.g., an HTML
        /// document with embedded images or stylesheets).
        public static let related = Self("related")

        /// The `multipart/mixed` subtype, specifying a generic set of mixed data types.
        ///
        /// This is the default multipart subtype for messages with multiple unrelated parts.
        public static let mixed = Self("mixed")

        /// The `message/rfc822` subtype for encapsulated email messages.
        ///
        /// This subtype indicates the message part contains a complete RFC 822 (email) message,
        /// which may have its own headers, body structure, and attachments.
        public static let rfc822 = Self("rfc822")

        /// The subtype as a lowercase string.
        internal let stringValue: String

        /// The subtype as a lowercase string.
        ///
        /// - Returns: The subtype name in lowercase (e.g., `"plain"`, `"html"`, `"mixed"`).
        public var debugDescription: String { self.stringValue }

        /// Creates a subtype from a string.
        ///
        /// The provided string is automatically lowercased to normalize the subtype value. This allows
        /// case-insensitive comparison between subtype values.
        ///
        /// - parameter stringValue: The subtype name as a string (e.g., `"PLAIN"`, `"Html"`, `"plain"`). Will be lowercased.
        public init(_ stringValue: String) {
            self.stringValue = stringValue.lowercased()
        }
    }
}

extension Media.Subtype: ExpressibleByStringLiteral {
    /// Creates a subtype from a string literal.
    ///
    /// This allows direct initialization like `let subtype: Media.Subtype = "plain"`.
    /// The string literal is automatically lowercased.
    ///
    /// - parameter stringLiteral: The subtype name as a string literal (e.g., `"plain"`, `"html"`).
    public init(stringLiteral: String) {
        self.init(stringLiteral)
    }
}

extension String {
    /// Creates a `String` from a ``Media/Subtype``.
    ///
    /// - parameter other: The subtype to convert.
    public init(_ other: Media.Subtype) {
        self = other.stringValue
    }
}

// MARK: -

extension BodyStructure {
    /// The MIME media type of this body structure.
    ///
    /// Computes the media type by examining the body structure cases. For single-part bodies, returns the media type
    /// of the single part. For multipart bodies, returns the media type with top-level type `multipart` and the
    /// appropriate subtype.
    ///
    /// - Returns: The computed ``Media/MediaType`` for this body structure.
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
        self.writeMediaTopLevelType(media.topLevel) + self.writeSpace() + self.writeMediaSubtype(media.sub)
    }

    @discardableResult mutating func writeMediaTopLevelType(_ type: Media.TopLevelType) -> Int {
        self.writeString("\"\(String(type).uppercased())\"")
    }

    @discardableResult mutating func writeMediaSubtype(_ type: Media.Subtype) -> Int {
        self.writeString("\"") + self.writeString(String(type).uppercased()) + self.writeString("\"")
    }
}
