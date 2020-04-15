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

    /// IMAPv4 `status-att-val`
    public enum StatusAttributeValue: Equatable {
        case messages(Int)
        case uidNext(Int)
        case uidValidity(Int)
        case unseen(Int)
        case deleted(Int)
        case size(Int)
        case modSequence(ModifierSequenceValue)
    }

}
