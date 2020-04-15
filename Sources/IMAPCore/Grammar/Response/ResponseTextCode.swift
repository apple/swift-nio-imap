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

    /// IMAPv4 `resp-text-code`
    public enum ResponseTextCode: Equatable {
        case alert
        case badCharset([String])
        case capability([Capability])
        case parse
        case permanentFlags([PermanentFlag])
        case readOnly
        case readWrite
        case tryCreate
        case uidNext(Int)
        case uidValidity(Int)
        case unseen(Int)
        case namespace(NamespaceResponse)
        case other(String, String?)
    }

}
