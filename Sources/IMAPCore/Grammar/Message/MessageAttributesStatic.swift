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



extension IMAPCore {

    /// Extracted from IMAPv4 `msg-att-static`
    public enum RFC822Reduced: String, Equatable {
        case header
        case text
    }

    /// IMAPv4 `msg-att-static`
    public enum MessageAttributesStatic: Equatable {
        case envelope(Envelope)
        case internalDate(Date.DateTime)
        case rfc822(RFC822Reduced?, IMAPCore.NString)
        case rfc822Size(Int)
        case body(Body, structure: Bool)
        case bodySection(SectionSpec?, Int?, NString)
        case bodySectionText(Int?, Int) // used when streaming the body, send the literal header
        case uid(Int)
        case binaryString(section: [Int], string: NString)
        case binaryLiteral(section: [Int], size: Int)
        case binarySize(section: [Int], number: Int)
    }

}
