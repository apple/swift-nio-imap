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

extension IMAPCore.Body {

    /// IMAPv4 `body-type-basic`
    public struct TypeBasic: Equatable {
        public var media: IMAPCore.Media.Basic
        public var fields: Fields
        
        public static func media(_ media: IMAPCore.Media.Basic, fields: Fields) -> Self {
            return Self(media: media, fields: fields)
        }
    }

}

// MARK: - Encoding
extension ByteBufferProtocol {

    @discardableResult mutating func writeBodyTypeBasic(_ body: IMAPCore.Body.TypeBasic) -> Int {
        self.writeMediaBasic(body.media) +
        self.writeSpace() +
        self.writeBodyFields(body.fields)
    }

}
