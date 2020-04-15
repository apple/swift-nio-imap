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



extension IMAPCore {

    public enum OptionExtensionType: Equatable {
        case standard(String)
        case vendor(OptionVendorTag)
    }

    /// IMAPv4 `option-extension`
    public struct OptionExtension: Equatable {
        public var type: OptionExtensionType
        public var value: OptionValueComp?

        public static func standard(_ atom: String, value: OptionValueComp?) -> Self {
            return Self(type: .standard(atom), value: value)
        }

        public static func vendor(_ tag: OptionVendorTag, value: OptionValueComp?) -> Self {
            return Self(type: .vendor(tag), value: value)
        }
    }

}
