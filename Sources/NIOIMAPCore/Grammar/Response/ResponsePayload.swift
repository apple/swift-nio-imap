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

import struct NIO.ByteBuffer
import struct OrderedCollections.OrderedDictionary

/// Data returned as part of an untagged response. Typically one of these cases will be returned
/// for each message or mailbox that is of interest.
public enum ResponsePayload: Hashable, Sendable {
    /// Indicates if the command, or subcommand, executed successfully.
    case conditionalState(UntaggedStatus)

    /// Contains information on a single mailbox, for example its flags.
    case mailboxData(MailboxData)

    /// Contains information on a message.
    case messageData(MessageData)

    /// An array of capabilities support by the server.
    case capabilityData([Capability])

    /// An array of capabilities that have been enabled on the server by the client.
    case enableData([Capability])

    /// The servers implementation details, used for identification. For example
    /// this may be used to identify an iCloud server.
    case id(OrderedDictionary<String, String?>)

    /// Matches a quota root with a mailbox.
    case quotaRoot(MailboxName, QuotaRoot)

    /// Contains quotas/limits for the specified `QuotaRoot`.
    case quota(QuotaRoot, [QuotaResource])

    /// Metadata for the specified mailbox.
    case metadata(MetadataResponse)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeResponsePayload(_ payload: ResponsePayload) -> Int {
        switch payload {
        case .conditionalState(let data):
            return self.writeUntaggedStatus(data)
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
        case .quotaRoot(let mailbox, let quotaRoot):
            return self.writeQuotaRootResponse(mailbox: mailbox, quotaRoot: quotaRoot)
        case .quota(let quotaRoot, let resources):
            return self.writeQuotaResponse(quotaRoot: quotaRoot, resources: resources)
        case .metadata(let response):
            return self.writeMetadataResponse(response)
        }
    }
}
