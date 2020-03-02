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

    /// Extracted from IMAPv4 `body-ext-1part`
    struct FieldLocationExtension: Equatable {
        var location: FieldLocation
        var extensions: [NIOIMAP.BodyExtension]
    }

}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeBodyFieldLocationExtension(_ locationExtension: NIOIMAP.Body.FieldLocationExtension) -> Int {
        self.writeSpace() +
        self.writeNString(locationExtension.location) +
        locationExtension.extensions.reduce(0) { (result, ext) in
            result +
            self.writeSpace() +
            self.writeBodyExtension(ext)
        }
    }

}
