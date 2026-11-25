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
                            subject: Array("Your Tripper Bus Ticket".utf8),
                            from: [
                                EmailAddressListElement.singleAddress(
                                    EmailAddress(
                                        personName: Array("TripperBus".utf8),
                                        sourceRoot: nil,
                                        mailbox: Array("noreply".utf8),
                                        host: Array("tripperbus.com".utf8)
                                    )
                                )
                            ],
                            sender: [],
                            reply: [],
                            to: [
                                EmailAddressListElement.singleAddress(
                                    EmailAddress(
                                        personName: Array("Jacob Black".utf8),
                                        sourceRoot: nil,
                                        mailbox: Array("jacob.black.paid".utf8),
                                        host: Array("icloud.com".utf8)
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
