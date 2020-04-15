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

    /// IMAPv4 `option-val-comp`
    public enum OptionValueComp: Equatable {
        case string(String)
        case array([OptionValueComp])
    }

}

// MARK: - Conveniences
extension IMAPCore.OptionValueComp: ExpressibleByArrayLiteral {

    public typealias ArrayLiteralElement = Self

    public init(arrayLiteral elements: IMAPCore.OptionValueComp...) {
        let array = Array(elements)
        self = .array(array)
    }

}
