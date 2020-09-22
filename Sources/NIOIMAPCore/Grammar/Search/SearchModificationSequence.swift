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

/// RFC 7162
public struct SearchModifiedSequenceExtension: Equatable {
    public var name: EntryFlagName
    public var request: EntryKindRequest

    public init(name: EntryFlagName, request: EntryKindRequest) {
        self.name = name
        self.request = request
    }
}

/// RFC 7162
public struct SearchModificationSequence: Equatable {
    public var extensions: [SearchModifiedSequenceExtension]
    public var sequenceValue: ModificationSequenceValue

    public init(extensions: [SearchModifiedSequenceExtension], sequenceValue: ModificationSequenceValue) {
        self.extensions = extensions
        self.sequenceValue = sequenceValue
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSearchModificationSequence(_ data: SearchModificationSequence) -> Int {
        self.writeString("MODSEQ") +
            self.writeArray(data.extensions, separator: "", parenthesis: false, callback: { (element, self) -> Int in
                self.writeSearchModifiedSequenceExtension(element)
            }) +
            self.writeSpace() +
            self.writeModificationSequenceValue(data.sequenceValue)
    }

    @discardableResult mutating func writeSearchModifiedSequenceExtension(_ data: SearchModifiedSequenceExtension) -> Int {
        self.writeSpace() +
            self.writeEntryFlagName(data.name) +
            self.writeSpace() +
            self.writeEntryKindRequest(data.request)
    }
}
