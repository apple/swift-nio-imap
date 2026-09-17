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
    ///
    /// - Throws: ``StatusNotOK`` if the status is `NO`, `BAD`, `PREAUTH`, or `BYE`.
    public func checkOK() throws(StatusNotOK) {
        switch self {
        case .ok:
            return
        case .no, .bad, .preauth, .bye:
            throw StatusNotOK(status: self)
        }
    }

    /// An error indicating a non-`OK` status.
    public struct StatusNotOK: Swift.Error, Sendable {
        /// The status the server sent.
        public var status: UntaggedStatus

        /// Creates an error reporting the given non-`OK` status.
        public init(status: UntaggedStatus) {
            self.status = status
        }
    }

    /// Returns the response text if the status is `OK`, or throws an error.
    ///
    /// - Throws: ``StatusNotOK`` if the status is `NO`, `BAD`, `PREAUTH`, or `BYE`.
    public func getOK() throws(StatusNotOK) -> ResponseText {
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
    ///
    /// - Throws: ``StateNotOK`` if the server answered `NO` or `BAD`.
    public func checkOK() throws(StateNotOK) {
        try state.checkOK()
    }

    /// Returns the response text if the state is `OK`, or throws an error.
    ///
    /// - Throws: ``StateNotOK`` if the server answered `NO` or `BAD`.
    public func getOK() throws(StateNotOK) -> ResponseText {
        try state.getOK()
    }

    /// An error indicating a non-`OK` tagged response state.
    public struct StateNotOK: Swift.Error, Sendable {
        /// The state the server sent.
        public var state: TaggedResponse.State

        /// Creates an error reporting the given non-`OK` state.
        public init(state: TaggedResponse.State) {
            self.state = state
        }
    }
}

extension TaggedResponse.State {
    /// Throws an error if the state is not `OK`.
    ///
    /// - Throws: ``TaggedResponse/StateNotOK`` if the server answered `NO` or `BAD`.
    public func checkOK() throws(TaggedResponse.StateNotOK) {
        switch self {
        case .ok:
            return
        case .no, .bad:
            throw TaggedResponse.StateNotOK(state: self)
        }
    }

    /// Returns the response text if the state is `OK`, or throws an error.
    ///
    /// - Throws: ``TaggedResponse/StateNotOK`` if the server answered `NO` or `BAD`.
    public func getOK() throws(TaggedResponse.StateNotOK) -> ResponseText {
        switch self {
        case .ok(let text):
            return text
        case .no, .bad:
            throw TaggedResponse.StateNotOK(state: self)
        }
    }
}

extension UntaggedStatus.StatusNotOK: CustomStringConvertible {
    public var description: String {
        "The server responded with \(status) rather than OK."
    }
}

extension TaggedResponse.StateNotOK: CustomStringConvertible {
    public var description: String {
        "The server responded with \(state) rather than OK."
    }
}
