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
    public struct BasicKind: RawRepresentable, CustomStringConvertible, Equatable {
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue.uppercased()
        }

        /// IMAP4rev1 APPLICATION
        public static var application: Self { .init(rawValue: "APPLICATION") }

        /// IMAP4rev1 AUDIO
        public static var audio: Self { .init(rawValue: "AUDIO") }

        /// IMAP4rev1 IMAGE
        public static var image: Self { .init(rawValue: "IMAGE") }

        /// IMAP4rev1 MESSAGE
        public static var message: Self { .init(rawValue: "MESSAGE") }

        /// IMAP4rev1 VIDEO
        public static var video: Self { .init(rawValue: "VIDEO") }

        /// IMAP4rev1 FONT
        public static var font: Self { .init(rawValue: "FONT") }

        /// Creates a new type with the given `String`.
        /// - parameter string: The type to create. Note that the `String` will be uppercased.
        /// - returns: A new type from the given `String`.
        public static func other(_ string: String) -> Self {
            self.init(rawValue: string)
        }

        public var description: String {
            rawValue
        }
    }

    /// IMAPv4 `media-basic`
    public struct Basic: Equatable {
        public var kind: BasicKind
        public var subtype: BodyStructure.MediaSubtype

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
            return self.writeString("\"\(type.rawValue)\"")
        default:
            return self.writeString(type.rawValue)
        }
    }

    @discardableResult mutating func writeMediaBasic(_ media: Media.Basic) -> Int {
        self.writeMediaBasicKind(media.kind) +
            self.writeSpace() +
            self.writeMediaSubtype(media.subtype)
    }
}
