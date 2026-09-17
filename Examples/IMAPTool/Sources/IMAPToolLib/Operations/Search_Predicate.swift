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
import IMAPCommands
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIO
import NIOIMAP

extension SearchKey {
    /// A combination of search criteria for filtering messages.
    struct Predicate: Hashable, Sendable {
        var olderThanDays: Int?
        var newerThanDays: Int?
        var subject: String?
        var from: String?
        var to: String?
        var cc: String?
        var text: String?
        var messageSizeSmallerThan: Int?
        var messageSizeLargerThan: Int?
        var messageID: MessageID?
        var emailID: EmailID?
        var threadID: ThreadID?
        var flagsSet: Set<NIOIMAP.Flag>
        var flagsNotSet: Set<NIOIMAP.Flag>

        init(
            olderThanDays: Int? = nil,
            newerThanDays: Int? = nil,
            subject: String? = nil,
            from: String? = nil,
            to: String? = nil,
            cc: String? = nil,
            text: String? = nil,
            messageSizeSmallerThan: Int? = nil,
            messageSizeLargerThan: Int? = nil,
            messageID: MessageID? = nil,
            emailID: EmailID? = nil,
            threadID: ThreadID? = nil,
            flagsSet: Set<NIOIMAP.Flag> = [],
            flagsNotSet: Set<NIOIMAP.Flag> = []
        ) {
            self.olderThanDays = olderThanDays
            self.newerThanDays = newerThanDays
            self.subject = subject
            self.from = from
            self.to = to
            self.cc = cc
            self.text = text
            self.messageSizeSmallerThan = messageSizeSmallerThan
            self.messageSizeLargerThan = messageSizeLargerThan
            self.messageID = messageID
            self.emailID = emailID
            self.threadID = threadID
            self.flagsSet = flagsSet
            self.flagsNotSet = flagsNotSet
        }
    }
}

extension SearchKey.Predicate: CustomStringConvertible {
    var description: String {
        var components: [String] = []
        if let olderThanDays {
            components.append("olderThanDays: \(olderThanDays)")
        }
        if let newerThanDays {
            components.append("newerThanDays: \(newerThanDays)")
        }
        if let subject {
            components.append("subject: \"\(subject)\"")
        }
        if let from {
            components.append("from: \"\(from)\"")
        }
        if let to {
            components.append("to: \"\(to)\"")
        }
        if let cc {
            components.append("cc: \"\(cc)\"")
        }
        if let text {
            components.append("text: \"\(text)\"")
        }
        if let messageSizeSmallerThan {
            components.append("messageSizeSmallerThan: \(messageSizeSmallerThan)")
        }
        if let messageSizeLargerThan {
            components.append("messageSizeLargerThan: \(messageSizeLargerThan)")
        }
        if let messageID {
            components.append("messageID: \(messageID)")
        }
        if let emailID {
            components.append("emailID: \(emailID)")
        }
        if let threadID {
            components.append("threadID: \(threadID)")
        }
        if !flagsSet.isEmpty {
            components.append("flagsSet: [\(flagsSet.map { String($0) }.joined(separator: ", "))]")
        }
        if !flagsNotSet.isEmpty {
            components.append("flagsNotSet: [\(flagsNotSet.map { String($0) }.joined(separator: ", "))]")
        }
        return components.joined(separator: ", ")
    }
}

extension IMAPCalendarDay {
    init(
        days: Int,
        since now: Date,
        timeZone: TimeZone
    ) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        guard
            let date = calendar.date(
                byAdding: .day,
                value: -days,
                to: now
            )
        else { throw ValidationError("Can not construct date with \(days) day(s) before now.") }
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard
            let result = IMAPCalendarDay(
                year: components.year!,
                month: components.month!,
                day: components.day!
            )
        else { throw ValidationError("Can not construct date with \(days) day(s) since now.") }
        self = result
    }
}

extension SearchKey {
    /// Builds search criteria from common parameters.
    init(
        _ predicate: Predicate,
        now: Date = Date(),
        timeZone: TimeZone = TimeZone.current
    ) throws {
        var keys: [SearchKey] = []

        // Date based searches:
        if let days = predicate.olderThanDays {
            try keys.append(
                .sentBefore(
                    IMAPCalendarDay(
                        days: days,
                        since: now,
                        timeZone: timeZone
                    )
                )
            )
        }
        if let days = predicate.newerThanDays {
            try keys.append(
                .sentSince(
                    IMAPCalendarDay(
                        days: days,
                        since: now,
                        timeZone: timeZone
                    )
                )
            )
        }

        // Text-based searches
        if let subject = predicate.subject {
            keys.append(.subject(ByteBuffer(string: subject)))
        }
        if let from = predicate.from {
            keys.append(.from(ByteBuffer(string: from)))
        }
        if let to = predicate.to {
            keys.append(.to(ByteBuffer(string: to)))
        }
        if let cc = predicate.cc {
            keys.append(.cc(ByteBuffer(string: cc)))
        }
        if let text = predicate.text {
            keys.append(.text(ByteBuffer(string: text)))
        }

        // Size-based searches
        if let size = predicate.messageSizeSmallerThan {
            keys.append(.messageSizeSmaller(size))
        }
        if let size = predicate.messageSizeLargerThan {
            keys.append(.messageSizeLarger(size))
        }

        // ID-based searches
        if let messageID = predicate.messageID {
            keys.append(.messageID(messageID))
        }
        if let emailID = predicate.emailID {
            keys.append(.emailID(emailID))
        }
        if let threadID = predicate.threadID {
            keys.append(.threadID(threadID))
        }

        // Flag-based searches
        for flag in predicate.flagsSet.sorted(by: { String($0) < String($1) }) {
            try keys.append(.init(flag: flag))
        }

        for flag in predicate.flagsNotSet.sorted(by: { String($0) < String($1) }) {
            try keys.append(.init(notFlag: flag))
        }

        // Combine all keys
        if keys.isEmpty {
            self = .all
        } else if keys.count == 1 {
            self = keys[0]
        } else {
            self = .and(keys)
        }
    }

    init(
        flag: NIOIMAP.Flag
    ) throws {
        if flag == .answered {
            self = .answered
        } else if flag == .flagged {
            self = .flagged
        } else if flag == .deleted {
            self = .deleted
        } else if flag == .seen {
            self = .seen
        } else if flag == .draft {
            self = .draft
        } else if let keyword = NIOIMAP.Flag.Keyword(String(flag)) {
            self = .keyword(keyword)
        } else {
            throw ValidationError("Invalid flag: \(String(flag))")
        }
    }

    init(
        notFlag flag: NIOIMAP.Flag
    ) throws {
        if flag == .answered {
            self = .unanswered
        } else if flag == .flagged {
            self = .unflagged
        } else if flag == .deleted {
            self = .undeleted
        } else if flag == .seen {
            self = .unseen
        } else if flag == .draft {
            self = .undraft
        } else if let keyword = NIOIMAP.Flag.Keyword(String(flag)) {
            self = .not(.keyword(keyword))
        } else {
            throw ValidationError("Invalid flag: \(String(flag))")
        }
    }
}
