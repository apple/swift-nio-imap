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

// Runs a series of interactions between a client and server, aiming to replicate what might happen in the real world.

import Foundation
import NIOIMAP

let commands: [(String, Command)] = [
    ("Check",       .check),
    ("Start TLS",   .starttls),
    ("Idle start",  .idleStart),
    ("Logout",      .logout),
    ("Login",       .login(username: "test", password: "test")),
    ("Capability",  .capability),
    ("Close",       .close),
    ("Namespace",   .namespace),
    ("Noop",        .noop),
    ("Unselect",    .unselect),
    ("Create", .create(.init("My Test Mailbox"), [.attributes([.flagged, .junk])])),
    ("Delete", .delete(.inbox)),
    ("Enable (lots)", .enable([.acl, .binary, .catenate, .condStore, .children, .esearch, .esort, .namespace])),
    ("Enable (one)", .enable([.namespace])),
    ("Copy (last command)", .copy(.lastCommand, .inbox)),
    ("Copy (all)", .copy(.all, .inbox)),
    ("Copy (set-one)", .copy([1...2, 4...5, 10...20], .inbox)),
    ("Copy (set-many)", .copy([1...100], .inbox)),
    ("Fetch (last command, lots)", .fetch(.lastCommand, [.envelope, .flags, .internalDate, .gmailThreadID, .modificationSequence], [])),
    ("Fetch (all, lots)", .fetch(.all, [.envelope, .flags, .internalDate, .gmailThreadID, .modificationSequence], [])),
    ("Fetch (set-one, lots)", .fetch([1...10], [.envelope, .flags, .internalDate, .gmailThreadID, .modificationSequence], [])),
    ("Fetch (set-many, lots)", .fetch([1...2, 4...7, 10...100], [.envelope, .flags, .internalDate, .gmailThreadID, .modificationSequence], [])),
    ("Copy (set-one)", .copy([1 ... 2, 4 ... 5, 10 ... 20], .inbox)),
    ("Copy (set-many)", .copy([1 ... 100], .inbox)),
    ("Fetch (last command, lots)", .fetch(.lastCommand, [.envelope, .flags, .internalDate, .gmailThreadID, .modificationSequence], [])),
    ("Fetch (all, lots)", .fetch(.all, [.envelope, .flags, .internalDate, .gmailThreadID, .modificationSequence], [])),
    ("Fetch (set-one, lots)", .fetch([1 ... 10], [.envelope, .flags, .internalDate, .gmailThreadID, .modificationSequence], [])),
    ("Fetch (set-many, lots)", .fetch([1 ... 2, 4 ... 7, 10 ... 100], [.envelope, .flags, .internalDate, .gmailThreadID, .modificationSequence], [])),
]

print("Testing \(commands.count) commands")
print("---------------------------------------------")

let startDate = Date()

for (name, command) in commands {
    let commandStart = Date()
    let tester = CommandTester(iterations: 10_000, command: command)
    tester.run()
    let commandEnd = Date()
    print(String(format: "(%.2fs) Completed \(name)", commandEnd.timeIntervalSince(commandStart)))
}

let endDate = Date()
let timeTaken = endDate.timeIntervalSince(startDate)
print("---------------------------------------------")
print(String(format: "Total time taken: %.2fs", timeTaken))
