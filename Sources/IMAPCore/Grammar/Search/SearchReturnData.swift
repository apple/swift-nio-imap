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

    /// IMAPv4 `search-return-data`
    public enum SearchReturnData: Equatable {
        case min(Int)
        case max(Int)
        case all([IMAPCore.SequenceRange])
        case count(Int)
        case dataExtension(SearchReturnDataExtension)
    }

}
