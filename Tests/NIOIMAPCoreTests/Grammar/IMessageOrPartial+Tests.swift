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

import NIO
@testable import NIOIMAPCore
import XCTest

class URLFetchType_Tests: EncodeTestClass {}

// MARK: - IMAP

extension URLFetchType_Tests {
    func testEncode() {
        let inputs: [(URLFetchType, String, UInt)] = [
            (
                .partialOnly(.init(range: .init(offset: 1, length: 2))),
                ";PARTIAL=1.2",
                #line
            ),
            (
                .sectionPartial(section: .init(encodedSection: .init(section: "section")), partial: nil),
                ";SECTION=section",
                #line
            ),
            (
                .sectionPartial(section: .init(encodedSection: .init(section: "section")), partial: .init(range: .init(offset: 1, length: 2))),
                ";SECTION=section/;PARTIAL=1.2",
                #line
            ),
            (
                .uidSectionPartial(uid: .init(uid: 123), section: nil, partial: nil),
                ";UID=123",
                #line
            ),
            (
                .uidSectionPartial(uid: .init(uid: 123), section: .init(encodedSection: .init(section: "test")), partial: nil),
                ";UID=123/;SECTION=test",
                #line
            ),
            (
                .uidSectionPartial(uid: .init(uid: 123), section: nil, partial: .init(range: .init(offset: 1, length: 2))),
                ";UID=123/;PARTIAL=1.2",
                #line
            ),
            (
                .uidSectionPartial(uid: .init(uid: 123), section: .init(encodedSection: .init(section: "test")), partial: .init(range: .init(offset: 1, length: 2))),
                ";UID=123/;SECTION=test/;PARTIAL=1.2",
                #line
            ),
            (
                .refUidSectionPartial(ref: .init(encodeMailbox: .init(mailbox: "test")), uid: .init(uid: 123), section: nil, partial: nil),
                "test;UID=123",
                #line
            ),
            (
                .refUidSectionPartial(ref: .init(encodeMailbox: .init(mailbox: "test")), uid: .init(uid: 123), section: .init(encodedSection: .init(section: "box")), partial: nil),
                "test;UID=123/;SECTION=box",
                #line
            ),
            (
                .refUidSectionPartial(ref: .init(encodeMailbox: .init(mailbox: "test")), uid: .init(uid: 123), section: nil, partial: .init(range: .init(offset: 1, length: 2))),
                "test;UID=123/;PARTIAL=1.2",
                #line
            ),
            (
                .refUidSectionPartial(ref: .init(encodeMailbox: .init(mailbox: "test")), uid: .init(uid: 123), section: .init(encodedSection: .init(section: "box")), partial: .init(range: .init(offset: 1, length: 2))),
                "test;UID=123/;SECTION=box/;PARTIAL=1.2",
                #line
            ),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeURLFetchType($0) })
    }
}
