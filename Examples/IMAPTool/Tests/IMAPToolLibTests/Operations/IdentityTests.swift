//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import IMAPToolLib
import Testing

@Suite
private enum IdentityTests {

    #if os(Linux)
    @Test
    static func os() {
        #expect(Identity.operatingSystemName == "Linux")
        #expect(Identity.operatingSystemVersion?.isEmpty == false)
    }

    #else
    @Test
    static func os() {
        #expect(Identity.operatingSystemName == "Darwin")
        #expect(Identity.operatingSystemVersion?.isEmpty == false)
    }

    #endif
}
