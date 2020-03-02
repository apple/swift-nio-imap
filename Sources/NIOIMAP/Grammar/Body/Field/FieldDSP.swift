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

    /// IMAPv4 `body-fld-dsp`
    struct FieldDSPData: Equatable {
        var string: NIOIMAP.IMAPString
        var parameter: FieldParameter
    }

    typealias FieldDSP = FieldDSPData?

}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeBodyFieldDSP(_ dsp: NIOIMAP.Body.FieldDSP) -> Int {
        guard let dsp = dsp else {
            return self.writeNil()
        }
        
        return
            self.writeString("(") +
            self.writeIMAPString(dsp.string) +
            self.writeSpace() +
            self.writeBodyFieldParameter(dsp.parameter) +
            self.writeString(")")
    }

}
