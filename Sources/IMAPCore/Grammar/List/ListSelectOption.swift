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

    /// IMAPv4 `list-select-opt`
    public enum ListSelectOption: Equatable {
        case base(ListSelectBaseOption)
        case independent(ListSelectIndependentOption)
        case mod(ListSelectModOption)
    }

    public enum ListSelectionOptionsData: Equatable {
        case select([ListSelectOption], ListSelectBaseOption)
        case selectIndependent([ListSelectIndependentOption])
    }

    /// IMAPv4 `list-select-options`
    public typealias ListSelectOptions = ListSelectionOptionsData?
}
