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

    /// IMAPv4 `flag-perm`
    public enum PermanentFlag: Equatable {
        case flag(Flag)
        case wildcard
    }

}

// MARK: - Encoding
extension ByteBufferProtocol {

    @discardableResult mutating func writeFlagPerm(_ flagPerm: IMAPCore.PermanentFlag) -> Int {
        switch flagPerm {
        case .flag(let flag):
            return self.writeFlag(flag)
        case .wildcard:
            return self.writeString(#"\*"#)
        }
    }
    
    @discardableResult mutating func writePermanentFlags(_ flags: [IMAPCore.PermanentFlag]) -> Int {
        return self.writeArray(flags) { (element, self) in
            self.writeFlagPerm(element)
        }
    }

}
