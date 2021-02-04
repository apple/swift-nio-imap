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

/// Used when performing a search to only include messages modified since a particular moment.
public struct SearchModificationSequence: Hashable {
    /// Extensions defined to catch data sent as part of any future extensions.
    public var extensions: KeyValues<EntryFlagName, EntryKindRequest>

    /// The minimum `ModificationSequenceValue` that any messages returned as part of the search must have.
    public var sequenceValue: ModificationSequenceValue

    /// Creates a new `SearchModificationSequence`.
    /// - parameter extensions: Extensions defined to catch data sent as part of any future extensions.
    /// - parameter sequenceValue: The minimum `ModificationSequenceValue` that any messages returned as part of the search must have.
    public init(extensions: KeyValues<EntryFlagName, EntryKindRequest>, sequenceValue: ModificationSequenceValue) {
        self.extensions = extensions
        self.sequenceValue = sequenceValue
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSearchModificationSequence(_ data: SearchModificationSequence) -> Int {
        self.writeString("MODSEQ") +
            self.writeKeyValues(data.extensions, separator: "", parenthesis: false) { (element, self) -> Int in
                self.writeSpace() +
                self.writeEntryFlagName(element.key) +
                    self.writeSpace() +
                self.writeEntryKindRequest(element.value)
            } +
            self.writeSpace() +
            self.writeModificationSequenceValue(data.sequenceValue)
    }
}
