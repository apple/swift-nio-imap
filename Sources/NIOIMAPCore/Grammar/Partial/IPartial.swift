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

/// Used to append a `PartialRange` to the end of a *UID FETCH BODY.PEEK*.
public struct IPartial: Equatable {
    /// The `PartialRange` to append.
    public var range: PartialRange

    /// Creates a new `IPartial`.
    /// - parameter range: The `PartialRange` to append.
    public init(range: PartialRange) {
        self.range = range
    }
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeIPartial(_ data: IPartial) -> Int {
        self._writeString("/;PARTIAL=") +
            self.writePartialRange(data.range)
    }

    @discardableResult mutating func writeIPartialOnly(_ data: IPartial) -> Int {
        self._writeString(";PARTIAL=") +
            self.writePartialRange(data.range)
    }
}
