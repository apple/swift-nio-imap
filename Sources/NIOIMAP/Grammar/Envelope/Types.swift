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

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeEnvelopeAddresses(_ addresses: [NIOIMAP.Address]?) -> Int {
        guard let addresses = addresses else {
            return self.writeNil()
        }

        return
            self.writeString("(") +
            self.writeArray(addresses, separator: "", parenthesis: false) { (address, self) -> Int in
                self.writeAddress(address)
            } +
            self.writeString(")")
    }

}
