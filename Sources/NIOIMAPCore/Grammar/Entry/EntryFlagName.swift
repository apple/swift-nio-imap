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

public struct EntryFlagName: Equatable {
    public var flag: AttributeFlag

    public init(flag: AttributeFlag) {
        self.flag = flag
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeEntryFlagName(_ name: EntryFlagName) -> Int {
        self.writeString("\"/flags/") + self.writeAttributeFlag(name.flag) + self.writeString("\"")
    }
}
