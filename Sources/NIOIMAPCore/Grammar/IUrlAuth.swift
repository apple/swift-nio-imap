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

/// RFC 5092
public struct IUrlAuth: Equatable {
    public var auth: IURLAuthRump
    public var verifier: IUAVerifier
    
    public init(auth: IURLAuthRump, verifier: IUAVerifier) {
        self.auth = auth
        self.verifier = verifier
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeIUrlAuth(_ data: IUrlAuth) -> Int {
        self.writeIURLAuthRump(data.auth) +
            self.writeIUAVerifier(data.verifier)
    }
}
