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

import struct NIO.ByteBuffer

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeQuotaResponse(quotaRoot: QuotaRoot, resources: [QuotaResource]) -> Int {
        self._writeString("QUOTA ") +
            self.writeQuotaRoot(quotaRoot) +
            self.writeSpace() +
            self.writeQuotaResources(resources)
    }

    mutating func writeQuotaResources(_ resources: [QuotaResource]) -> Int {
        self._writeString("(") +
            resources.map { resource in self.writeQuotaResource(resource) }.reduce(0, +) +
            self._writeString(")")
    }
}
