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

import Testing
import Dispatch
import Foundation
import NIOIMAPCore
@testable import IMAPToolLib

@Suite("MIMEMessage line scanning")
struct MIMEMessageLineScanningTests {

    @Test("Finds Date header with CRLF line endings")
    func dateHeaderCRLF() {
        let input =
            "From: sender@example.com\r\nDate: Fri, 15 Mar 2024 10:30:45 +0100\r\nSubject: Hello\r\n\r\nBody here"
        #expect(dateFrom(input) == "Fri, 15 Mar 2024 10:30:45 +0100")
    }

    @Test("Finds Date header with LF line endings")
    func dateHeaderLF() {
        let input = "From: sender@example.com\nDate: Fri, 15 Mar 2024 10:30:45 +0100\nSubject: Hello\n\nBody here"
        #expect(dateFrom(input) == "Fri, 15 Mar 2024 10:30:45 +0100")
    }

    @Test("Case-insensitive header name matching")
    func caseInsensitive() {
        let input = "DATE: Mon, 01 Jan 2024 00:00:00 +0000\r\n\r\n"
        #expect(dateFrom(input) == "Mon, 01 Jan 2024 00:00:00 +0000")
    }

    @Test("Mixed case header name")
    func mixedCase() {
        let input = "dAtE: Tue, 02 Jan 2024 12:00:00 -0500\r\n\r\n"
        #expect(dateFrom(input) == "Tue, 02 Jan 2024 12:00:00 -0500")
    }

    @Test("Stops at empty line — Date in body is not found")
    func stopsAtEmptyLine() {
        let input = "From: sender@example.com\r\n\r\nDate: Fri, 15 Mar 2024 10:30:45 +0100\r\n"
        #expect(dateFrom(input) == nil)
    }

    @Test("Returns nil when no Date header present")
    func noDateHeader() {
        let input = "From: sender@example.com\r\nSubject: Hello\r\n\r\nBody"
        #expect(dateFrom(input) == nil)
    }

    @Test("Trims leading whitespace from value")
    func trimsLeadingWhitespace() {
        let input = "Date:   Fri, 15 Mar 2024 10:30:45 +0100\r\n\r\n"
        #expect(dateFrom(input) == "Fri, 15 Mar 2024 10:30:45 +0100")
    }

    @Test("Trims trailing whitespace from value")
    func trimsTrailingWhitespace() {
        let input = "Date: Fri, 15 Mar 2024 10:30:45 +0100   \r\n\r\n"
        #expect(dateFrom(input) == "Fri, 15 Mar 2024 10:30:45 +0100")
    }

    @Test("Handles tab after colon")
    func tabAfterColon() {
        let input = "Date:\tFri, 15 Mar 2024 10:30:45 +0100\r\n\r\n"
        #expect(dateFrom(input) == "Fri, 15 Mar 2024 10:30:45 +0100")
    }

    @Test("Returns nil for empty buffer")
    func emptyBuffer() {
        #expect(dateFrom("") == nil)
    }

    @Test("Headers without terminating empty line still finds Date")
    func noTerminatingEmptyLine() {
        let input = "Date: Fri, 15 Mar 2024 10:30:45 +0100\r\nSubject: Hello"
        #expect(dateFrom(input) == "Fri, 15 Mar 2024 10:30:45 +0100")
    }

    @Test("Does not match partial header name like X-Date")
    func doesNotMatchPartialName() {
        let input = "X-Date: not this one\r\nDate: the real one\r\n\r\n"
        #expect(dateFrom(input) == "the real one")
    }

    @Test("Enumerates multiple headers in order")
    func enumeratesMultipleHeaders() {
        let input = "From: alice\r\nTo: bob\r\nSubject: hi\r\n\r\n"
        var names: [String] = []
        let message = MIMEMessage.data(Data(input.utf8))
        message.withContiguousBytes { buffer in
            message.enumerateHeaderLines(in: buffer) { name, _ in
                names.append(String(decoding: name, as: UTF8.self))
                return true
            }
        }
        #expect(names == ["From", "To", "Subject"])
    }

    @Test("Stops enumeration when body returns false")
    func stopsOnFalse() {
        let input = "A: 1\r\nB: 2\r\nC: 3\r\n\r\n"
        var count = 0
        let message = MIMEMessage.data(Data(input.utf8))
        message.withContiguousBytes { buffer in
            message.enumerateHeaderLines(in: buffer) { _, _ in
                count += 1
                return count < 2
            }
        }
        #expect(count == 2)
    }

