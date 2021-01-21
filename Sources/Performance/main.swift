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
]

let startDate = Date()

for (name, command) in commands {
    let tester = CommandTester(iterations: 10_000, command: command)
    tester.run()
    print("Completed \(name)")
}

let endDate = Date()
let timeTaken = endDate.timeIntervalSince(startDate)
print(String(format: "%.2f", timeTaken))
