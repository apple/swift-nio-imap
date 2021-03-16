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

/// A wrapper around `AttributeFlag`, used in `SearchModificationSequence`
public struct EntryFlagName: Hashable {
    /// An `AttributeFlag`
    public var flag: AttributeFlag

    /// Creates a new `EntryFlagName` to wrap an `AttributeFlag`
    public init(flag: AttributeFlag) {
        self.flag = flag
    }
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeEntryFlagName(_ name: EntryFlagName) -> Int {
        self._writeString("\"/flags/") + self.writeAttributeFlag(name.flag) + self._writeString("\"")
    }
}
