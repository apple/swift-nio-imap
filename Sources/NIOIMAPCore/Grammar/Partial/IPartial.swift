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

/// See RFC 5092
public struct IPartial: Equatable {
    public var range: PartialRange

    public init(range: PartialRange) {
        self.range = range
    }
}

/// See RFC 5092
public struct IPartialOnly: Equatable {
    public var range: PartialRange

    public init(range: PartialRange) {
        self.range = range
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeIPartial(_ data: IPartial) -> Int {
        self.writeString("/;PARTIAL=") +
            self.writePartialRange(data.range)
    }

    @discardableResult mutating func writeIPartialOnly(_ data: IPartialOnly) -> Int {
        self.writeString(";PARTIAL=") +
            self.writePartialRange(data.range)
    }
}
