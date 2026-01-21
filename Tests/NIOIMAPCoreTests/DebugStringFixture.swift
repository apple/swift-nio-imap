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

import Testing

struct DebugStringFixture<T>: Sendable, CustomTestStringConvertible where T: Sendable, T: CustomDebugStringConvertible {
    let sut: T
    let expected: String

    var testDescription: String {
        expected
    }
}

extension DebugStringFixture {
    func check(
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(sut.debugDescription == expected, sourceLocation: sourceLocation)
    }
}
