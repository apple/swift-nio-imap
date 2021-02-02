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

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeBodyParameterPairs(_ params: KeyValues<String, String>) -> Int {
        guard params.count > 0 else {
            return self.writeNil()
        }
        return self.writeKeyValues(params) { (element, self) in
            self.writeIMAPString(element.0) +
                self.writeSpace() +
            self.writeIMAPString(element.1)
        }
    }

}
