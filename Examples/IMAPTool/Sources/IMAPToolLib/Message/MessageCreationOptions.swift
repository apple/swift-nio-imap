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
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Options that control message generation for testing and seeding.
struct MessageCreationOptions: ParsableArguments {
    init() {}

    /// The number of messages to create or use.
    @Option(help: "Number of messages to create or use.")
    var messageCount: Int = 43

    /// The seed for deterministic message generation.
    @Option(help: "A seed for message generation.")
    var messageSeed: SeededRandomNumberGenerator.Seed = .default
}
