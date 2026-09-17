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

import ArgumentParser
// `Scanner`/`CharacterSet` are not part of `FoundationEssentials`.
import Foundation

/// Generates deterministic pseudo-random numbers from a fixed seed.
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    fileprivate struct State {
        var state: UInt64
        var inc: UInt64
    }

    fileprivate var state: State

    /// Creates a generator with the given seed.
    init(_ seed: Seed) {
        self.state = State(state: seed.a, inc: seed.b)
    }

    /// Creates a generator with two raw state values.
    init(_ a: UInt64, _ b: UInt64) {
        self.state = State(state: a, inc: b)
    }

    /// Returns the next random `UInt64` value.
    mutating func next() -> UInt64 {
        UInt64(self.state.next()) << 32 | UInt64(self.state.next())
    }

    /// Returns the next random `UInt32` value.
    mutating func next() -> UInt32 {
        self.state.next()
    }
}

extension SeededRandomNumberGenerator.State {
    /// Advances the state and returns the next random `UInt32` value.
    mutating func next() -> UInt32 {
        let oldstate = self.state
        self.state = oldstate &* 6_364_136_223_846_793_005 &+ (inc | 1)
        let xorshifted: UInt64 = ((oldstate >> 18) ^ oldstate) >> 27
        let rot: UInt64 = oldstate >> 59
        let irot = UInt64(bitPattern: -Int64(bitPattern: rot))
        let result: UInt64 = (xorshifted >> rot) | (xorshifted << (irot & 31))
        return UInt32(result & UInt64(UInt32.max))
    }
}

extension SeededRandomNumberGenerator {
    /// A pair of values that initializes the random number generator state.
    struct Seed: Equatable {
        /// The first state component.
        var a: UInt64
        /// The second state component.
        var b: UInt64

        /// Creates a seed with the given state components.
        init(a: UInt64, b: UInt64) {
            self.a = a
            self.b = b
        }
    }
}

extension SeededRandomNumberGenerator.Seed: ExpressibleByArgument {
    /// The default seed value.
    static var `default`: SeededRandomNumberGenerator.Seed {
        SeededRandomNumberGenerator.Seed(a: 0x3501_404A_0218_5150, b: 0xF23C_78DA_2C09_7E04)
    }

    /// Creates a seed by parsing a hex-prefixed string argument.
    init?(argument: String) {
        guard
            let a = SeededRandomNumberGenerator.Seed(hexPrefixed: argument)
        else { return nil }
        self = a
    }

    init?(hexPrefixed string: String) {
        let scanner = Scanner(string: string)
        guard scanner.scanString("hex:") != nil else { return nil }
        scanner.charactersToBeSkipped = CharacterSet(charactersIn: " _")
        var values: [UInt8] = []
        while !scanner.isAtEnd {
            guard
                let a = scanner.scanCharacter(),
                let b = scanner.scanCharacter(),
                let c = UInt8(String([a, b]), radix: 16)
            else { return nil }
            values.append(c)
        }
        guard values.count == 16 else { return nil }

        var remaining = values[...]
        func pop() -> UInt64 {
            var r = 0 as UInt64
            for _ in 0..<8 {
                r *= 256
                r += UInt64(remaining.popFirst()!)
            }
            return r
        }

        self.init(a: pop(), b: pop())
    }
}
