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

import NIO

extension NIOIMAP.Body {

    /// IMAPv4 `body-type-text`
    public struct TypeText: Equatable {
        public var mediaText: NIOIMAP.Media.Text
        public var fields: Fields
        public var lines: FieldLines
        
        public static func mediaText(_ mediaText: NIOIMAP.Media.Text, fields: Fields, lines: FieldLines) -> Self {
            return Self(mediaText: mediaText, fields: fields, lines: lines)
        }
    }

}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeBodyTypeText(_ body: NIOIMAP.Body.TypeText) -> Int {
        self.writeMediaText(body.mediaText) +
        self.writeSpace() +
        self.writeBodyFields(body.fields) +
        self.writeString(" \(body.lines)")
    }

}
