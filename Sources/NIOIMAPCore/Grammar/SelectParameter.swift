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

public struct QResyncParameter: Equatable {
    public var uidValiditiy: Int

    public var modificationSequenceValue: ModificationSequenceValue

    public var knownUids: SequenceSet?

    public var sequenceMatchData: SequenceMatchData?

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
            self.writeIfExists(param.knownUids, callback: { (set) -> Int in
                self.writeSpace() + self.writeSequenceSet(set)
            }) +
            self.writeIfExists(param.sequenceMatchData, callback: { (data) -> Int in
                self.writeSpace() + self.writeSequenceMatchData(data)
            }) +
            self.writeString(")")
    }
}
