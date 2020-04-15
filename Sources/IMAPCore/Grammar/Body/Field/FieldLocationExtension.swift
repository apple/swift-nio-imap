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

    /// Extracted from IMAPv4 `body-ext-1part`
    public struct FieldLocationExtension: Equatable {
        public var location: IMAPCore.NString
        public var extensions: [[IMAPCore.BodyExtensionType]]
        
        public static func location(_ location: IMAPCore.NString, extensions: [[IMAPCore.BodyExtensionType]]) -> Self {
            return Self(location: location, extensions: extensions)
        }
    }

}
