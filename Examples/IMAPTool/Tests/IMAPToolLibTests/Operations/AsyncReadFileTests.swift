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

import Foundation
import NIOCore
@testable import NIOIMAP
import SystemPackage
import Testing
@testable import IMAPToolLib

@Suite("Async Read File")
private enum AsyncReadFileTests {
    static func createFile(
        dir: FilePath,
        name: String,
        content: String
    ) throws -> FilePath {
        let path = dir.appending(name)
        try Data(content.utf8).write(to: URL(path))
        return path
    }

    @Test
    static func filePathComponent() async throws {
        try await withTemporaryDirectory { dir in
            let count = 10

            let paths = try (1...count).map { index -> (Int, FilePath) in
                (
                    index,
                    try createFile(
                        dir: dir,
                        name: "\(index)",
                        content: "\(index)"
                    )
                )
            }

            let all = try await withThrowingTaskGroup { group in
                for element in paths {
                    let index = element.0
                    let path = element.1
                    group.addTask {
                        let buffer = try await ByteBuffer(asyncContentsOf: path)
                        let s = String(buffer: buffer)
                        return (index, s)
                    }
                }

                var result: [(Int, String)] = []
                for try await element in group {
                    result.append(element)
                }
                result.sort(by: { $0.0 < $1.0 })
                return result.map { $0.1 }
            }

            #expect(all == (1...count).map { "\($0)" })
        }
    }
}
