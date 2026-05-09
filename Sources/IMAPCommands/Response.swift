//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO
import NIOIMAP

extension UntaggedStatus {
    /// Throws an error if the status is not `OK`.
    public func checkOK() throws {
        switch self {
        case .ok:
            return
        case .no, .bad, .preauth, .bye:
            throw StatusNotOK(status: self)
        }
    }

    /// An error indicating a non-`OK` status.
    public struct StatusNotOK: Swift.Error {
        public var status: UntaggedStatus
    }

    /// Returns the response text if the status is `OK`, or throws an error.
    public func getOK() throws -> ResponseText {
        switch self {
        case .ok(let text):
            return text
        case .no, .bad, .preauth, .bye:
            throw StatusNotOK(status: self)
        }
    }
}

extension TaggedResponse {
    /// Throws an error if the response state is not `OK`.
    public func checkOK() throws {
        try state.checkOK()
    }

    /// Returns the response text if the state is `OK`, or throws an error.
    public func getOK() throws -> ResponseText {
        try state.getOK()
    }

    /// An error indicating a non-`OK` tagged response state.
    public struct StateNotOK: Swift.Error {
        public var state: TaggedResponse.State
    }
}

extension TaggedResponse.State {
    /// Throws an error if the state is not `OK`.
    public func checkOK() throws {
        switch self {
        case .ok:
            return
        case .no, .bad:
            throw TaggedResponse.StateNotOK(state: self)
        }
    }

    /// Returns the response text if the state is `OK`, or throws an error.
    public func getOK() throws -> ResponseText {
        switch self {
        case .ok(let text):
            return text
        case .no, .bad:
            throw TaggedResponse.StateNotOK(state: self)
        }
    }
}
