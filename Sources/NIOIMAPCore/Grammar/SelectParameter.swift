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

/// Quick resynchronisation parameters for the `.select` and `.examine` commands.
/// Recommended reading: RFC 7162 § 3.2.5.
public struct QResyncParameter: Equatable {
    
    /// The last known UID validity.
    public var uidValiditiy: Int

    /// The last known modification sequence
    public var modificationSequenceValue: ModificationSequenceValue

    /// The optional set of known UIDs.
    public var knownUids: SequenceSet?

    /// An optional parenthesized list of known sequence ranges and their corresponding UIDs.
    public var sequenceMatchData: SequenceMatchData?

    ///
    /// - parameter uidValidity: The last known UID validity.
    /// - parameter modificationSequenceValue: The last known modification sequence
    /// - parameter knownUids: The optional set of known UIDs.
    /// - parameter sequenceMatchData: An optional parenthesized list of known sequence ranges and their corresponding UIDs.
    public init(uidValiditiy: Int, modificationSequenceValue: ModificationSequenceValue, knownUids: SequenceSet?, sequenceMatchData: SequenceMatchData?) {
        self.uidValiditiy = uidValiditiy
        self.modificationSequenceValue = modificationSequenceValue
        self.knownUids = knownUids
        self.sequenceMatchData = sequenceMatchData
    }
}

public enum SelectParameter: Equatable {
    case basic(Parameter)

    case qresync(QResyncParameter)

    case condstore
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSelectParameters(_ params: [SelectParameter]) -> Int {
        if params.isEmpty {
            return 0
        }

        return
            self.writeSpace() +
            self.writeArray(params) { (param, self) -> Int in
                self.writeSelectParameter(param)
            }
    }

    @discardableResult public mutating func writeSelectParameter(_ param: SelectParameter) -> Int {
        switch param {
        case .qresync(let param):
            return self.writeQResyncParameter(param: param)
        case .basic(let param):
            return self.writeParameter(param)
        case .condstore:
            return self.writeString("CONDSTORE")
        }
    }

    @discardableResult mutating func writeQResyncParameter(param: QResyncParameter) -> Int {
        self.writeString("QRESYNC (\(param.uidValiditiy) ") +
            self.writeModificationSequenceValue(param.modificationSequenceValue) +
            self.writeIfExists(param.knownUids) { (set) -> Int in
                self.writeSpace() + self.writeSequenceSet(set)
            } +
            self.writeIfExists(param.sequenceMatchData) { (data) -> Int in
                self.writeSpace() + self.writeSequenceMatchData(data)
            } +
            self.writeString(")")
    }
}
