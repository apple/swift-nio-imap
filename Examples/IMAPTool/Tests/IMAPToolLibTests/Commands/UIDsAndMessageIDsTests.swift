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

@testable import IMAPToolLib
import Foundation
import NIO
import NIOIMAP
import Testing

@Suite
enum UIDsAndMessageIDsTests {
    @Test
    static func parsingJSON_1() throws {
        let ids = try UIDsAndMessageIDs.parse(
            input: Data(
                #"""
                {"messages" : [{"filename" : "Available now_ Bayonetta 3.eml","id" : "<61bed42d-59c4-4734-b501-c903d3ba8952@atl1s07mta2958.xt.local>","uid" : 34},{"filename" : "New sign-in to your account 5.eml","id" : "<010001762fc8b627-39331a9f-265d-4135-8367-8fdaf93a44ed-000000@email.amazonses.com>","uid" : 5678}]}
                """#.utf8
            )
        )
        #expect(ids.uids == [34, 5678])
        #expect(ids.messageIDs == [])
    }

    @Test
    static func parsingJSON_2() throws {
        let ids = try UIDsAndMessageIDs.parse(
            input: Data(
                #"""
                {"messages" : [{"uid" : 34},{"uid" : 5678}]}
                """#.utf8
            )
        )
        #expect(ids.uids == [34, 5678])
        #expect(ids.messageIDs == [])
    }

    @Test
    static func parsingJSON_3() throws {
        let ids = try UIDsAndMessageIDs.parse(
            input: Data(
                #"""
                {"messages" : [{"uid" : 30}]}
                """#.utf8
            )
        )
        #expect(ids.uids == [30])
        #expect(ids.messageIDs == [])
    }

    @Test
    static func parsingJSON_4() throws {
        let ids = try UIDsAndMessageIDs.parse(
            input: Data(
                #"""
                {"messages" : [{"id" : "<61bed42d-59c4-4734-b501-c903d3ba8952@atl1s07mta2958.xt.local>"},{"id" : "<010001762fc8b627-39331a9f-265d-4135-8367-8fdaf93a44ed-000000@email.amazonses.com>"}]}
                """#.utf8
            )
        )
        #expect(ids.uids == [])
        #expect(
            ids.messageIDs == [
                "<61bed42d-59c4-4734-b501-c903d3ba8952@atl1s07mta2958.xt.local>",
                "<010001762fc8b627-39331a9f-265d-4135-8367-8fdaf93a44ed-000000@email.amazonses.com>",
            ]
        )
    }
}
