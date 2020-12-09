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

/// Implemented as a catch-all to support components defined in future extensions.
public struct SearchModificationSequenceExtension: Hashable {
    
    /// The name of the metadata item.
    public var name: EntryFlagName
    
    /// The type of metadata item.
    public var request: EntryKindRequest

    /// Creates a new `SearchModificationSequenceExtension`.
    /// - parameter name: The name of the metadata item.
    /// - parameter request: The type of metadata item.
    public init(name: EntryFlagName, request: EntryKindRequest) {
        self.name = name
        self.request = request
    }
}

/// Used when performing a search to only include messages modified since a particular moment.
public struct SearchModificationSequence: Hashable {
    
    /// Extensions defined to catch data sent as part of any future extensions.
    public var extensions: [SearchModificationSequenceExtension]
    
    /// The minimum `ModificationSequenceValue` that any messages returned as part of the search must have.
    public var sequenceValue: ModificationSequenceValue

    /// Creates a new `SearchModificationSequence`.
    /// - parameter extensions: Extensions defined to catch data sent as part of any future extensions.
    /// - parameter sequenceValue: The minimum `ModificationSequenceValue` that any messages returned as part of the search must have.
    public init(extensions: [SearchModificationSequenceExtension], sequenceValue: ModificationSequenceValue) {
        self.extensions = extensions
        self.sequenceValue = sequenceValue
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSearchModificationSequence(_ data: SearchModificationSequence) -> Int {
        self.writeString("MODSEQ") +
            self.writeArray(data.extensions, separator: "", parenthesis: false) { (element, self) -> Int in
                self.writeSearchModificationSequenceExtension(element)
            } +
            self.writeSpace() +
            self.writeModificationSequenceValue(data.sequenceValue)
    }

    @discardableResult mutating func writeSearchModificationSequenceExtension(_ data: SearchModificationSequenceExtension) -> Int {
        self.writeSpace() +
            self.writeEntryFlagName(data.name) +
            self.writeSpace() +
            self.writeEntryKindRequest(data.request)
    }
}
