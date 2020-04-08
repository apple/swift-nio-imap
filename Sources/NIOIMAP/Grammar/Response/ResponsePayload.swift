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

extension NIOIMAP {

    public enum ResponsePayload: Equatable {
        case conditionalState(ResponseConditionalState)
        case conditionalBye(ResponseText)
        case mailboxData(Mailbox.Data)
        case messageData(MessageData)
        case capabilityData([Capability])
        case enableData([NIOIMAP.Capability])
        case id([IDParamsListElement]?)
    }

}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeResponsePayload(_ payload: NIOIMAP.ResponsePayload) -> Int {
        switch payload {
        case .conditionalState(let data):
            return self.writeResponseConditionalState(data)
        case .conditionalBye(let data):
            return self.writeResponseConditionalBye(data)
        case .mailboxData(let data):
            return self.writeMailboxData(data)
        case .messageData(let data):
            return self.writeMessageData(data)
        case .capabilityData(let data):
            return self.writeCapabilityData(data)
        case .enableData(let data):
            return self.writeEnableData(data)
        case .id(let data):
            return self.writeIDResponse(data)
        }
    }

}
