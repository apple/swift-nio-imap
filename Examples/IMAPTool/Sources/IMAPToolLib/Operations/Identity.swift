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
#if canImport(Darwin)
import Darwin
#else
import Glibc
import SystemPackage
#endif

/// The identity of a server, including its `ID` response and capabilities.
struct Identity: Hashable, Sendable {
    /// The key-value pairs from the server’s `ID` response.
    var serverID: [String: String?]
    /// The capabilities advertised by the server.
    var capabilities: [Capability]

    /// Creates a new identity with the given server ID and capabilities.
    init(
        serverID: [String: String?] = [:],
        capabilities: [Capability]
    ) {
        self.serverID = serverID
        self.capabilities = capabilities
    }
}

#if canImport(Darwin)

extension Identity {
    static var operatingSystemName: String? {
        systemInformation(name: "kern.ostype")
    }

    static var operatingSystemVersion: String? {
        systemInformation(name: "kern.osproductversion")
    }
}

/// Retrieves system information by name. Wraps `sysctlbyname(3)`.
private func systemInformation(name: String) -> String? {
    name.withCString { _name -> String? in
        withUnsafeTemporaryAllocation(of: UInt8.self, capacity: 200) { buffer -> String? in
            var count = buffer.count
            guard sysctlbyname(_name, buffer.baseAddress, &count, nil, 0) == 0
            else { return nil }
            guard 0 < count else { return nil }
            // sysctlbyname includes a trailing NUL in the byte count.
            return String(decoding: buffer.prefix(count - 1), as: UTF8.self)
        }
    }
}

#else

extension Identity {
    static var operatingSystemName: String? {
        systemInformation(name: "ostype")
    }

    static var operatingSystemVersion: String? {
        systemInformation(name: "osrelease")
    }
}

/// Retrieves system information by name. Reads from `/proc/sys/kernel/`.
private func systemInformation(name: String) -> String? {
    let url = URL(fileURLWithPath: "/proc/sys/kernel/\(name)")
    guard
        let data = try? Data(contentsOf: url),
        let text = String(data: data, encoding: .utf8)
    else { return nil }
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
}

#endif

extension Identity: Encodable {
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(self.serverID, forKey: .id)
        try c.encode(self.capabilities.map { String($0) }, forKey: .capabilities)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case capabilities
    }
}
