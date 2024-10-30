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

extension BodyStructure {
    /// Pairs a location with `BodyExtensions`s. An abstraction from RFC 3501
    /// to make the API slightly easier to work with and enforce validity.
    public struct LocationAndExtensions: Hashable, Sendable {
        /// A string giving the body content URI. Defined in LOCATION.
        public var location: String?

        /// An array of extension fields that are not formally defined, but may be in future capabilities.
        /// This is a method of future proofing clients.
        public var extensions: [BodyExtension]

        /// Creates a new `LocationAndExtensions` pair.
        /// - parameter location: A string giving the body content URI. Defined in LOCATION.
        /// - parameter extensions: An array of extension fields that are not formally defined, but may be in future capabilities.
        public init(location: String?, extensions: [BodyExtension]) {
            self.location = location
            self.extensions = extensions
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeBodyLocationAndExtensions(
        _ locationExtension: BodyStructure.LocationAndExtensions
    ) -> Int {
        self.writeSpace() + self.writeNString(locationExtension.location)
            + self.write(if: !locationExtension.extensions.isEmpty) {
                self.writeSpace() + self.writeBodyExtensions(locationExtension.extensions)
            }
    }
}
