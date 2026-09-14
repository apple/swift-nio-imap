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

extension Array where Element: FloatingPoint {
    func mean() -> Element? {
        guard !isEmpty else { return nil }
        return self.sum() / Element(count)
    }

    func sum() -> Element {
        reduce(0, +)
    }

    func standardDeviation() -> Element? {
        guard let meanValue = mean() else { return nil }
        let variance = (reduce(into: 0 as Element) { $0 += (meanValue - $1) * (meanValue - $1) }) / Element(count)
        return variance.squareRoot()
    }
}
