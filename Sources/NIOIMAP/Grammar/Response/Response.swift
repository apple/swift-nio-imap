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

    @discardableResult mutating func writeResponseType(_ type: NIOIMAP.ResponseType) -> Int {
        switch type {
        case .continueRequest(let continueRequest):
            return self.writeContinueRequest(continueRequest)
        case .responseData(let data):
            return self.writeResponseData(data)
        }
    }

}
