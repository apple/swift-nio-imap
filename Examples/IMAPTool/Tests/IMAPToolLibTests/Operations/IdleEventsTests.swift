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

@testable import IMAPCommands
import Foundation
@testable import IMAPToolLib
import NIO
import NIOIMAP
import Testing

@Suite
private enum IdleEventsTests {
    @Test
    static func encoding() async throws {
        func jsonEncode(_ event: IdleEvent) -> String {
            do {
                return try String(decoding: makeResultData(event, format: .json), as: UTF8.self)
            } catch {
                return "failed: \(error)"
            }
        }

        #expect(
            jsonEncode(.exists(208976)) == #"""
                {
                  "count" : 208976,
                  "kind" : "exists"
                }
                """#
        )
        #expect(
            jsonEncode(.expunge(200622)) == #"""
                {
                  "kind" : "expunge",
                  "sequenceNumber" : 200622
                }
                """#
        )
        #expect(
            jsonEncode(.vanished([1_109_412])) == #"""
                {
                  "kind" : "vanished",
                  "uids" : "1109412",
                  "uidsList" : [
                    1109412
                  ]
                }
                """#
        )
        #expect(
            jsonEncode(
                .vanished([51327, 65956, 258891, 469223, 565342, 722572, 985909, 1_406_543, 1_681_131, 1_831_100])
            ) == #"""
                {
                  "kind" : "vanished",
                  "uids" : "51327,65956,258891,469223,565342,722572,985909,1406543,1681131,1831100",
                  "uidsList" : [
                    51327,
                    65956,
                    258891,
                    469223,
                    565342,
                    722572,
                    985909,
                    1406543,
                    1681131,
                    1831100
                  ]
                }
                """#
        )
        #expect(
            jsonEncode(.vanished([51327, 65956...65960, 1_831_100])) == #"""
                {
                  "kind" : "vanished",
                  "uids" : "51327,65956:65960,1831100",
                  "uidsList" : [
                    51327,
                    65956,
                    65957,
                    65958,
                    65959,
                    65960,
                    1831100
                  ]
                }
                """#
        )
        #expect(
            jsonEncode(.fetch(1_331_855, [.flags([.seen])])) == #"""
                {
                  "flags" : [
                    "\\Seen"
                  ],
                  "kind" : "fetch",
                  "sequenceNumber" : 1331855
                }
                """#
        )
        #expect(
            jsonEncode(.fetch(378_377, [.flags([]), .uid(1_893_959)])) == #"""
                {
                  "flags" : [

                  ],
                  "kind" : "fetch",
                  "sequenceNumber" : 378377,
                  "uid" : 1893959
                }
                """#
        )
        #expect(
            jsonEncode(.fetch(18_081, [.flags([.seen, .deleted]), .uid(771_126)])) == #"""
                {
                  "flags" : [
                    "\\Seen",
                    "\\Deleted"
                  ],
                  "kind" : "fetch",
                  "sequenceNumber" : 18081,
                  "uid" : 771126
                }
                """#
        )
        #expect(
            jsonEncode(.fetch(nil, [.rfc822Size(98_453), .uid(499_452)])) == #"""
                {
                  "kind" : "fetch",
                  "rfc822Size" : 98453,
                  "uid" : 499452
                }
                """#
        )
    }

    @Test
    static func decoding() {
        func decode(_ input: [Response]) -> [IdleEvent] {
            var decoder = IdleEventDecoder.normal
            var result: [IdleEvent] = []
            for response in input {
                if let e = decoder.update(response) {
                    result.append(e)
                }
            }
            return result
        }

        #expect(
            decode([
                .untagged(.mailboxData(.exists(1_271_487)))
            ]) == [
                .exists(1_271_487)
            ]
        )
        #expect(
            decode([
                .untagged(.messageData(.expunge(576_840)))
            ]) == [
                .expunge(576_840)
            ]
        )
        #expect(
            decode([
                .untagged(.messageData(.vanished([557, 991, 1031, 1658, 1825, 1895])))
            ]) == [
                .vanished([557, 991, 1031, 1658, 1825, 1895])
            ]
        )
        #expect(
            decode([
                .fetch(.start(504_274)),
                .fetch(.simpleAttribute(.flags([.seen]))),
                .fetch(.finish),
            ]) == [
                .fetch(504_274, [.flags([.seen])])
            ]
        )
        #expect(
            decode([
                .untagged(.mailboxData(.exists(90_124))),
                .fetch(.start(504_274)),
                .fetch(.simpleAttribute(.flags([.seen]))),
                .fetch(.finish),
                .untagged(.mailboxData(.exists(1_816_239))),
            ]) == [
                .exists(90_124),
                .fetch(504_274, [.flags([.seen])]),
                .exists(1_816_239),
            ]
        )
    }
}
