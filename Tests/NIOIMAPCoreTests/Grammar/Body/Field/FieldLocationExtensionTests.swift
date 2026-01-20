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

import NIO
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import Testing

@Suite("BodyStructure.LocationAndExtensions")
struct FieldLocationExtensionTests {
    @Test(arguments: [
        EncodeFixture.locationAndExtensions(.init(location: "loc", extensions: []), " \"loc\""),
        EncodeFixture.locationAndExtensions(.init(location: "loc", extensions: [.number(1)]), " \"loc\" (1)"),
        EncodeFixture.locationAndExtensions(.init(location: "loc", extensions: [.number(1), .number(2)]), " \"loc\" (1 2)"),
    ])
    func encoding(_ fixture: EncodeFixture<BodyStructure.LocationAndExtensions>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<BodyStructure.LocationAndExtensions> {
    fileprivate static func locationAndExtensions(_ input: T, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            expectedString: expectedString,
            encoder: { $0.writeBodyLocationAndExtensions($1) }
        )
    }
}
