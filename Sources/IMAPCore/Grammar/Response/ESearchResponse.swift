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

    /// IMAPv4 `esearch-response`
    public struct ESearchResponse: Equatable {
        public var correlator: String?
        public var uid: Bool
        public var returnData: [SearchReturnData]

        public static func correlator(_ correlator: String?, uid: Bool, returnData: [SearchReturnData]) -> Self {
            return Self(correlator: correlator, uid: uid, returnData: returnData)
        }
    }
}
