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

import NIOIMAP

/// A rough estimate of the number of bytes a write sends to the network.
struct WriteWeight: Hashable, Sendable, Comparable {
    static func < (lhs: WriteWeight, rhs: WriteWeight) -> Bool {
        lhs.underlying < rhs.underlying
    }

    static func > (lhs: WriteWeight, rhs: WriteWeight) -> Bool {
        lhs.underlying > rhs.underlying
    }

    static func + (lhs: WriteWeight, rhs: WriteWeight) -> WriteWeight {
        Self(lhs.underlying + rhs.underlying)
    }

    static func += (lhs: inout WriteWeight, rhs: WriteWeight) {
        lhs.underlying += rhs.underlying
    }

    init(_ underlying: Int) {
        self.underlying = underlying
    }

    private var underlying: Int
}

extension IMAPClientHandler.OutboundIn {
    var writeWeight: WriteWeight {
        switch self {
        case .part(let part):
            switch part {
            case .idleDone,
                .tagged,
                .append(.start),
                .append(.beginMessage),
                .append(.endMessage),
                .append(.beginCatenate),
                .append(.catenateData(.begin)),
                .append(.catenateData(.end)),
                .append(.endCatenate),
                .append(.finish):
                WriteWeight(100)
            case .append(.messageBytes(let buffer)),
                .append(.catenateData(.bytes(let buffer))),
                .append(.catenateURL(let buffer)):
                WriteWeight(100 + buffer.readableBytes)
            case .continuationResponse(let b):
                WriteWeight(b.readableBytes * 2)
            }
        case .setEncodingOptions:
            WriteWeight(0)
        }
    }
}
