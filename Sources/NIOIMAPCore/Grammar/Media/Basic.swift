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
    public enum BasicType: Equatable {
        case application
        case audio
        case image
        case message
        case video
        case font
        case other(ByteBuffer)
    }

    /// IMAPv4 `media-basic`
    public struct Basic: Equatable {
        public var type: BasicType
        public var subtype: String

        /// Convenience function for a better experience when chaining multiple types.
        public static func type(_ type: BasicType, subtype: String) -> Self {
            Self(type: type, subtype: subtype)
        }
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeMediaBasicType(_ type: Media.BasicType) -> Int {
        switch type {
        case .application:
            return self.writeString(#""APPLICATION""#)
        case .audio:
            return self.writeString(#""AUDIO""#)
        case .image:
            return self.writeString(#""IMAGE""#)
        case .message:
            return self.writeString(#""MESSAGE""#)
        case .video:
            return self.writeString(#""VIDEO""#)
        case .font:
            return self.writeString(#""FONT""#)
        case .other(let buffer):
            return self.writeIMAPString(buffer)
        }
    }

    @discardableResult mutating func writeMediaBasic(_ media: Media.Basic) -> Int {
        self.writeMediaBasicType(media.type) +
            self.writeSpace() +
            self.writeIMAPString(media.subtype)
    }
}
