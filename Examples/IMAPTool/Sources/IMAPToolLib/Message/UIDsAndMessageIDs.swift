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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIOIMAP

struct UIDsAndMessageIDs: Equatable, Sendable {
    var uids: UIDSet
    var messageIDs: Set<MessageID>

    var isEmpty: Bool {
        uids.isEmpty && messageIDs.isEmpty
    }
}

extension UIDsAndMessageIDs {
    init(
        filePath: String?,
        uids: [UID],
        messageIDs: [MessageID]
    ) throws {
        if let filePath {
            self = try Self.parse(filePath: filePath)
        } else {
            self.init(uids: [], messageIDs: [])
        }
        self.uids.formUnion(UIDSet(uids))
        self.messageIDs.formUnion(messageIDs)
    }
}

extension UIDsAndMessageIDs {
    static func parse(
        filePath: String
    ) throws -> UIDsAndMessageIDs {
        let json = try Data(contentsOf: URL(filePath: filePath, directoryHint: .notDirectory))
        return try Self.parse(input: json)
    }

    static func parse(
        input: Data
    ) throws -> UIDsAndMessageIDs {
        var uids = UIDSet()
        var ids = Set<MessageID>()
        for m in try parseMessages(input: input) {
            switch m {
            case .uid(let uid): uids.insert(uid)
            case .messageID(let id): ids.insert(id)
            }
        }
        return UIDsAndMessageIDs(
            uids: uids,
            messageIDs: ids
        )
    }

    enum MessageInfo {
        case uid(UID)
        case messageID(MessageID)
    }

    static func parseMessages(input: Data) throws -> [MessageInfo] {
        struct Messages: Decodable {
            var messages: [Message]

            struct Message: Decodable {
                var uid: UInt32?
                var id: String?
            }
        }

        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true
        let m = try decoder.decode(Messages.self, from: input)
        return m.messages.compactMap { raw -> MessageInfo? in
            if let u = raw.uid, let uid = UID(exactly: u) {
                return .uid(uid)
            } else if let id = raw.id {
                guard
                    id.first == "<",
                    id.last == ">"
                else { return nil }
                return .messageID(MessageID(id))
            } else {
                return nil
            }
        }
    }
}

func findMessageIDs<C: ConnectionProtocol>(
    connection: C,
    selectInfo: SelectInfo,
    capabilities: [Capability],
    ids: UIDsAndMessageIDs
) async throws -> UIDSet {
    guard
        let key = SearchKey.messageID(ids.messageIDs)
    else { return ids.uids }

    let new = try await search(
        connection: connection,
        capabilities: capabilities,
        key: key
    )
    return ids.uids.union(new)
}