    private func dateFrom(_ string: String) -> String? {
        let message = MIMEMessage.data(Data(string.utf8))
        guard let date = message.dateHeader() else { return nil }
        return String(date)
    }
}

@Suite("MIMEMessage.messageIDHeader()")
struct MIMEMessageMessageIDTests {

    @Test("Finds Message-ID header")
    func findsMessageID() {
        let input = "Date: Mon, 01 Jan 2024 00:00:00 +0000\r\nMessage-ID: <abc@example.com>\r\n\r\n"
        let message = MIMEMessage.data(Data(input.utf8))
        let result = message.messageIDHeader()
        #expect(result != nil)
        #expect(String(result!) == "<abc@example.com>")
    }

    @Test("Case-insensitive Message-ID matching")
    func caseInsensitive() {
        let input = "MESSAGE-ID: <XYZ@host>\r\n\r\n"
        let message = MIMEMessage.data(Data(input.utf8))
        #expect(String(message.messageIDHeader()!) == "<XYZ@host>")
    }

    @Test("Returns nil when not present")
    func notPresent() {
        let input = "Date: Mon, 01 Jan 2024 00:00:00 +0000\r\n\r\n"
        let message = MIMEMessage.data(Data(input.utf8))
        #expect(message.messageIDHeader() == nil)
    }

    @Test("Does not match partial name like X-Message-ID")
    func doesNotMatchPartial() {
        let input = "X-Message-ID: <wrong>\r\nMessage-ID: <right@host>\r\n\r\n"
        let message = MIMEMessage.data(Data(input.utf8))
        #expect(String(message.messageIDHeader()!) == "<right@host>")
    }
}

@Suite("MIMEMessage.headersOfInterest()")
struct MIMEMessageHeadersOfInterestTests {

    @Test("Returns both date and message-id in a single pass")
    func returnsBoth() {
        let input = "Message-ID: <id@host>\r\nDate: Wed, 10 Apr 2024 08:15:30 +0000\r\nSubject: Hello\r\n\r\nBody"
        let message = MIMEMessage.data(Data(input.utf8))
        let result = message.headersOfInterest()
        #expect(result != nil)
        #expect(String(result!.date) == "Wed, 10 Apr 2024 08:15:30 +0000")
        #expect(String(result!.messageID) == "<id@host>")
    }

    @Test("Returns nil when date is missing")
    func missingDate() {
        let input = "Message-ID: <id@host>\r\nSubject: Hello\r\n\r\n"
        let message = MIMEMessage.data(Data(input.utf8))
        #expect(message.headersOfInterest() == nil)
    }

    @Test("Returns nil when message-id is missing")
    func missingMessageID() {
        let input = "Date: Wed, 10 Apr 2024 08:15:30 +0000\r\nSubject: Hello\r\n\r\n"
        let message = MIMEMessage.data(Data(input.utf8))
        #expect(message.headersOfInterest() == nil)
    }

    @Test("Stops scanning once both are found")
    func stopsEarly() {
        let input =
            "Date: Wed, 10 Apr 2024 08:15:30 +0000\r\nMessage-ID: <id@host>\r\nX-Extra: should not be reached\r\n\r\n"
        var headerCount = 0
        let data = Data(input.utf8)
        let message = MIMEMessage.data(data)
        message.withContiguousBytes { buffer in
            var date: InternetMessageDate?
            var messageID: MessageID?
            message.enumerateHeaderLines(in: buffer) { name, value in
                headerCount += 1
                let nameStr = String(decoding: name, as: UTF8.self).lowercased()
                if nameStr == "date" {
                    date = InternetMessageDate("x")
                } else if nameStr == "message-id" {
                    messageID = MessageID("x")
                }
                return date == nil || messageID == nil
            }
        }
        #expect(headerCount == 2)
    }

    @Test("Works with DispatchData")
    func worksWithDispatchData() {
        let input = "Message-ID: <dd@host>\r\nDate: Fri, 01 Jan 2024 00:00:00 +0000\r\n\r\n"
        let data = input.data(using: .utf8)!
        let dd = data.withUnsafeBytes { DispatchData(bytes: $0) }
        let message = MIMEMessage.dispatchData(dd)
        let result = message.headersOfInterest()
        #expect(result != nil)
        #expect(String(result!.messageID) == "<dd@host>")
    }
}
