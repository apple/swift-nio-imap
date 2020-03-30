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

    /// IMAPv4 `body-fld-param`
    public typealias FieldParameter = [ByteBuffer]?

}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeBodyFieldParameter(_ params: NIOIMAP.Body.FieldParameter) -> Int {
        guard let params = params else {
            return self.writeNil()
        }
        return self.writeArray(params) { (element, buffer) in
            buffer.writeIMAPString(element)
        }
    }

}
