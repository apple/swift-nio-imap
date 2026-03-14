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

/// Identifies a search operation in responses when multiple searches are pipelined (RFC 7377 MULTIMAILBOX SEARCH extension).
///
/// When performing multiple concurrent searches across different mailboxes, clients need a way to correlate
/// each ESEARCH response with its corresponding request. This type provides identification information that
/// allows clients to safely pipeline search commands without confusion, as each response includes the correlator
/// information from the original request.
///
/// **Requires server capability:** ``Capability/multimailboxSearch``
///
/// The server echoes back the correlator information in the ESEARCH response, allowing clients to:
/// - Match responses to requests when pipelining
/// - Search multiple mailboxes with a single command
/// - Avoid disrupting the currently selected mailbox
///
/// ### Example
///
/// ```
/// C: A001 SEARCH IN (MAILBOX "INBOX") TEXT "hello" RETURN (COUNT) TAG "A001" MAILBOX "INBOX" UIDVALIDITY 12345
/// S: * ESEARCH (TAG "A001" MAILBOX "INBOX" UIDVALIDITY 12345) COUNT 5
/// S: A001 OK SEARCH completed
/// ```
///
/// The `TAG "A001" MAILBOX "INBOX" UIDVALIDITY 12345` clause in the response corresponds to a ``SearchCorrelator``
/// with `tag: "A001"`, `mailbox: "INBOX"`, and `uidValidity: 12345`. These fields allow the client to identify
/// which mailbox's search results are being returned.
///
/// - SeeAlso: [RFC 7377 Section 2.3](https://datatracker.ietf.org/doc/html/rfc7377#section-2.3)
/// - SeeAlso: ``ExtendedSearchResponse``
public struct SearchCorrelator: Hashable, Sendable {
    /// The tag from the original `SEARCH` command, used to correlate responses with requests.
    ///
    /// Per RFC 4466, this is an arbitrary string chosen by the client to uniquely identify this search
    /// among potentially multiple concurrent searches.
    public var tag: String

    /// The mailbox name associated with this search, when using RFC 7377 multimailbox search.
    ///
    /// When present, the server is searching this specific mailbox. When `nil`, the search may apply
    /// to the currently selected mailbox or multiple mailboxes depending on the request structure.
    public var mailbox: MailboxName?

    /// The UIDVALIDITY of the mailbox at the time of the search, when using RFC 7377.
    ///
    /// UIDVALIDITY changes if the mailbox is reconstructed or emptied. Clients can use this to detect
    /// when a mailbox has been modified and results may be stale.
    public var uidValidity: UIDValidity?

    /// Creates a new `SearchCorrelator`.
    /// - parameter tag: The tag string from the `SEARCH` command (per RFC 4466)
    /// - parameter mailbox: The mailbox name being searched (RFC 7377, optional)
    /// - parameter uidValidity: The UIDVALIDITY of the mailbox (RFC 7377, optional)
    public init(tag: String, mailbox: MailboxName? = nil, uidValidity: UIDValidity? = nil) {
        self.tag = tag
        self.mailbox = mailbox
        self.uidValidity = uidValidity
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSearchCorrelator(_ correlator: SearchCorrelator) -> Int {
        self.writeString(" (TAG \"") + self.writeString(correlator.tag) + self.writeString("\"")
            + self.writeIfExists(correlator.mailbox) { mailbox in
                self.writeString(" MAILBOX ") + self.writeMailbox(mailbox)
            }
            + self.writeIfExists(correlator.uidValidity) { uidValidity in
                self.writeString(" UIDVALIDITY ") + self.writeUIDValidity(uidValidity)
            } + self.writeString(")")
    }
}
