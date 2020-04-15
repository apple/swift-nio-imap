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

    @discardableResult mutating func writeBodyFieldLanguage(_ language: NIOIMAP.Body.FieldLanguage) -> Int {
        switch language {
        case .single(let string):
            return self.writeNString(string)
        case .multiple(let strings):
            return self.writeArray(strings) { (element, self) in
                self.writeIMAPString(element)
            }
        }
    }

}
