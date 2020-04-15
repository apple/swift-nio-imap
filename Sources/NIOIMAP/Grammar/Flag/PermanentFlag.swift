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

    @discardableResult mutating func writeFlagPerm(_ flagPerm: NIOIMAP.PermanentFlag) -> Int {
        switch flagPerm {
        case .flag(let flag):
            return self.writeFlag(flag)
        case .wildcard:
            return self.writeString(#"\*"#)
        }
    }
    
    @discardableResult mutating func writePermanentFlags(_ flags: [NIOIMAP.PermanentFlag]) -> Int {
        return self.writeArray(flags) { (element, self) in
            self.writeFlagPerm(element)
        }
    }

}
