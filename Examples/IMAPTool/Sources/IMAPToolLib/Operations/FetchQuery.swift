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
import NIO
import NIOIMAP

/// Which messages to operate on.
enum FetchQuery: Hashable, Sendable {
    /// Fetches the specific UIDs.
    case uids(UIDSet)
    /// Fetches the last `count` messages in a mailbox.
    case last(count: Int)
    /// Fetches all messages.
    case all
}

/// Determines the best combination of `UIDSet` and `[FetchModifier]` to operate on messages in the mailbox.
///
/// Use this for `UID FETCH`, `UID SEARCH`, and similar commands. This helper checks which capabilities
/// the server supports, and picks the best approach to split the work into multiple ranges or multiple
/// `UID FETCH` commands.
///
/// It does not perform the `UID FETCH` itself, but repeatedly calls the `fetch` closure to do any fetching,
/// and the `update` closure to collect results.
func batched<C: ConnectionProtocol, InnerResult: Sendable, Result: Sendable>(
    connection: C,
    query: FetchQuery,
    mailboxMessageCount: Int,
    capabilities: [Capability],
    fetch: @Sendable @escaping (FetchBatch) async throws -> InnerResult,
    into _result: Result,
    update: @Sendable (inout Result, InnerResult) throws -> Void
) async throws -> Result {
    let batches = try await makeBatches(
        connection: connection,
        query: query,
        mailboxMessageCount: mailboxMessageCount,
        capabilities: capabilities
    )
    // Run multiple concurrently:
    let maxConcurrentTasks = 11
    return try await withThrowingTaskGroup(
        of: InnerResult.self,
        returning: Result.self
    ) { group in
        var batchIterator = batches.makeIterator()

        // A helper that does the actual work:
        func addTask() {
            guard let batch = batchIterator.next() else { return }
            group.addTask {
                try await fetch(batch)
            }
        }

        // Start the first set of tasks:
        for _ in 0..<maxConcurrentTasks {
            addTask()
        }

        var result = _result
        while let innerResult = try await group.next() {
            try update(&result, innerResult)
            // Start the next task:
            addTask()
        }
        return result
    }
}

// MARK: -

/// A helper that provides flexible `FetchQuery` parsing as an `@OptionGroup` for `ArgumentParser`.
struct FetchQueryGroup: ParsableArguments, Sendable {
    init() {}

    @Option(
        help: """
            The number of messages to get.
            """
    )
    /// The number of messages to fetch, or `nil` to use the default.
    var count: Int?

    @ArgumentParser.Flag(
        help: "Get all messages."
    )
    var all: Bool = false

    mutating func validate() throws {
        // Validation logic lives in `makeFetchQuery()`; building and discarding
        // the result is the simplest way to surface any thrown error here.
        _ = try self.makeFetchQuery()
    }

    /// Creates a `FetchQuery` from the parsed arguments.
    func makeFetchQuery() throws -> FetchQuery {
        switch (count, all) {
        case (nil, false):
            // Default to “last 20”:
            return .last(count: 20)
        case (let c?, false):
            return .last(count: c)
        case (nil, true):
            return .all
        case (.some, true):
            throw ValidationError("Must not specify both --count and --all.")
        }
    }
}
