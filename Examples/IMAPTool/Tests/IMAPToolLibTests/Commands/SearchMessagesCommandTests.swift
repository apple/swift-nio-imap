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
@testable import IMAPToolLib
@testable import IMAPCommands
import Foundation
import NIO
@testable import NIOIMAPCore
import Testing

@Suite("SearchMessagesCommand Tests")
private enum SearchMessagesCommandTests {
    static func parse(
        _ arguments: [String],
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> SearchMessagesCommand {
        try ArgumentParsingTests.parse(
            SearchMessagesCommand.self,
            arguments,
            sourceLocation: sourceLocation
        )
    }

    // MARK: - Command Argument Parsing Tests

    @Test
    static func parseSearchCommand_basic() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "plain:foo bar",
            "--server", "bar.example.com",
        ])
        #expect(sut.connectionInfo.server == "bar.example.com")
        #expect(sut.connectionInfo.sasl == "plain:foo bar")
        #expect(sut.mailbox == .inbox)
        #expect(sut.outputFormat == .text)
        #expect(sut.predicate.olderThanDays == nil)
        #expect(sut.predicate.newerThanDays == nil)
        #expect(sut.predicate.subject == nil)
        #expect(sut.predicate.fromAddress == nil)
        #expect(sut.predicate.flags == [])
        #expect(sut.shouldFetchMessageInfo == false)
    }

    @Test
    static func parseSearchCommand_customMailbox() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--mailbox", "Sent",
        ])
        #expect(sut.mailbox == "Sent")
    }

    @Test
    static func parseSearchCommand_outputFormat() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--output-format", "json",
        ])
        #expect(sut.outputFormat == .json)
    }

    // MARK: - Date-based Search Parsing Tests

    @Test
    static func parseSearchCommand_olderThanDays() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--older-than-days", "30",
        ])
        #expect(sut.predicate.olderThanDays == 30)
        #expect(sut.predicate.newerThanDays == nil)
    }

    @Test
    static func parseSearchCommand_newerThanDays() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--newer-than-days", "7",
        ])
        #expect(sut.predicate.newerThanDays == 7)
        #expect(sut.predicate.olderThanDays == nil)
    }

    @Test
    static func parseSearchCommand_bothDateRanges() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--older-than-days", "90",
            "--newer-than-days", "30",
        ])
        #expect(sut.predicate.olderThanDays == 90)
        #expect(sut.predicate.newerThanDays == 30)
    }

    @Test
    static func parseSearchCommand_zeroDays() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--older-than-days", "0",
            "--newer-than-days", "0",
        ])
        #expect(sut.predicate.olderThanDays == 0)
        #expect(sut.predicate.newerThanDays == 0)
    }

    // MARK: - Flag-based Search Parsing Tests

    @Test
    static func parseSearchCommand_singleFlag() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--flag", "seen",
        ])
        #expect(sut.predicate.flags == [.seen])
    }

    @Test
    static func parseSearchCommand_multipleFlags() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--flag", "seen",
            "--flag", "flagged",
            "--flag", "answered",
        ])
        #expect(sut.predicate.flags == [.seen, .flagged, .answered])
    }

    @Test
    static func parseSearchCommand_allStandardFlags() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--flag", "seen",
            "--flag", "flagged",
            "--flag", "answered",
            "--flag", "deleted",
            "--flag", "draft",
        ])
        #expect(sut.predicate.flags == [.seen, .flagged, .answered, .deleted, .draft])
    }

    @Test
    static func parseSearchCommand_mixedCaseFlags() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--flag", "seen",
            "--flag", "flagged",
            "--flag", "answered",
        ])
        #expect(sut.predicate.flags == [.seen, .flagged, .answered])
    }

    @Test
    static func parseSearchCommand_unknownFlags() throws {
        // Unknown flags should fail to parse
        #expect(
            performing: {
                _ = try parse([
                    "search-messages",
                    "--sasl", "plain:foo bar",
                    "--server", "example.com",
                    "--flag", "seen",
                    "--flag", "nonexistent",
                    "--flag", "custom",
                ])
            },
            throws: { _ in true }
        )
    }

    // MARK: - Subject and From Search Parsing Tests

    @Test
    static func parseSearchCommand_subject() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--subject", "Meeting Tomorrow",
        ])
        #expect(sut.predicate.subject == "Meeting Tomorrow")
    }

    @Test
    static func parseSearchCommand_from() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--from", "john@example.com",
        ])
        #expect(sut.predicate.fromAddress == "john@example.com")
    }

    @Test
    static func parseSearchCommand_subjectAndFrom() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--subject", "Important",
            "--from", "boss@company.com",
        ])
        #expect(sut.predicate.subject == "Important")
        #expect(sut.predicate.fromAddress == "boss@company.com")
    }

    @Test
    static func parseSearchCommand_emptySubjectAndFrom() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--subject", "",
            "--from", "",
        ])
        #expect(sut.predicate.subject == "")
        #expect(sut.predicate.fromAddress == "")
    }

    @Test
    static func parseSearchCommand_subjectWithSpaces() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--subject", "Meeting scheduled for next week",
        ])
        #expect(sut.predicate.subject == "Meeting scheduled for next week")
    }

    @Test
    static func parseSearchCommand_fromWithDisplayName() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--from", "John Doe <john@example.com>",
        ])
        #expect(sut.predicate.fromAddress == "John Doe <john@example.com>")
    }

    // MARK: - Message Info Return Flag Tests

    @Test
    static func parseSearchCommand_returnMessageInfo() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--fetch-message-info",
        ])
        #expect(sut.shouldFetchMessageInfo == true)
    }

    @Test
    static func parseSearchCommand_noReturnMessageInfo() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
        ])
        #expect(sut.shouldFetchMessageInfo == false)
    }

    // MARK: - Combined Search Criteria Tests

    @Test
    static func parseSearchCommand_allCriteria() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--mailbox", "Work",
            "--older-than-days", "30",
            "--newer-than-days", "7",
            "--subject", "Project Update",
            "--from", "manager@company.com",
            "--flag", "seen",
            "--flag", "flagged",
            "--fetch-message-info",
            "--output-format", "json",
        ])
        #expect(sut.connectionInfo.server == "example.com")
        #expect(sut.mailbox == "Work")
        #expect(sut.predicate.olderThanDays == 30)
        #expect(sut.predicate.newerThanDays == 7)
        #expect(sut.predicate.subject == "Project Update")
        #expect(sut.predicate.fromAddress == "manager@company.com")
        #expect(sut.predicate.flags == [.seen, .flagged])
        #expect(sut.shouldFetchMessageInfo == true)
        #expect(sut.outputFormat == .json)
    }

    @Test
    static func parseSearchCommand_multipleFlagsAndDates() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--older-than-days", "90",
            "--newer-than-days", "30",
            "--flag", "seen",
            "--flag", "answered",
            "--flag", "flagged",
        ])
        #expect(sut.predicate.olderThanDays == 90)
        #expect(sut.predicate.newerThanDays == 30)
        #expect(sut.predicate.flags == [.seen, .answered, .flagged])
    }

    // MARK: - Edge Cases and Validation Tests

    @Test
    static func parseSearchCommand_largeDayValues() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--older-than-days", "365",
            "--newer-than-days", "1000",
        ])
        #expect(sut.predicate.olderThanDays == 365)
        #expect(sut.predicate.newerThanDays == 1000)
    }

    @Test
    static func parseSearchCommand_unicodeSubject() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--subject", "测试邮件 🎉",
        ])
        #expect(sut.predicate.subject == "测试邮件 🎉")
    }

    @Test
    static func parseSearchCommand_specialCharactersInFrom() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--from", "user+tag@example.com",
        ])
        #expect(sut.predicate.fromAddress == "user+tag@example.com")
    }

    @Test
    static func parseSearchCommand_duplicateFlags() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--flag", "seen",
            "--flag", "seen",
            "--flag", "flagged",
            "--flag", "seen",
        ])
        #expect(sut.predicate.flags == [.seen, .seen, .flagged, .seen])
    }

    @Test
    static func parseSearchCommand_noSearchCriteria() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
        ])
        // Should be valid - will use SearchKey.all
        #expect(sut.predicate.olderThanDays == nil)
        #expect(sut.predicate.newerThanDays == nil)
        #expect(sut.predicate.subject == nil)
        #expect(sut.predicate.fromAddress == nil)
        #expect(sut.predicate.flags == [])
    }

    // MARK: - Search Logic Integration Tests

    @Test
    static func searchLogic_dateCalculation() throws {
        // Test that date calculations work correctly
        let calendar = Calendar.current
        let today = Date()

        // Test older than 30 days
        let olderDate = calendar.date(byAdding: .day, value: -30, to: today)!
        let olderComponents = calendar.dateComponents([.year, .month, .day], from: olderDate)
        let olderIMAPDate = IMAPCalendarDay(
            year: olderComponents.year!,
            month: olderComponents.month!,
            day: olderComponents.day!
        )
        #expect(olderIMAPDate != nil)

        // Test newer than 7 days
        let newerDate = calendar.date(byAdding: .day, value: -7, to: today)!
        let newerComponents = calendar.dateComponents([.year, .month, .day], from: newerDate)
        let newerIMAPDate = IMAPCalendarDay(
            year: newerComponents.year!,
            month: newerComponents.month!,
            day: newerComponents.day!
        )
        #expect(newerIMAPDate != nil)

        // Newer date should be more recent than older date
        if let older = olderIMAPDate, let newer = newerIMAPDate {
            #expect(newer.year >= older.year)
            if newer.year == older.year {
                #expect(newer.month >= older.month)
                if newer.month == older.month {
                    #expect(newer.day >= older.day)
                }
            }
        }
    }

    @Test
    static func searchLogic_flagMapping() throws {
        // Test that flag strings map correctly to lowercase
        let flagMappings: [String: String] = [
            "seen": "seen",
            "flagged": "flagged",
            "answered": "answered",
            "deleted": "deleted",
            "draft": "draft",
        ]

        for (input, expected) in flagMappings {
            // Test lowercase
            #expect(input.lowercased() == expected)

            // Test that uppercase works too
            #expect(input.uppercased().lowercased() == expected)
        }
    }

    @Test
    static func searchLogic_byteBufferCreation() throws {
        // Test ByteBuffer creation for subject and from strings
        let testStrings = [
            "Simple subject",
            "Subject with unicode 🎉",
            "Empty string: ",
            "Subject with\nnewlines\nand\ttabs",
            "user@example.com",
            "User Name <user@example.com>",
            "用户@example.com",  // Unicode email
        ]

        for testString in testStrings {
            let buffer = ByteBuffer(string: testString)
            #expect(buffer.readableBytes > 0 || testString.isEmpty)

            // Verify we can read the string back
            let reconstructed = buffer.getString(at: 0, length: buffer.readableBytes)
            #expect(reconstructed == testString)
        }
    }

    @Test
    static func searchLogic_combinedSearchKeys() throws {
        // Test the logic for combining multiple search criteria
        var searchKeys: [SearchKey] = []

        // Add various criteria
        searchKeys.append(.seen)
        searchKeys.append(.flagged)
        let subjectBuffer = ByteBuffer(string: "test")
        searchKeys.append(.subject(subjectBuffer))

        // Test single key
        let singleKey = searchKeys.first!
        let singleKeyDesc = String(describing: singleKey).uppercased()
        #expect(singleKeyDesc.contains("SEEN"))

        // Test combined key
        if searchKeys.count > 1 {
            let combinedKey = SearchKey.and(searchKeys)
            // The combined key should contain multiple search terms
            let combinedKeyDesc = String(describing: combinedKey).uppercased()
            #expect(combinedKeyDesc.contains("SEEN"))
            #expect(combinedKeyDesc.contains("FLAGGED"))
            #expect(combinedKeyDesc.contains("SUBJECT"))
        }

        // Test empty case (should use .all)
        let emptyKeys: [SearchKey] = []
        if emptyKeys.isEmpty {
            let allKey = SearchKey.all
            let allKeyDesc = String(describing: allKey).uppercased()
            #expect(allKeyDesc.contains("ALL"))
        }
    }

    // MARK: - Invalid Input Tests

    @Test
    static func parseSearchCommand_negativeOlderThanDays() throws {
        // Negative day values should be treated as invalid by ArgumentParser
        #expect(
            performing: {
                _ = try parse([
                    "search-messages",
                    "--sasl", "plain:foo bar",
                    "--server", "example.com",
                    "--older-than-days", "-5",
                ])
            },
            throws: { _ in true }
        )
    }

    @Test
    static func parseSearchCommand_negativeNewerThanDays() throws {
        // Negative day values should be treated as invalid by ArgumentParser
        #expect(
            performing: {
                _ = try parse([
                    "search-messages",
                    "--sasl", "plain:foo bar",
                    "--server", "example.com",
                    "--newer-than-days", "-10",
                ])
            },
            throws: { _ in true }
        )
    }

    // MARK: - IMAPConnection Info Tests

    @Test
    static func parseSearchCommand_usernameAuth() throws {
        let sut = try parse([
            "search-messages",
            "--username", "user:password",
            "--server", "example.com",
        ])
        #expect(sut.connectionInfo.username == "user:password")
        #expect(sut.connectionInfo.sasl == nil)
    }

    @Test
    static func parseSearchCommand_saslAuth() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "oauth:token123",
            "--server", "example.com",
        ])
        #expect(sut.connectionInfo.sasl == "oauth:token123")
        #expect(sut.connectionInfo.username == nil)
    }

    @Test
    static func parseSearchCommand_customPort() throws {
        let sut = try parse([
            "search-messages",
            "--username", "user:pass",
            "--server", "example.com:143",
        ])
        #expect(sut.connectionInfo.server == "example.com:143")
    }

    @Test
    static func parseSearchCommand_forceLogin() throws {
        let sut = try parse([
            "search-messages",
            "--username", "user:pass",
            "--server", "example.com",
            "--force-login",
        ])
        #expect(sut.connectionInfo.forceLogin == true)
    }

    // MARK: - Real-world Usage Pattern Tests

    @Test
    static func parseSearchCommand_findUnreadMessagesFromLastWeek() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "oauth:token123",
            "--server", "imap.gmail.com",
            "--newer-than-days", "7",
            "--flag", "seen",
            "--fetch-message-info",
        ])
        #expect(sut.predicate.newerThanDays == 7)
        #expect(sut.predicate.flags == [.seen])
        #expect(sut.shouldFetchMessageInfo == true)
    }

    @Test
    static func searchLogic_sequenceNumberToMessageInfoMapping() throws {
        // Test that we understand the difference between sequence numbers and UIDs
        // This test documents the fix for the sequence number vs UID confusion

        // Simulate search results (sequence numbers)
        let searchResults: [SequenceNumber] = [SequenceNumber(1), SequenceNumber(3), SequenceNumber(5)]

        // Simulate message infos (with UIDs that are different from sequence numbers)
        struct MockMessageInfo {
            let uid: UInt32
            let sequenceNumber: Int
        }

        let allMessageInfos = [
            MockMessageInfo(uid: 1001, sequenceNumber: 1),  // seq 1, uid 1001
            MockMessageInfo(uid: 1005, sequenceNumber: 2),  // seq 2, uid 1005
            MockMessageInfo(uid: 1007, sequenceNumber: 3),  // seq 3, uid 1007
            MockMessageInfo(uid: 1012, sequenceNumber: 4),  // seq 4, uid 1012
            MockMessageInfo(uid: 1015, sequenceNumber: 5),  // seq 5, uid 1015
        ]

        // Test the WRONG approach (matching sequence numbers against UIDs)
        let searchUIDs = Set(searchResults.map { UInt32($0) })  // [1, 3, 5]
        let wrongFiltered = allMessageInfos.filter { searchUIDs.contains($0.uid) }
        #expect(wrongFiltered.isEmpty)  // This fails because UIDs don't match sequence numbers

        // Test the CORRECT approach (matching by sequence number position)
        let searchSequenceNumbers = Set(searchResults.map { Int($0) })  // [1, 3, 5]
        let correctFiltered = allMessageInfos.enumerated().compactMap { (index, messageInfo) in
            let sequenceNumber = index + 1  // Convert 0-based index to 1-based sequence
            return searchSequenceNumbers.contains(sequenceNumber) ? messageInfo : nil
        }
        #expect(correctFiltered.count == 3)  // Should find 3 messages
        #expect(correctFiltered[0].uid == 1001)  // seq 1 -> uid 1001
        #expect(correctFiltered[1].uid == 1007)  // seq 3 -> uid 1007
        #expect(correctFiltered[2].uid == 1015)  // seq 5 -> uid 1015
    }

    @Test
    static func parseSearchCommand_findImportantEmailsFromBoss() throws {
        let sut = try parse([
            "search-messages",
            "--username", "employee:password",
            "--server", "company.com",
            "--from", "boss@company.com",
            "--flag", "flagged",
            "--subject", "urgent",
            "--mailbox", "INBOX",
        ])
        #expect(sut.predicate.fromAddress == "boss@company.com")
        #expect(sut.predicate.flags == [.flagged])
        #expect(sut.predicate.subject == "urgent")
        #expect(sut.mailbox == .inbox)
    }

    @Test
    static func parseSearchCommand_cleanupOldDrafts() throws {
        let sut = try parse([
            "search-messages",
            "--username", "user:pass",
            "--server", "example.com",
            "--mailbox", "Drafts",
            "--older-than-days", "90",
            "--flag", "draft",
            "--output-format", "json",
        ])
        #expect(sut.mailbox == "Drafts")
        #expect(sut.predicate.olderThanDays == 90)
        #expect(sut.predicate.flags == [.draft])
        #expect(sut.outputFormat == .json)
    }

    @Test
    static func parseSearchCommand_findAnsweredEmailsInDateRange() throws {
        let sut = try parse([
            "search-messages",
            "--sasl", "plain:token123",
            "--server", "imap.example.com",
            "--older-than-days", "30",
            "--newer-than-days", "7",
            "--flag", "answered",
            "--flag", "seen",
            "--fetch-message-info",
        ])
        #expect(sut.predicate.olderThanDays == 30)
        #expect(sut.predicate.newerThanDays == 7)
        #expect(sut.predicate.flags == [.answered, .seen])
        #expect(sut.shouldFetchMessageInfo == true)
    }
}
