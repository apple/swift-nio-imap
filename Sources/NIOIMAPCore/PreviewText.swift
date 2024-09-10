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

public struct PreviewText: Hashable, Sendable {
    fileprivate let text: String

    public init(_ text: String) {
        self.text = text
    }
}

extension String {
    public init(_ other: PreviewText) {
        self = other.text
    }
}
