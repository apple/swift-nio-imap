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



extension IMAPCore.Media {

    public enum BasicType: Equatable {
        case application
        case audio
        case image
        case message
        case video
        case font
        case other(String)
    }

    /// IMAPv4 `media-basic`
    public struct Basic: Equatable {
        public var type: BasicType
        public var subtype: String

        /// Convenience function for a better experience when chaining multiple types.
        public static func type(_ type: BasicType, subtype: String) -> Self {
            return Self(type: type, subtype: subtype)
        }
    }

}
