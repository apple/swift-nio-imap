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
@testable import IMAPCommands
import Foundation
@testable import IMAPToolLib
import NIO
import NIOIMAP
import Testing
#if canImport(System)
import System
#else
import SystemPackage
#endif

func firstLineOfErrorMessage(for error: any Error) -> Substring {
    RootCommand
        .fullMessage(for: error)
        .prefix(while: { !$0.isNewline })
}

struct ConnectionHelper {
    var sent: [CommandStreamPart] = []
    mutating func send(_ c: CommandStreamPart) {
        self.sent.append(c)
    }
}

extension IMAPCredential {
    static var testUsername: IMAPCredential {
        .username("foo", password: "bar")
    }
}

extension CommandStreamPart {
    static func continuationResponse(_ data: Data) -> CommandStreamPart {
        .continuationResponse(ByteBuffer(data))
    }
}

extension NIOIMAP.MailboxName: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        // Test code only:
        self = try! MailboxPath.makeRootMailbox(displayName: value).name
    }
}

extension NIOIMAP.MailboxPath: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        try! self.init(name: MailboxName(stringLiteral: value), pathSeparator: ".")
    }
}

extension IMAPConnection.Tag: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = IMAPConnection.Tag(value)!
    }
}

extension CommandStreamPart {
    func getCommand() throws -> TaggedCommand {
        guard case .tagged(let tagged) = self else {
            struct NotACommand: Swift.Error {}
            throw NotACommand()
        }
        return tagged
    }
}

func withTemporaryDirectory<R>(
    closure: (FilePath) async throws -> R
) async throws -> R {
    let a = FilePath(NSTemporaryDirectory()).appending("DownloadDirectoryTests-XXXXXXXXXXXXXXXX")
    let p = a.withPlatformString { pointer -> FilePath? in
        let count = strlen(pointer)
        let immutable = UnsafeBufferPointer(start: pointer, count: count)
        return withUnsafeTemporaryAllocation(
            of: CInterop.PlatformChar.self,
            capacity: count + 1
        ) { buffer -> FilePath? in
            let (_, index) = buffer.initialize(from: immutable)
            buffer[index] = 0
            guard
                mkdtemp(buffer.baseAddress) != nil
            else { return nil }
            return buffer.baseAddress.map { FilePath(platformString: $0) }
        }
    }
    guard let p else { throw FailedToCreateTemporaryDirectory() }
    let r = try await closure(p)
    deleteDirectory(p)
    return r
}

private struct FailedToCreateTemporaryDirectory: Swift.Error {}

private func deleteDirectory(_ root: FilePath) {
    root.withPlatformString { platformRoot in
        _ = nftw(
            platformRoot,
            { path, sb, type, _ in
                switch type {
                case FTW_D:
                    break
                case FTW_DP, FTW_DNR:
                    _ = rmdir(path)
                case FTW_F, FTW_NS, FTW_SL, FTW_SLN:
                    _ = unlink(path)
                default:
                    break
                }
                return 0
            },
            64,
            FTW_DEPTH | FTW_PHYS
        )
    }
}
