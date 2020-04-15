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

    public enum ResponsePayload: Equatable {
        case conditionalState(ResponseConditionalState)
        case conditionalBye(ResponseText)
        case mailboxData(Mailbox.Data)
        case messageData(MessageData)
        case capabilityData([Capability])
        case enableData([IMAPCore.Capability])
        case id([IDParameter])
    }

}

