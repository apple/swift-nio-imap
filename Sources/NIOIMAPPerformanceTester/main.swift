//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2019 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import NIO
import NIOIMAP

let commands: [(String, Command)] = [
    ("Check", .check),
    ("Start TLS", .starttls),
    ("Idle start", .idleStart),
    ("Logout", .logout),
    ("Login", .login(username: "test", password: "test")),
    ("Capability", .capability),
    ("Close", .close),
    ("Namespace", .namespace),
    ("Noop", .noop),
    ("Unselect", .unselect),
    ("Create (no atts)", .create(.init("My Test Mailbox"), [])),
    ("Create (one att)", .create(.init("My Test Mailbox"), [.attributes([.flagged])])),
    ("Create (many att)", .create(.init("My Test Mailbox"), [.attributes([.flagged, .junk, .archive, .sent, .trash])])),
    ("Delete", .delete(.inbox)),
    ("Enable (lots)", .enable([.acl, .binary, .catenate, .condStore, .children, .esearch, .esort, .namespace])),
    ("Enable (one)", .enable([.namespace])),
    ("Copy (last command)", .copy(.lastCommand, .inbox)),
    ("Copy (all)", .copy(.all, .inbox)),
    ("Copy (set-one)", .copy([1 ... 2, 4 ... 5, 10 ... 20], .inbox)),
    ("Copy (set-many)", .copy([1 ... 100], .inbox)),
    ("Fetch (last command, lots)", .fetch(.lastCommand, [.envelope, .flags, .internalDate, .gmailThreadID, .modificationSequence], [])),
    ("Fetch (all, lots)", .fetch(.all, [.envelope, .flags, .internalDate, .gmailThreadID, .modificationSequence], [])),
    ("Fetch (set-one, lots)", .fetch([1 ... 10], [.envelope, .flags, .internalDate, .gmailThreadID, .modificationSequence], [])),
    ("Fetch (set-many, lots)", .fetch([1 ... 2, 4 ... 7, 10 ... 100], [.envelope, .flags, .internalDate, .gmailThreadID, .modificationSequence], [])),
    ("Auth (plain, nil)", .authenticate(method: "PLAIN", initialClientResponse: nil)),
    ("Auth (plain, empty)", .authenticate(method: "PLAIN", initialClientResponse: .empty)),
    ("Auth (plain, initial data)", .authenticate(method: "PLAIN", initialClientResponse: .data(ByteBuffer(string: "dGhpcyBpcyB0ZXN0IGJhc2U2NA==")))),
    ("ESearch (simple all)", .esearch(.init(key: .all))),
    ("ESearch (simple recursive + date)", .esearch(.init(key: .and([.not(.answered), .not(.before(.init(year: 2000, month: 12, day: 12)!))])))),
    ("ESearch (complex)", .esearch(.init(key: .and([.younger(123), .or(.keyword(.colorBit0), .keyword(.colorBit1))]), charset: "UTF-8", returnOptions: [.min, .max, .count], sourceOptions: .init(sourceMailbox: [.inboxes])!))),
    ("Examine (no params)", .examine(.inbox, [])),
    ("Examine (1 param)", .examine(.inbox, [.init(name: "param")])),
    ("Examine (lots param)", .examine(.inbox, [.init(name: "param1"), .init(name: "param2"), .init(name: "param3", value: .sequence(.range([1 ... 5, 10 ... 100]))), .init(name: "param4", value: .comp(["str1"]))])),
    ("Expunge", .expunge),
    ("GenURLAuth (one)", .genURLAuth([.init(urlRump: ByteBuffer(string: "test"), mechanism: .internal)])),
    ("GenURLAuth (many)", .genURLAuth([.init(urlRump: ByteBuffer(string: "test1"), mechanism: .internal), .init(urlRump: ByteBuffer(string: "test2"), mechanism: .internal), .init(urlRump: ByteBuffer(string: "test3"), mechanism: .internal)])),
    ("Get Metadata (complex)", .getMetadata(options: [.maxSize(123), .scope(.infinity)], mailbox: .inbox, entries: [ByteBuffer(string: "test1"), ByteBuffer(string: "test2")])),
    ("Get Quota", .getQuota(.init("inbox"))),
    ("Select (params-none)", .select(.inbox, [])),
    ("Select (params-one)", .select(.inbox, [.condstore])),
    ("Select (params-complex)", .select(.inbox, [.condstore, .basic(.init(name: "param1")), .qresync(.init(uidValiditiy: 123, modificationSequenceValue: .zero, knownUids: [1 ... 3, 5 ... 7, 10 ... 1000], sequenceMatchData: .init(knownSequenceSet: [1 ... 10, 10 ... 20, 30 ... 100], knownUidSet: [100 ... 200, 300 ... 400])))])),
    ("Set Quota (one)", .setQuota(QuotaRoot("inbox"), [.init(resourceName: "size", limit: 100)])),
    ("Set Quota (many)", .setQuota(QuotaRoot("inbox"), [.init(resourceName: "size", limit: 100), .init(resourceName: "messages", limit: 100), .init(resourceName: "disk", limit: 100)])),
    ("Get Quota Root", .getQuotaRoot(.inbox)),
    ("ID (one)", .id([.init(key: "key1", value: nil)])),
    ("ID (many)", .id([.init(key: "key1", value: nil), .init(key: "key2", value: ByteBuffer(string: "value2")), .init(key: "key3", value: ByteBuffer(string: "value3"))])),
    ("Rename (params-none)", .rename(from: .inbox, to: .init("not an inbox"), params: [])),
    ("Rename (params-one)", .rename(from: .inbox, to: .init("not an inbox"), params: [.init(name: "name")])),
    ("Rename (params-many)", .rename(from: .inbox, to: .init("not an inbox"), params: [.init(name: "name1"), .init(name: "name2", value: .sequence([1 ... 2, 3 ... 4]))])),
    ("Subscribe", .subscribe(.inbox)),
    ("Unsubscribe", .unsubscribe(.inbox)),
    ("LSUB", .lsub(reference: .inbox, pattern: ByteBuffer(string: "pattern"))),
    ("Store (simple, last command)", .store(.lastCommand, [.unchangedSince(.init(modificationSequence: 124))], .add(silent: false, list: [.answered]))),
    ("Store (simple, all)", .store(.all, [.unchangedSince(.init(modificationSequence: 124))], .add(silent: false, list: [.answered]))),
    ("Store (complex, all)", .store(.all, [.unchangedSince(.init(modificationSequence: 124))], .add(silent: false, list: [.answered, .deleted, .flagged, .seen, .draft]))),
    ("Store (complex)", .store([1 ... 10, 11 ... 20, 21 ... 30, 31 ... 40], [.unchangedSince(.init(modificationSequence: 124))], .add(silent: false, list: [.answered, .deleted, .flagged, .seen, .draft]))),
    ("Move (last command)", .move(.lastCommand, .inbox)),
    ("Move (all)", .move(.lastCommand, .inbox)),
    ("Move (set)", .move([1 ... 100, 200 ... 300, 3000 ... 4000], .inbox)),
]

