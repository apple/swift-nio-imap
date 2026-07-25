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
import NIOIMAP
#if canImport(System)
import System
#else
import SystemPackage
#endif

/// An RFC 5322 email message stored as raw data.
public struct EmailMessage: Hashable, Sendable {
    var data: Data
}

extension EmailMessage {
    init(filePath: FilePath) async throws {
        let input = try await Data(
            asyncContentsOf: filePath
        )
        // This is not entirely clean, but we want to avoid uploading
        // messages with Unix file endings to an IMAP server.
        guard
            EmailMessage.headerIsCRLFClean(input)
        else {
            self = EmailMessage.convertingLineEndings(input)
            return
        }
        self.init(data: input)
    }
}

extension EmailMessage {
    /// Checks whether the message header uses CRLF line endings.
    static func headerIsCRLFClean(_ input: Data) -> Bool {
        input.withUnsafeBytes { buffer in
            var isCRLFClean = true
            // Find the first 4 line breaks:
            let max = min(buffer.count, 10_000)
            var remainder = buffer[..<max]
            var count = 0
            while count < 4, !remainder.isEmpty {
                guard
                    isCRLFClean,
                    let index = remainder.firstIndex(where: { $0 == 0x0d || $0 == 0x0a })
                else { break }

                var next = index + 1
                defer {
                    let start = min(remainder.endIndex, next)
                    remainder = remainder[start...]
                }

                switch remainder[index] {
                case 0x0d:
                    if index + 1 < remainder.endIndex {
                        if remainder[index + 1] == 0xa {
                            next += 1
                            count += 1
                        } else {
                            isCRLFClean = false
                        }
                    } else {
                        isCRLFClean = false
                    }
                default:
                    isCRLFClean = false
                }
            }
            return isCRLFClean
        }
    }

    /// Creates an email message by converting all line endings to CRLF.
    static func convertingLineEndings(_ input: Data) -> EmailMessage {
        // Convert to CRLF:
        var output = Data(capacity: input.count)
        input.withUnsafeBytes { inputBuffer in
            guard !inputBuffer.isEmpty else { return }
            var remainder = inputBuffer[...]
            while let end = remainder.locateLineEnding() {
                let line = remainder[remainder.startIndex..<end.lowerBound]
                output.append(contentsOf: line)
                output.append(contentsOf: [0xD, 0xA])
                remainder = remainder[end.upperBound..<remainder.endIndex]
            }
            if !remainder.isEmpty {
                output.append(contentsOf: remainder)
            }
        }
        return EmailMessage(data: output)
    }
}

extension EmailMessage {
    public struct HeadersOfInterest: Hashable, Sendable {
        public var messageID: MessageID
        public var date: InternetMessageDate
        /// The message subject, for display purposes. Not populated by the
        /// default ``MiniMIMEHeaderParser``.
        public var subject: String?

        public init(messageID: MessageID, date: InternetMessageDate, subject: String? = nil) {
            self.messageID = messageID
            self.date = date
            self.subject = subject
        }
    }

    var headersOfInterest: HeadersOfInterest? {
        MessageHeaderParser.current.headersOfInterest(data)
    }
}

// MARK: -

extension Slice where Base == UnsafeRawBufferPointer {
    func locateLineEnding() -> Range<Int>? {
        guard let r = locate(0xA) else { return nil }
        // Check if there’s an CR:
        guard startIndex < r.lowerBound, self[r.lowerBound - 1] == 0xD else {
            return r
        }
        return (r.lowerBound - 1)..<r.upperBound
    }

    func locate(_ needle: UInt8) -> Range<Int>? {
        guard
            let rebased = UnsafeRawBufferPointer(rebasing: self).locate(needle)
        else { return nil }
        let start = rebased.lowerBound.advanced(by: startIndex)
        let end = rebased.upperBound.advanced(by: startIndex)
        return start..<end
    }

    func locateDoubleLineEnding() -> Range<Int>? {
        self.locate([0xD, 0xA, 0xD, 0xA])
    }

    func locate(_ needle: [UInt8]) -> Range<Int>? {
        needle.withUnsafeBytes { needleBuffer -> Range<Int>? in
            guard
                let rebased = UnsafeRawBufferPointer(rebasing: self)
                    .locate(needleBuffer.baseAddress!, needleBuffer.count)
            else { return nil }
            let start = rebased.lowerBound.advanced(by: startIndex)
            let end = rebased.upperBound.advanced(by: startIndex)
            return start..<end
        }
    }
}

extension UnsafeRawBufferPointer {
    func locate(_ needle: UnsafeRawPointer, _ needleCount: Int) -> Range<Int>? {
        guard
            let addr = baseAddress
        else { return nil }
        guard
            let location = memmem(addr, count, needle, needleCount)
        else { return nil }

        let start = addr.distance(to: location)
        guard startIndex <= start else { return nil }

        let end = start.advanced(by: needleCount)
        guard end <= endIndex else { return nil }

        return start..<end
    }

    func locate(_ needle: UInt8) -> Range<Int>? {
        guard
            let addr = baseAddress
        else { return nil }
        guard
            let location = memchr(addr, Int32(needle), count)
        else { return nil }

        let start = addr.distance(to: location)
        guard startIndex <= start else { return nil }

        let end = start.advanced(by: 1)
        guard end <= endIndex else { return nil }

        return start..<end
    }
}
