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
    public var knownUids: LastCommandSet<SequenceRangeSet>?

    /// An optional parenthesized list of known sequence ranges and their corresponding UIDs.
    public var sequenceMatchData: SequenceMatchData?

    /// Creates a new `QResyncParameter`.
    /// - parameter uidValidity: The last known UID validity.
    /// - parameter modificationSequenceValue: The last known modification sequence
    /// - parameter knownUids: The optional set of known UIDs.
    /// - parameter sequenceMatchData: An optional parenthesized list of known sequence ranges and their corresponding UIDs.
    public init(uidValiditiy: Int, modificationSequenceValue: ModificationSequenceValue, knownUids: LastCommandSet<SequenceRangeSet>?, sequenceMatchData: SequenceMatchData?) {
        self.uidValiditiy = uidValiditiy
        self.modificationSequenceValue = modificationSequenceValue
        self.knownUids = knownUids
        self.sequenceMatchData = sequenceMatchData
    }
}

/// Used to specify the type of `.select` command that should be execuuted.
public enum SelectParameter: Equatable {
    /// Perform a basic `.select` command without Condition Store or Quick Resynchronisation.
    case basic(KeyValue<String, ParameterValue?>)

    /// Perform a `.select` command with Quick Resynchronisation. Note that a server must explicitly advertise this capability. See RFC 7162.
    case qresync(QResyncParameter)

    /// Perform a `.select` command with Conditional Store. Note that a server must explicitly advertise this capability. See RFC 7162.
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

    @discardableResult mutating func writeSelectParameter(_ param: SelectParameter) -> Int {
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
                self.writeSpace() + self.writeLastCommandSet(set)
            } +
            self.writeIfExists(param.sequenceMatchData) { (data) -> Int in
                self.writeSpace() + self.writeSequenceMatchData(data)
            } +
            self.writeString(")")
    }
}
