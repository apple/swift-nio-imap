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

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif swift(<6.0)
@preconcurrency import Foundation
#else
import Foundation
#endif

import struct NIO.ByteBuffer
import struct OrderedCollections.OrderedDictionary

/// Data returned as part of an untagged response from the server.
///
/// Untagged responses contain server-initiated information about mailbox state, message status,
/// capabilities, and other protocol data. These responses are not tied to a specific command
/// and may be returned at any time. See [RFC 3501 Section 7.1](https://datatracker.ietf.org/doc/html/rfc3501#section-7.1)
/// for details on untagged response types.
///
/// ### Examples
///
/// ```
/// S: * FLAGS (\Seen \Answered \Flagged \Deleted \Draft)
/// S: * 15 EXISTS
/// S: * CAPABILITY IMAP4rev1 STARTTLS LOGINDISABLED
/// S: * ID ("name" "server" "version" "1.0")
/// ```
///
/// The first line corresponds to ``mailboxData(_:)`` containing ``MailboxData/flags(_:)``.
/// The second line corresponds to ``mailboxData(_:)`` containing ``MailboxData/exists(_:)``.
/// The third line corresponds to ``capabilityData(_:)``, while the fourth corresponds
/// to ``id(_:)``.
///
/// ## Related Types
///
/// See ``Response`` for the main response wrapper, ``UntaggedStatus`` for conditional status responses,
/// and ``ResponsePayload`` cases for detailed information types.
///
/// - SeeAlso: [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501)
public enum ResponsePayload: Hashable, Sendable {
    /// Indicates if a command executed successfully or encountered an error.
    ///
    /// This case wraps an ``UntaggedStatus`` which can be `OK` (success), `NO` (warning/rejection),
    /// `BAD` (protocol error), `PREAUTH` (pre-authenticated), or `BYE` (server closing connection).
    /// See [RFC 3501 Section 7.1](https://datatracker.ietf.org/doc/html/rfc3501#section-7.1) for
    /// details on status responses.
    case conditionalState(UntaggedStatus)

    /// Contains information on a single mailbox.
    ///
    /// This case wraps mailbox-specific data such as flags, existence counts, recent count,
    /// and search results. See ``MailboxData`` for the various mailbox information types.
    case mailboxData(MailboxData)

    /// Contains information on a single message.
    ///
    /// This case wraps message-specific data returned during FETCH operations or other
    /// message queries. See ``MessageData`` for the various message attribute types.
    case messageData(MessageData)

    /// An array of capabilities supported by the server.
    ///
    /// This case is returned in response to `CAPABILITY` commands or as part of the initial
    /// server greeting. It indicates which IMAP extensions and features the server supports.
    /// See [RFC 3501 Section 7.1](https://datatracker.ietf.org/doc/html/rfc3501#section-7.1) and ``Capability``.
    case capabilityData([Capability])

    /// An array of capabilities that have been enabled on the server by the client.
    ///
    /// This case is returned in response to an `ENABLE` command and lists the capabilities
    /// that were successfully enabled. See [RFC 5161](https://datatracker.ietf.org/doc/html/rfc5161)
    /// (ENABLE Extension) for details.
    case enableData([Capability])

    /// The server's implementation details used for identification.
    ///
    /// This case contains an ordered dictionary of key-value pairs providing server identification
    /// information. Common keys include "name", "version", and "os". Returned in response to
    /// the ID command. See [RFC 2971](https://datatracker.ietf.org/doc/html/rfc2971) (ID Extension)
    /// for details.
    case id(OrderedDictionary<String, String?>)

    /// Matches a quota root with a mailbox.
    ///
    /// This case associates a mailbox with its quota root. Multiple mailboxes may share the same
    /// quota root. See [RFC 2087](https://datatracker.ietf.org/doc/html/rfc2087) (QUOTA Extension)
    /// for details and ``QuotaRoot``.
    case quotaRoot(MailboxName, QuotaRoot)

    /// Contains quotas and resource limits for the specified quota root.
    ///
    /// This case provides the usage and limit information for a quota root. See [RFC 2087](https://datatracker.ietf.org/doc/html/rfc2087)
    /// for details on quota resources and ``QuotaResource``.
    case quota(QuotaRoot, [QuotaResource])

    /// Metadata for a mailbox.
    ///
    /// This case provides metadata entries for a mailbox, as requested by a `GETMETADATA` command.
    /// See [RFC 5464](https://datatracker.ietf.org/doc/html/rfc5464) (METADATA Extension) for details.
    case metadata(MetadataResponse)

    /// JMAP Access URL for the mailbox.
    ///
    /// This case provides a URL that allows clients to access mailbox data via JMAP (JSON Mail
    /// Access Protocol). See [RFC 9698](https://datatracker.ietf.org/doc/html/rfc9698) (JMAPACCESS Extension)
    /// for details.
    case jmapAccess(URL)
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
        case .jmapAccess(let url):
            return self.writeString("JMAPACCESS \"\(url)\"")
        }
    }
}
