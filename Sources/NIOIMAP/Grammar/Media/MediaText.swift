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

extension NIOIMAP.Media {

    /// IMAPv4 `media-text`
    public typealias Text = Subtype

}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeMediaText(_ text: NIOIMAP.Media.Text) -> Int {
        self.writeString(#""TEXT" "#) +
        self.writeIMAPString(text)
    }

}
