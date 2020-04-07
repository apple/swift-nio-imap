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

extension NIOIMAP.Mailbox {

    /// IMAPv4 `mbox-list-extended-item`
    public struct ListExtendedItem: Equatable {
        public var tag: ByteBuffer
        public var extensionValue: NIOIMAP.TaggedExtensionValue
        
        public static func tag(_ tag: ByteBuffer, extensionValue: NIOIMAP.TaggedExtensionValue) -> Self {
            return Self(tag: tag, extensionValue: extensionValue)
        }
    }

}
