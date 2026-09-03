//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// A bundle of object identifiers, as introduced by the `OBJECTID+` extension.
///
/// ``CompoundObjectID`` bundles the identifiers relevant to a given context (a mailbox, or a
/// message) into a single value. Every field is optional: a server omits identifiers it does
/// not support or that are not applicable, rather than returning a placeholder. A
/// ``CompoundObjectID`` with every field `nil` is valid, and is encoded as `OBJECTID ()`.
///
/// Mailbox contexts (`SELECT`, `EXAMINE`, `CREATE`, `RENAME`, `STATUS`) typically populate
/// ``mailboxID`` and ``accountID``. Message contexts (`FETCH`) typically populate ``emailID``
/// and ``threadID``.
///
/// **Requires server capability:** ``Capability/objectIDPlus``
///
/// - SeeAlso: `draft-ietf-mailmaint-imap-objectid-bis`
public struct CompoundObjectID: Hashable, Sendable {
    /// The identifier for the mailbox, if present and applicable to this context.
    public var mailboxID: MailboxID?

    /// The identifier for the account that owns the mailbox, if present and applicable to this context.
    public var accountID: AccountID?

    /// The identifier for the message content, if present and applicable to this context.
    public var emailID: EmailID?

    /// The identifier for the message's thread, if present and applicable to this context.
    public var threadID: ThreadID?

    /// Creates a new compound of object identifiers.
    ///
    /// - Parameter mailboxID: The mailbox's identifier, if any
    /// - Parameter accountID: The owning account's identifier, if any
    /// - Parameter emailID: The message's identifier, if any
    /// - Parameter threadID: The message's thread identifier, if any
    public init(
        mailboxID: MailboxID? = nil,
        accountID: AccountID? = nil,
        emailID: EmailID? = nil,
        threadID: ThreadID? = nil
    ) {
        self.mailboxID = mailboxID
        self.accountID = accountID
        self.emailID = emailID
        self.threadID = threadID
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeCompoundObjectID(_ compound: CompoundObjectID) -> Int {
        var pairs: [(String, String)] = []
        if let mailboxID = compound.mailboxID {
            pairs.append(("MAILBOXID", String(mailboxID)))
        }
        if let accountID = compound.accountID {
            pairs.append(("ACCOUNTID", String(accountID)))
        }
        if let emailID = compound.emailID {
            pairs.append(("EMAILID", String(emailID)))
        }
        if let threadID = compound.threadID {
            pairs.append(("THREADID", String(threadID)))
        }
        return self.writeArray(pairs, parenthesis: true) { (pair, buffer) in
            buffer.writeString("\(pair.0) \(pair.1)")
        }
    }
}
