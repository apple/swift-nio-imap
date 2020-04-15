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

    /// IMAPv4 `response-tagged`
    public struct ResponseTagged: Equatable {
        public var tag: String
        public var state: ResponseConditionalState
        
        public static func tag(_ tag: String, state: ResponseConditionalState) -> Self {
            return Self(tag: tag, state: state)
        }
    }
    
}
