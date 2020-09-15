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

public struct SequenceMatchData: Equatable {
    public var knownSequenceSet: SequenceSet

    public var knownUidSet: SequenceSet

    public init(knownSequenceSet: SequenceSet, knownUidSet: SequenceSet) {
        self.knownSequenceSet = knownSequenceSet
        self.knownUidSet = knownUidSet
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSequenceMatchData(_ data: SequenceMatchData) -> Int {
        self.writeString("(") +
            self.writeSequenceSet(data.knownSequenceSet) +
            self.writeSpace() +
            self.writeSequenceSet(data.knownUidSet) +
            self.writeString(")")
    }
}
