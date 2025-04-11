//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2025 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@_spi(NIOIMAPInternal) import NIOIMAPCore

struct ClientEncodingOptions {
    var userOptions: IMAPClientHandler.EncodingOptions
    var automatic: CommandEncodingOptions

    init(
        userOptions: IMAPClientHandler.EncodingOptions,
        automatic: CommandEncodingOptions = CommandEncodingOptions()
    ) {
        self.userOptions = userOptions
        self.automatic = automatic
    }

    var encodingOptions: CommandEncodingOptions {
        switch userOptions {
        case .automatic: return automatic
        case .fixed(let e): return e
        }
    }
}

extension ClientEncodingOptions {
    mutating func updateAutomaticOptions(
        response: Response
    ) {
        switch response {
        case .untagged(.capabilityData(let c)):
            self.updateAutomaticOptions(capabilities: c)
        case .tagged(let tagged):
            switch tagged.state {
            case .ok(let r), .no(let r), .bad(let r):
                switch r.code {
                case .capability(let c)?:
                    self.updateAutomaticOptions(capabilities: c)
                default:
                    break
                }
            }
        default:
            break
        }
    }

    mutating func updateAutomaticOptions(
        capabilities: [Capability]
    ) {
        automatic = CommandEncodingOptions(capabilities: capabilities)
    }
}
