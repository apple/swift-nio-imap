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

import Foundation
@testable import IMAPToolLib
import NIO
import NIOIMAP
import Testing

@Suite
private enum MessageInfoTests {
    @Test
    static func fromMessageAttributes() {
        #expect(
            MessageInfo(
                uid: 8_089_525,
                attributes: [
                    MessageAttribute.envelope(
                        Envelope(
                            date: "Sat, 19 Oct 2024 03:36:04 +0000",
                            subject: ByteBuffer(string: "Your Tripper Bus Ticket"),
                            from: [
                                EmailAddressListElement.singleAddress(
                                    EmailAddress(
                                        personName: ByteBuffer(string: "TripperBus"),
                                        sourceRoot: nil,
                                        mailbox: ByteBuffer(string: "noreply"),
                                        host: ByteBuffer(string: "tripperbus.com")
                                    )
                                )
                            ],
                            sender: [],
                            reply: [],
                            to: [
                                EmailAddressListElement.singleAddress(
                                    EmailAddress(
                                        personName: ByteBuffer(string: "Jacob Black"),
                                        sourceRoot: nil,
                                        mailbox: ByteBuffer(string: "jacob.black.paid"),
                                        host: ByteBuffer(string: "icloud.com")
                                    )
                                )
                            ],
                            cc: [],
                            bcc: [],
                            inReplyTo: nil,
                            messageID: MessageID("<20250619033604.32962e456969f8f6@tripperbus.com>")
                        )
                    ),
                    MessageAttribute.flags([.answered, .seen]),
                ]
            )
                == MessageInfo(
                    uid: 8_089_525,
                    date: "Sat, 19 Oct 2024 03:36:04 +0000",
                    dateSeconds: 1_729_308_964,
                    subject: "Your Tripper Bus Ticket",
                    from: #""TripperBus" <noreply@tripperbus.com>"#,
                    to: #""Jacob Black" <jacob.black.paid@icloud.com>"#,
                    cc: nil,
                    messageID: "<20250619033604.32962e456969f8f6@tripperbus.com>",
                    inReplyTo: nil,
                    flags: [
                        #"\Answered"#,
                        #"\Seen"#,
                    ]
                )
        )
    }
}
