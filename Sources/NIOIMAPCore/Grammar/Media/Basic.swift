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

extension Media {
    /// Represents a simple but common data type such as *APPLICATION* or *INAGE*
    public struct BasicKind: CustomDebugStringConvertible, Equatable {
        /// IMAP4rev1 APPLICATION
        public static let application = Self("APPLICATION")

        /// IMAP4rev1 AUDIO
        public static let audio = Self("AUDIO")

        /// IMAP4rev1 IMAGE
        public static let image = Self("IMAGE")

        /// IMAP4rev1 MESSAGE
        public static let message = Self("MESSAGE")

        /// IMAP4rev1 VIDEO
        public static let video = Self("VIDEO")

        /// IMAP4rev1 FONT
        public static let font = Self("FONT")

        /// The raw uppercased string representation of the type.
        public let stringValue: String

        /// See `rawValue`
        public var debugDescription: String {
            stringValue
        }

        /// Creates a new `BasicKind` from a given `String`.
        /// - parameter rawValue: A string that represents the type, note that this will be uppercased.
        public init(_ stringValue: String) {
            self.stringValue = stringValue.uppercased()
        }
    }

    /// A basic media type to form a full data type. It contains a high-level type, e.g. "VIDEO", and a lower-level
    /// subtype, e.g. "MP4", to construct to construct "VIDEO/MP4".
    public struct Basic: Equatable {
        /// The top-level media kind.
        public var kind: BasicKind

        /// The specific media subtype.
        public var subtype: BodyStructure.MediaSubtype

        /// Creates a new `Basic`.
        /// - parameter kind: The top-level media kind.
        /// - parameter subtype: The specific media subtype.
        public init(kind: Media.BasicKind, subtype: BodyStructure.MediaSubtype) {
            self.kind = kind
            self.subtype = subtype
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMediaBasicKind(_ type: Media.BasicKind) -> Int {
        switch type {
        case .application, .audio, .image, .message, .video:
            return self.writeString("\"\(type.stringValue)\"")
        default:
            return self.writeString(type.stringValue)
        }
    }

    @discardableResult mutating func writeMediaBasic(_ media: Media.Basic) -> Int {
        self.writeMediaBasicKind(media.kind) +
            self.writeSpace() +
            self.writeMediaSubtype(media.subtype)
    }
}
