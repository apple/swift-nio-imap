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

extension NIOIMAP {

    /// IMAPv4 `search-modifier-name`
    public typealias SearchModifierName = TaggedExtensionLabel

    /// IMAPv4 `search-mod-params`
    public typealias SearchModifierParams = TaggedExtensionValue

    /// IMAPv4 `search-return-value`
    public typealias SearchReturnValue = TaggedExtensionValue

}