// MARK: Test Harness

var warning: String = ""
assert({
    print("======================================================")
    print("= YOU ARE RUNNING NIOPerformanceTester IN DEBUG MODE =")
    print("======================================================")
    warning = " <<< DEBUG MODE >>>"
    return true
}())

func measure(_ fn: () throws -> Int) rethrows -> [TimeInterval] {
    func measureOne(_ fn: () throws -> Int) rethrows -> TimeInterval {
        let start = Date()
        _ = try fn()
        let end = Date()
        return end.timeIntervalSince(start)
    }

    _ = try measureOne(fn) /* pre-heat and throw away */
    var measurements = Array(repeating: 0.0, count: 10)
    for i in 0 ..< 10 {
        measurements[i] = try measureOne(fn)
    }

    return measurements
}

let limitSet = CommandLine.arguments.dropFirst()

func measureAndPrint(desc: String, fn: () throws -> Int) rethrows {
    if limitSet.count == 0 || limitSet.contains(desc) {
        print("measuring\(warning): \(desc): ", terminator: "")
        let measurements = try measure(fn)
        print(measurements.reduce("") { $0 + "\($1), " })
    } else {
        print("skipping '\(desc)', limit set = \(limitSet)")
    }
}

// MARK: Utilities

for (description, command) in commands {
    try measureAndPrint(desc: description, benchmark: CommandTester(command: command, iterations: 10_000))
}
