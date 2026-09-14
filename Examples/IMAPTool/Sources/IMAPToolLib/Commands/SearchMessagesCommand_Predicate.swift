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

import ArgumentParser
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIOIMAP

extension SearchMessagesCommand {
    /// Command-line arguments that specify the search predicate.
    struct Predicate: ParsableArguments, Sendable {
        init() {}

        init(
            olderThanDays: Int? = nil,
            newerThanDays: Int? = nil,
            subject: String? = nil,
            fromAddress: String? = nil,
            toAddress: String? = nil,
            ccAddress: String? = nil,
            text: String? = nil,
            messageSizeSmallerThan: Int? = nil,
            messageSizeLargerThan: Int? = nil,
            messageID: String? = nil,
            emailID: String? = nil,
            threadID: String? = nil,
            flags: [MessageFlag] = []
        ) {
            self.olderThanDays = olderThanDays
            self.newerThanDays = newerThanDays
            self.subject = subject
            self.fromAddress = fromAddress
            self.toAddress = toAddress
            self.ccAddress = ccAddress
            self.text = text
            self.messageSizeSmallerThan = messageSizeSmallerThan
            self.messageSizeLargerThan = messageSizeLargerThan
            self.messageID = messageID
            self.emailID = emailID
            self.threadID = threadID
            self.flags = flags
        }

        @Option(
            name: .customLong("older-than-days"),
            help: "Match messages older than N days"
        )
        var olderThanDays: Int?

        @Option(
            name: .customLong("newer-than-days"),
            help: "Match messages newer than N days"
        )
        var newerThanDays: Int?

        @Option(
            name: .customLong("subject"),
            help: "Match messages with this subject"
        )
        var subject: String?

        @Option(
            name: .customLong("from"),
            help: "Match messages from this sender"
        )
        var fromAddress: String?

        @Option(
            name: .customLong("to"),
            help: "Match messages to this recipient"
        )
        var toAddress: String?

        @Option(
            name: .customLong("cc"),
            help: "Match messages with this CC recipient"
        )
        var ccAddress: String?

        @Option(
            name: .customLong("text"),
            help: "Match messages containing this text"
        )
        var text: String?

        @Option(
            name: .customLong("message-size-smaller-than"),
            help: "Match messages smaller than N bytes"
        )
        var messageSizeSmallerThan: Int?

        @Option(
            name: .customLong("message-size-larger-than"),
            help: "Match messages larger than N bytes"
        )
        var messageSizeLargerThan: Int?

        @Option(
            name: .customLong("message-id"),
            help: "Match message by IMAP Message-ID"
        )
        var messageID: String?

        @Option(
            name: .customLong("email-id"),
            help: "Match message by RFC 8474 Email ID"
        )
        var emailID: String?

        @Option(
            name: .customLong("thread-id"),
            help: "Match messages by RFC 8474 Thread ID"
        )
        var threadID: String?

        @Option(
            name: .customLong("flag"),
            help: .init(
                "Match messages with this flag.",
                discussion: #"""
                    Match messages with this flag set.

                    This can be repeated multiple times.

                    Valid values: \#(MessageFlag.allCases.map { $0.rawValue }.joined(separator: ", "))
                    """#
            )
        )
        var flags: [MessageFlag] = []
    }
}

extension SearchKey {
    /// Create a ``SearchKey`` from command line arguments.
    init(
        _ other: SearchMessagesCommand.Predicate
    ) throws {
        try self.init(SearchKey.Predicate(other))
    }
}

extension SearchKey.Predicate {
    /// Convert to a `SearchKey.Predicate`.
    init(
        _ other: SearchMessagesCommand.Predicate
    ) throws {
        // Combine all flags
        var flagsSet: Set<NIOIMAP.Flag> = []
        var flagsNotSet: Set<NIOIMAP.Flag> = []
        for flag in other.flags {
            let toSearch = flag.flagsToSearch
            flagsSet.formUnion(toSearch.set)
            flagsNotSet.formUnion(toSearch.notSet)
        }
        guard
            flagsSet.isDisjoint(with: flagsNotSet)
        else {
            let a = flagsSet.intersection(flagsNotSet)
            let invalid = other
                .flags
                .filter { flag in
                    !flag.flagsToSearch.set.isDisjoint(with: a) || !flag.flagsToSearch.notSet.isDisjoint(with: a)
                }
            guard
                !invalid.isEmpty
            else { throw ValidationError("Invalid flag combination") }
            throw ValidationError("Invalid combination of flags {\(invalid.map { "\($0)" }.joined(separator: ", "))}")
        }

        // Parse string IDs to typed IDs
        let emailID: EmailID?
        if let emailIDString = other.emailID {
            guard let parsed = EmailID(emailIDString) else {
                throw ValidationError("Invalid email-id: \(emailIDString)")
            }
            emailID = parsed
        } else {
            emailID = nil
        }

        let threadID: ThreadID?
        if let threadIDString = other.threadID {
            guard let parsed = ThreadID(threadIDString) else {
                throw ValidationError("Invalid thread-id: \(threadIDString)")
            }
            threadID = parsed
        } else {
            threadID = nil
        }

        if let o = other.olderThanDays, let n = other.newerThanDays {
            guard
                o < n
            else { throw ValidationError("Messages can not be older than \(o) and newer than \(n) at the same time.") }
        }

        self.init(
            olderThanDays: other.olderThanDays,
            newerThanDays: other.newerThanDays,
            subject: other.subject,
            from: other.fromAddress,
            to: other.toAddress,
            cc: other.ccAddress,
            text: other.text,
            messageSizeSmallerThan: other.messageSizeSmallerThan,
            messageSizeLargerThan: other.messageSizeLargerThan,
            messageID: other.messageID.map { MessageID($0) },
            emailID: emailID,
            threadID: threadID,
            flagsSet: flagsSet,
            flagsNotSet: flagsNotSet
        )
    }
}
