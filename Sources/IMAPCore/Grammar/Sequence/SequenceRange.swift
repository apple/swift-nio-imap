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
 
    /// IMAPv4 `seq-range`
    public struct SequenceRange: Equatable {
        
        public static var wildcard: SequenceRange {
            return Self(.last ... .last)
        }
        
        public static func single(_ num: Int) -> SequenceRange {
            return Self(.number(num) ... .number(num))
        }
        
        public var closedRange: ClosedRange<SequenceNumber>
        
        public var from: SequenceNumber {
            return closedRange.lowerBound
        }
        
        public var to: SequenceNumber {
            return closedRange.upperBound
        }
        
        public init(from: SequenceNumber, to: SequenceNumber) {
            if from < to {
                self.init(from ... to)
            } else {
                self.init(to ... from)
            }
        }
        
        public init(_ closedRange: ClosedRange<SequenceNumber>) {
            self.closedRange = closedRange
        }
        
    }
    
}

// MARK: - Integer literal
extension IMAPCore.SequenceRange: ExpressibleByIntegerLiteral {
    
    public typealias IntegerLiteralType = Int
    
    public init(integerLiteral value: Self.IntegerLiteralType) {
        self.closedRange = ClosedRange(uncheckedBounds: (.number(value), .number(value)))
    }
    
}

// MARK: - Swift ranges
extension IMAPCore.SequenceNumber {
    
    // always flip for wildcard to be on right
    public static prefix func ... (maximum: Self) -> IMAPCore.SequenceRange {
        return IMAPCore.SequenceRange(maximum ... .last)
    }
    
    public static postfix func ... (minimum: Self) -> IMAPCore.SequenceRange {
        return IMAPCore.SequenceRange(minimum ... .last)
    }
    
    public static func ... (minimum: Self, maximum: Self) -> IMAPCore.SequenceRange {
        if minimum < maximum {
            return IMAPCore.SequenceRange(minimum ... maximum)
        } else {
            return IMAPCore.SequenceRange(maximum ... minimum)
        }
    }

}

// MARK: - Encoding
extension ByteBufferProtocol {

    @discardableResult mutating func writeSequenceRange(_ range: IMAPCore.SequenceRange) -> Int {
        self.writeSequenceNumber(range.closedRange.lowerBound) +
        self.writeIfTrue(range.closedRange.lowerBound < range.closedRange.upperBound) {
            self.writeString(":") +
            self.writeSequenceNumber(range.closedRange.upperBound)
        }
    }
    
}
