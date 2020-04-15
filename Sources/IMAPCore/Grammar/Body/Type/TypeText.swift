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

    /// IMAPv4 `body-type-text`
    public struct TypeText: Equatable {
        public var mediaText: String
        public var fields: Fields
        public var lines: Int
        
        public static func mediaText(_ mediaText: String, fields: Fields, lines: Int) -> Self {
            return Self(mediaText: mediaText, fields: fields, lines: lines)
        }
    }

}
