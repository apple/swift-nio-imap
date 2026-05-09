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

import Dispatch
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIOIMAP

// Does not handle header folding (continuation lines).
enum MIMEMessage {
    case data(Data)
    case dispatchData(DispatchData)

    func dateHeader() -> InternetMessageDate? {
        withContiguousBytes { buffer in
            var result: InternetMessageDate?
            enumerateHeaderLines(in: buffer) { name, value in
                if caseInsensitiveEqual(name, "date") {
                    result = InternetMessageDate(trimmedString(value))
                    return false
                }
                return true
            }
            return result
        }
    }

    func messageIDHeader() -> MessageID? {
        withContiguousBytes { buffer in
            var result: MessageID?
            enumerateHeaderLines(in: buffer) { name, value in
                if caseInsensitiveEqual(name, "message-id") {
                    result = MessageID(trimmedString(value))
                    return false
                }
                return true
            }
            return result
        }
    }

    func headersOfInterest() -> EmailMessage.HeadersOfInterest? {
        withContiguousBytes { buffer in
            var date: InternetMessageDate?
            var messageID: MessageID?
            enumerateHeaderLines(in: buffer) { name, value in
                if caseInsensitiveEqual(name, "date") {
                    date = InternetMessageDate(trimmedString(value))
                } else if caseInsensitiveEqual(name, "message-id") {
                    messageID = MessageID(trimmedString(value))
                }
                return date == nil || messageID == nil
            }
            guard let date, let messageID else { return nil }
            return EmailMessage.HeadersOfInterest(messageID: messageID, date: date)
        }
    }
}

// MARK: - Internal

extension MIMEMessage {
    func withContiguousBytes<R>(_ body: (UnsafeRawBufferPointer) -> R) -> R {
        switch self {
        case .data(let data):
            return data.withUnsafeBytes(body)
        case .dispatchData(let dd):
            return Data(dd).withUnsafeBytes(body)
        }
    }

    /// Iterates header lines, calling `body` with the header name and value
    /// portions of each line. Stops at the first empty line (end of headers)
    /// or when `body` returns `false`.
    func enumerateHeaderLines(
        in buffer: UnsafeRawBufferPointer,
        body: (_ name: UnsafeRawBufferPointer, _ value: UnsafeRawBufferPointer) -> Bool
    ) {
        guard buffer.count > 0 else { return }
        var position = 0
        let count = buffer.count
        let bytes = buffer.baseAddress!.assumingMemoryBound(to: UInt8.self)

        while position < count {
            let lineStart = position
            while position < count && bytes[position] != UInt8(ascii: "\n") {
                position += 1
            }
            var lineEnd = position
            if lineEnd > lineStart && bytes[lineEnd - 1] == UInt8(ascii: "\r") {
                lineEnd -= 1
            }
            if position < count {
                position += 1
            }

            let lineLength = lineEnd - lineStart
            if lineLength == 0 { return }

            // Find the colon separating name from value.
            var colonIndex = lineStart
            while colonIndex < lineEnd && bytes[colonIndex] != UInt8(ascii: ":") {
                colonIndex += 1
            }
            guard colonIndex < lineEnd else { continue }

            let name = UnsafeRawBufferPointer(
                start: bytes + lineStart,
                count: colonIndex - lineStart
            )
            let valueStart = colonIndex + 1
            let value = UnsafeRawBufferPointer(
                start: bytes + valueStart,
                count: lineEnd - valueStart
            )
            if !body(name, value) { return }
        }
    }

    private func caseInsensitiveEqual(
        _ buffer: UnsafeRawBufferPointer,
        _ expected: StaticString
    ) -> Bool {
        guard buffer.count == expected.utf8CodeUnitCount else { return false }
        let bytes = buffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
        return expected.withUTF8Buffer { expectedBytes in
            for i in 0..<expectedBytes.count {
                let b = bytes[i]
                let lower = (b >= 0x41 && b <= 0x5A) ? b | 0x20 : b
                if lower != expectedBytes[i] { return false }
            }
            return true
        }
    }

    private func trimmedString(_ buffer: UnsafeRawBufferPointer) -> String {
        guard buffer.count > 0 else { return "" }
        let bytes = buffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
        var start = 0
        var end = buffer.count
        while start < end && (bytes[start] == UInt8(ascii: " ") || bytes[start] == UInt8(ascii: "\t")) {
            start += 1
        }
        while end > start && (bytes[end - 1] == UInt8(ascii: " ") || bytes[end - 1] == UInt8(ascii: "\t")) {
            end -= 1
        }
        return String(
            decoding: UnsafeRawBufferPointer(start: bytes + start, count: end - start),
            as: UTF8.self
        )
    }
}
