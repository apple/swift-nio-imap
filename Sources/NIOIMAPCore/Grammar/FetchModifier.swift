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
public enum FetchModifier: Equatable {
    case changedSince(ChangedSinceModifier)

    case other(Parameter)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeFetchModifier(_ val: FetchModifier) -> Int {
        switch val {
        case .changedSince(let changedSince):
            return self.writeChangedSinceModifier(changedSince)
        case .other(let param):
            return self.writeParameter(param)
        }
    }
}
