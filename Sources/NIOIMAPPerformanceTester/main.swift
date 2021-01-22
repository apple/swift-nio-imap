//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftNIO project authors
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
    ("parse_check", .check),
    ("parse_starttls", .starttls),
    ("parse_idlestart", .idleStart),
    ("parse_logout", .logout),
    ("parse_login", .login(username: "test", password: "test")),
    ("parse_capability", .capability),
    ("parse_close", .close),
    ("parse_namespace", .namespace),
    ("parse_noop", .noop),
    ("parse_unselect", .unselect),
    ("parse_create_no_atts", .create(.init("My Test Mailbox"), [])),
    ("parse_create_one_att", .create(.init("My Test Mailbox"), [.attributes([.flagged])])),
    ("parse_create_many_att", .create(.init("My Test Mailbox"), [.attributes([.flagged, .junk, .archive, .sent, .trash])])),
    ("parse_delete", .delete(.inbox)),
    ("parse_enable_lots", .enable([.acl, .binary, .catenate, .condStore, .children, .esearch, .esort, .namespace])),
    ("parse_enable_one", .enable([.namespace])),
    ("parse_copy_last_command", .copy(.lastCommand, .inbox)),
    ("parse_copy_all", .copy(.all, .inbox)),
    ("parse_copy_set_one", .copy([1 ... 2, 4 ... 5, 10 ... 20], .inbox)),
    ("parse_copy_set_many", .copy([1 ... 100], .inbox)),
    ("parse_fetch_last_command_lots", .fetch(.lastCommand, [.envelope, .flags, .internalDate, .gmailThreadID, .modificationSequence], [])),
    ("parse_fetch_all_lots", .fetch(.all, [.envelope, .flags, .internalDate, .gmailThreadID, .modificationSequence], [])),
    ("parse_fetch_set_one_lots", .fetch([1 ... 10], [.envelope, .flags, .internalDate, .gmailThreadID, .modificationSequence], [])),
    ("parse_fetch_set_many_lots", .fetch([1 ... 2, 4 ... 7, 10 ... 100], [.envelope, .flags, .internalDate, .gmailThreadID, .modificationSequence], [])),
    ("parse_auth_plain_nil", .authenticate(method: "PLAIN", initialClientResponse: nil)),
    ("parse_auth_plain_empty", .authenticate(method: "PLAIN", initialClientResponse: .empty)),
    ("parse_auth_plain_initial data", .authenticate(method: "PLAIN", initialClientResponse: .data(ByteBuffer(string: "dGhpcyBpcyB0ZXN0IGJhc2U2NA==")))),
    ("parse_esearch_simple_all", .esearch(.init(key: .all))),
    ("parse_esearch_simple_recursive_date", .esearch(.init(key: .and([.not(.answered), .not(.before(NIOIMAP.Date(year: 2000, month: 12, day: 12)!))])))),
    ("parse_esearch_complex", .esearch(.init(key: .and([.younger(123), .or(.keyword(.colorBit0), .keyword(.colorBit1))]), charset: "UTF-8", returnOptions: [.min, .max, .count], sourceOptions: ESearchSourceOptions(sourceMailbox: [.inboxes])!))),
    ("parse_examine_no_params", .examine(.inbox, [])),
    ("parse_examine_1_param", .examine(.inbox, [.init(name: "param")])),
    ("parse_examine_lots_param", .examine(.inbox, [.init(name: "param1"), .init(name: "param2"), .init(name: "param3", value: .sequence(.range([1 ... 5, 10 ... 100]))), .init(name: "param4", value: .comp(["str1"]))])),
    ("parse_expunge", .expunge),
    ("parse_genurlauth_one", .genURLAuth([.init(urlRump: ByteBuffer(string: "test"), mechanism: .internal)])),
    ("parse_genurlauth_many", .genURLAuth([.init(urlRump: ByteBuffer(string: "test1"), mechanism: .internal), .init(urlRump: ByteBuffer(string: "test2"), mechanism: .internal), .init(urlRump: ByteBuffer(string: "test3"), mechanism: .internal)])),
    ("parse_getmetadata_complex", .getMetadata(options: [.maxSize(123), .scope(.infinity)], mailbox: .inbox, entries: [ByteBuffer(string: "test1"), ByteBuffer(string: "test2")])),
    ("parse_getquota", .getQuota(.init("inbox"))),
    ("parse_select_params_none", .select(.inbox, [])),
    ("parse_select_params_one", .select(.inbox, [.condstore])),
    ("parse_select_params_complex", .select(.inbox, [.condstore, .basic(.init(name: "param1")), .qresync(.init(uidValiditiy: 123, modificationSequenceValue: .zero, knownUids: [1 ... 3, 5 ... 7, 10 ... 1000], sequenceMatchData: .init(knownSequenceSet: [1 ... 10, 10 ... 20, 30 ... 100], knownUidSet: [100 ... 200, 300 ... 400])))])),
    ("parse_setquota_one", .setQuota(QuotaRoot("inbox"), [.init(resourceName: "size", limit: 100)])),
    ("parse_setquota_many", .setQuota(QuotaRoot("inbox"), [.init(resourceName: "size", limit: 100), .init(resourceName: "messages", limit: 100), .init(resourceName: "disk", limit: 100)])),
    ("parse_getquotaRoot", .getQuotaRoot(.inbox)),
    ("parse_id_one", .id([.init(key: "key1", value: nil)])),
    ("parse_id_many", .id([.init(key: "key1", value: nil), .init(key: "key2", value: ByteBuffer(string: "value2")), .init(key: "key3", value: ByteBuffer(string: "value3"))])),
    ("parse_rename_params_none", .rename(from: .inbox, to: .init("not an inbox"), params: [])),
    ("parse_rename_params_one", .rename(from: .inbox, to: .init("not an inbox"), params: [.init(name: "name")])),
    ("parse_rename_params_many", .rename(from: .inbox, to: .init("not an inbox"), params: [.init(name: "name1"), .init(name: "name2", value: .sequence([1 ... 2, 3 ... 4]))])),
    ("parse_subscribe", .subscribe(.inbox)),
    ("parse_unsubscribe", .unsubscribe(.inbox)),
    ("parse_lsub", .lsub(reference: .inbox, pattern: ByteBuffer(string: "pattern"))),
    ("parse_store_simple_last_command", .store(.lastCommand, [.unchangedSince(.init(modificationSequence: 124))], .add(silent: false, list: [.answered]))),
    ("parse_store_simple_all", .store(.all, [.unchangedSince(.init(modificationSequence: 124))], .add(silent: false, list: [.answered]))),
    ("parse_store_complex_all", .store(.all, [.unchangedSince(.init(modificationSequence: 124))], .add(silent: false, list: [.answered, .deleted, .flagged, .seen, .draft]))),
    ("parse_store_complex", .store([1 ... 10, 11 ... 20, 21 ... 30, 31 ... 40], [.unchangedSince(.init(modificationSequence: 124))], .add(silent: false, list: [.answered, .deleted, .flagged, .seen, .draft]))),
    ("parse_move_last command", .move(.lastCommand, .inbox)),
    ("parse_move_all", .move(.lastCommand, .inbox)),
    ("parse_move_set", .move([1 ... 100, 200 ... 300, 3000 ... 4000], .inbox)),
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
