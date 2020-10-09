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
public struct IPathQuery: Equatable {
    public var command: ICommand?

    public init(command: ICommand?) {
        self.command = command
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeIPathQuery(_ query: IPathQuery) -> Int {
        self.writeString("/") +
            self.writeIfExists(query.command) { command in
                self.writeICommand(command)
            }
    }
}
