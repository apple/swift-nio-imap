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

@Suite("ParameterValue")
struct TaggedExtensionValueTests {
    @Test(arguments: [
        EncodeFixture.parameterValue(.sequence(.set([123])), "123"),
        EncodeFixture.parameterValue(.sequence(.set([123, 124, 125])), "123:125"),
        EncodeFixture.parameterValue(.sequence(.set([316_999, 810_120, 880_169])), "316999,810120,880169"),
        EncodeFixture.parameterValue(.comp(["testComp"]), "((\"testComp\"))"),
    ])
    func encode(_ fixture: EncodeFixture<ParameterValue>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<ParameterValue> {
    fileprivate static func parameterValue(_ input: ParameterValue, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeParameterValue($1) }
        )
    }
}
