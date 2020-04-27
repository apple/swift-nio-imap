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

extension NIOIMAP.BodyStructure {
    /// IMAPv4 `body-type-basic`
    public struct TypeBasic: Equatable {
        public var media: NIOIMAP.Media.Basic
        public var fields: Fields

        public static func media(_ media: NIOIMAP.Media.Basic, fields: Fields) -> Self {
            Self(media: media, fields: fields)
        }
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeBodyTypeBasic(_ body: NIOIMAP.BodyStructure.TypeBasic) -> Int {
        self.writeMediaBasic(body.media) +
            self.writeSpace() +
            self.writeBodyFields(body.fields)
    }
}
