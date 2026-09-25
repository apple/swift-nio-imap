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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIOCore
import NIOIMAP

// Does not handle header folding (continuation lines).
enum MIMEMessage {
    case data(Data)
    case byteBuffer(ByteBuffer)

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
    func withContiguousBytes<R>(_ body: (Span<UInt8>) -> R) -> R {
        switch self {
        case .data(let data):
            return body(data.span)
        case .byteBuffer(let buffer):
            return buffer.withUnsafeReadableBytes { body($0.bindMemory(to: UInt8.self).span) }
        }
    }

    /// Iterates header lines, calling `body` with the header name and value
    /// portions of each line. Stops at the first empty line (end of headers)
    /// or when `body` returns `false`.
    func enumerateHeaderLines(
        in buffer: Span<UInt8>,
        body: (_ name: Span<UInt8>, _ value: Span<UInt8>) -> Bool
    ) {
        var position = 0
        let count = buffer.count

        while position < count {
            let lineStart = position
            while position < count && buffer[position] != UInt8(ascii: "\n") {
                position += 1
            }
            var lineEnd = position
            if lineEnd > lineStart && buffer[lineEnd - 1] == UInt8(ascii: "\r") {
                lineEnd -= 1
            }
            if position < count {
                position += 1
            }

            if lineEnd == lineStart { return }

            // Find the colon separating name from value.
            var colonIndex = lineStart
            while colonIndex < lineEnd && buffer[colonIndex] != UInt8(ascii: ":") {
                colonIndex += 1
            }
            guard colonIndex < lineEnd else { continue }

            let name = buffer.extracting(lineStart..<colonIndex)
            let value = buffer.extracting((colonIndex + 1)..<lineEnd)
            if !body(name, value) { return }
        }
    }

    private func caseInsensitiveEqual(
        _ buffer: Span<UInt8>,
        _ expected: StaticString
    ) -> Bool {
        guard buffer.count == expected.utf8CodeUnitCount else { return false }
        return expected.withUTF8Buffer { expectedBytes in
            for i in 0..<expectedBytes.count {
                let b = buffer[i]
                let lower = (b >= 0x41 && b <= 0x5A) ? b | 0x20 : b
                if lower != expectedBytes[i] { return false }
            }
            return true
        }
    }

    private func trimmedString(_ buffer: Span<UInt8>) -> String {
        var start = 0
        var end = buffer.count
        while start < end && (buffer[start] == UInt8(ascii: " ") || buffer[start] == UInt8(ascii: "\t")) {
            start += 1
        }
        while end > start && (buffer[end - 1] == UInt8(ascii: " ") || buffer[end - 1] == UInt8(ascii: "\t")) {
            end -= 1
        }
        return buffer.extracting(start..<end).utf8String
    }
}
