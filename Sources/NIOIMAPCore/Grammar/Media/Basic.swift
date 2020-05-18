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
    public struct BasicType: Equatable {
        var _backing: String

        /// IMAP4rev1 APPLICATION
        public static var application: Self { .init(_backing: "APPLICATION") }

        /// IMAP4rev1 AUDIO
        public static var audio: Self { .init(_backing: "AUDIO") }

        /// IMAP4rev1 IMAGE
        public static var image: Self { .init(_backing: "IMAGE") }

        /// IMAP4rev1 MESSAGE
        public static var message: Self { .init(_backing: "MESSAGE") }

        /// IMAP4rev1 VIDEO
        public static var video: Self { .init(_backing: "VIDEO") }

        /// IMAP4rev1 FONT
        public static var font: Self { .init(_backing: "FONT") }

        /// Creates a new type with the given `String`.
        /// - parameter string: The type to create. Note that the `String` will be uppercased.
        /// - returns: A new type from the given `String`.
        public static func other(_ string: String) -> Self {
            self.init(_backing: string.uppercased())
        }
    }

    /// IMAPv4 `media-basic`
    public struct Basic: Equatable {
        public var type: BasicType
        public var subtype: String

        public init(type: Media.BasicType, subtype: String) {
            self.type = type
            self.subtype = subtype
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMediaBasicType(_ type: Media.BasicType) -> Int {
        switch type {
        case .application, .audio, .image, .message, .video:
            return self.writeString("\"\(type._backing)\"")
        default:
            return self.writeString(type._backing)
        }
    }

    @discardableResult mutating func writeMediaBasic(_ media: Media.Basic) -> Int {
        self.writeMediaBasicType(media.type) +
            self.writeSpace() +
            self.writeIMAPString(media.subtype)
    }
}
