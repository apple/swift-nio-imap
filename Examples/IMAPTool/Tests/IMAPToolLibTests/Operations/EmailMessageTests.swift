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
import Foundation
@testable import IMAPToolLib
import Testing
import SystemPackage

@Suite("EmailMessage")
private enum EmailMessageTests {
    @Test
    static func convertLineEndings() throws {
        let sut = EmailMessage.convertingLineEndings(
            #"""
            To: noreply@apple.com
            Subject: Test

            Hello
            """#.data(using: .utf8)!
        )

        #expect(
            Array(sut.data) == [
                0x54, 0x6F, 0x3A, 0x20, 0x6E, 0x6F, 0x72, 0x65, 0x70, 0x6C, 0x79, 0x40, 0x61, 0x70, 0x70, 0x6C, 0x65,
                0x2E, 0x63, 0x6F, 0x6D,
                0xD, 0xA,
                0x53, 0x75, 0x62, 0x6A, 0x65, 0x63, 0x74, 0x3A, 0x20, 0x54, 0x65, 0x73, 0x74,
                0xD, 0xA,
                0xD, 0xA,
                0x48, 0x65, 0x6C, 0x6C, 0x6F,
            ]
        )
    }

    @Test
    static func findMessageID() throws {
        let sut = EmailMessage.convertingLineEndings(
            #"""
            From: bar@none.com
            To: phooey@all.com
            Subject: Here's how to do it
            Message-ID: <970701.32784@VIers.none.com>
            Date: Tue, 10 Jun 2025 21:49:03 +0000 (GMT)
            Content-type: text/html; charset=usascii

            <A HREF= "mid:960830.1639@XIson.com/partA.960830.1639@XIson.com">
            previous message</A>, shows how the approach you propose can be
            used to accomplish
            """#.data(using: .utf8)!
        )

        #expect(sut.headersOfInterest?.messageID == "<970701.32784@VIers.none.com>")
        #expect(sut.headersOfInterest?.date == "Tue, 10 Jun 2025 21:49:03 +0000 (GMT)")
    }

    @Test
    static func headerIsCRLFCleanWithCRLFEndings() throws {
        // The first four line breaks must all be CRLF.
        let input = "To: noreply@apple.com\r\nSubject: Test\r\nFrom: x@y.com\r\nDate: now\r\n\r\nHello\n"
            .data(using: .utf8)!
        #expect(EmailMessage.headerIsCRLFClean(input))
    }

    @Test
    static func headerIsNotCRLFCleanWithLFEndings() throws {
        let input = "To: noreply@apple.com\nSubject: Test\n\nHello\n".data(using: .utf8)!
        #expect(!EmailMessage.headerIsCRLFClean(input))
    }

    @Test
    static func headerIsNotCRLFCleanWithBareCR() throws {
        let input = "To: noreply@apple.com\rSubject: Test\r\n".data(using: .utf8)!
        #expect(!EmailMessage.headerIsCRLFClean(input))
    }
}
