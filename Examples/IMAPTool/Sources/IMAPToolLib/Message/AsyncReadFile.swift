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

import Dispatch
import System
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Synchronization

private let queue = DispatchSerialQueue(label: "async-file-read")

private let tokenBucket = TokenBucket(tokens: 20)

extension Data {
    /// Reads the contents of the file at the given path asynchronously.
    init(
        asyncContentsOf filePath: FilePath,
        length: Int = .max
    ) async throws {
        let other = try await read(
            filePath: filePath,
            length: length
        )
        self.init(other)
    }
}

extension DispatchData {
    init(
        asyncContentsOf filePath: FilePath,
        length: Int = .max
    ) async throws {
        self = try await read(
            filePath: filePath,
            length: length
        )
    }
}

private func read(
    filePath: FilePath,
    length: Int
) async throws -> DispatchData {
    // Use the TokenBucket to limit concurrency.
    try await tokenBucket.withToken {
        try await readWithToken(
            filePath: filePath,
            length: length
        )
    }
}

private func readWithToken(
    filePath: FilePath,
    length: Int
) async throws -> DispatchData {
    let io = try await withCheckedThrowingContinuation { continuation in
        let syncContinuation: Mutex<CheckedContinuation<IO, any Error>?> = Mutex(continuation)
        func getContinuation() -> CheckedContinuation<IO, any Error>? {
            syncContinuation.withLock {
                let c = $0
                $0 = nil
                return c
            }
        }

        do {
            let io = try IO(
                filePath: filePath,
                queue: queue,
                cleanupHandler: { error in
                    if let e = POSIXErrorCode(rawValue: error) {
                        getContinuation()?.resume(throwing: POSIXError(e))
                    }
                }
            )
            getContinuation()?.resume(returning: io)
        } catch {
            getContinuation()?.resume(throwing: error)
        }
    }
    return try await io.read(
        length: length
    )
}

private final class IO {
    let underlying: DispatchIO
    let queue: DispatchQueue

    init(
        underlying: DispatchIO,
        queue: DispatchQueue
    ) {
        self.underlying = underlying
        self.queue = queue
    }

    convenience init(
        filePath: FilePath,
        queue: DispatchQueue,
        cleanupHandler: @escaping (Int32) -> Void
    ) throws {
        let io = filePath.withPlatformString { platformPath in
            DispatchIO(
                type: .stream,
                path: platformPath,
                oflag: O_RDONLY,
                mode: 0,
                queue: queue,
                cleanupHandler: cleanupHandler
            )
        }
        guard let io else {
            struct UnableToOpen: Swift.Error {}

            throw UnableToOpen()
        }
        self.init(
            underlying: io,
            queue: queue
        )
    }

    deinit {
        underlying.close()
    }

    func read(
        length: Int = .max
    ) async throws -> DispatchData {
        try await withCheckedThrowingContinuation { continuation in
            var result: Result<DispatchData, any Error> = .success(.empty)
            underlying.read(offset: 0, length: length, queue: queue) { done, data, error in
                switch (result, data, error) {
                case (.failure, _, _):
                    break
                case (.success(var all), let new?, 0):
                    all.append(new)
                    result = .success(all)
                case (.success, nil, 0):
                    break
                case (.success, _, let e):
                    result = .failure(POSIXError(POSIXErrorCode(rawValue: e) ?? .EIO))
                }
                if done {
                    continuation.resume(with: result)
                }
            }
        }
    }
}
