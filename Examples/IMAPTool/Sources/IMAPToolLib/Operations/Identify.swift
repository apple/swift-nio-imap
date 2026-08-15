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

import IMAPCommands
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIO
import NIOIMAP
import OrderedCollections

/// Sends an `ID` command and returns the server's identity information.
func identify<C: ConnectionProtocol>(
    connection: C,
    capabilities: [Capability]
) async throws -> Identity {
    guard
        capabilities.contains(.id)
    else { return Identity(capabilities: capabilities) }

    return try await connection.send(.id(clientID)) { _, responses -> Identity in
        var result = Identity(
            capabilities: capabilities
        )
        _ = try await responses.forEach { response in
            guard
                case .untagged(.id(let id)) = response
            else { return }
            result.serverID.removeAll()
            id.forEach { key, value in
                result.serverID[key] = .some(value)
            }
        }.getOK()
        return result
    }
}

private let clientID: OrderedDictionary<String, String?> = [
    "name": "imap-tool",
    "os": Identity.operatingSystemName,
    "os-version": Identity.operatingSystemVersion,
]
