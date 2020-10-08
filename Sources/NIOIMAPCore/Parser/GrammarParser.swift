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

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import Darwin
#elseif os(Linux) || os(FreeBSD) || os(Android)
import Glibc
#else
let badOS = { fatalError("unsupported OS") }()
#endif

import struct NIO.ByteBuffer
import struct NIO.ByteBufferView

public enum ParsingError: Error {
    case lineTooLong
}

struct _IncompleteMessage: Error {
    init() {}
}

public enum GrammarParser {}

// MARK: - Grammar Parsers

extension GrammarParser {
    // address         = "(" addr-name SP addr-adl SP addr-mailbox SP
    //                   addr-host ")"
    static func parseAddress(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Address {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Address in
            try fixedString("(", buffer: &buffer, tracker: tracker)
            let name = try self.parseNString(buffer: &buffer, tracker: tracker)
            try fixedString(" ", buffer: &buffer, tracker: tracker)
            let adl = try self.parseNString(buffer: &buffer, tracker: tracker)
            try fixedString(" ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseNString(buffer: &buffer, tracker: tracker)
            try fixedString(" ", buffer: &buffer, tracker: tracker)
            let host = try self.parseNString(buffer: &buffer, tracker: tracker)
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return Address(name: name, adl: adl, mailbox: mailbox, host: host)
        }
    }

    // append          = "APPEND" SP mailbox 1*append-message
    static func parseAppend(buffer: inout ByteBuffer, tracker: StackTracker) throws -> CommandStream {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> CommandStream in
            let tag = try self.parseTag(buffer: &buffer, tracker: tracker)
            try fixedString(" APPEND ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .append(.start(tag: tag, appendingTo: mailbox))
        }
    }

    // append-data = literal / literal8 / append-data-ext
    static func parseAppendData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> AppendData {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> AppendData in
            let withoutContentTransferEncoding = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try fixedString("~", buffer: &buffer, tracker: tracker)
            }.map { () in true } ?? false
            try fixedString("{", buffer: &buffer, tracker: tracker)
            let length = try Self.parseNumber(buffer: &buffer, tracker: tracker)
            _ = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try fixedString("+", buffer: &buffer, tracker: tracker)
            }.map { () in false } ?? true
            try fixedString("}", buffer: &buffer, tracker: tracker)
            try newline(buffer: &buffer, tracker: tracker)
            return .init(byteCount: length, withoutContentTransferEncoding: withoutContentTransferEncoding)
        }
    }

    // append-message = appents-opts SP append-data
    static func parseAppendMessage(buffer: inout ByteBuffer, tracker: StackTracker) throws -> AppendMessage {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> AppendMessage in
            let options = try self.parseAppendOptions(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let data = try self.parseAppendData(buffer: &buffer, tracker: tracker)
            return .init(options: options, data: data)
        }
    }

    // Like appendMessage, but with CATENATE at the start instead of regular append data.
    static func parseCatenateMessage(buffer: inout ByteBuffer, tracker: StackTracker) throws -> AppendOptions {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> AppendOptions in
            let options = try self.parseAppendOptions(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            try fixedString("CATENATE (", buffer: &buffer, tracker: tracker)
            return options
        }
    }

    enum AppendOrCatenateMessage {
        case append(AppendMessage)
        case catenate(AppendOptions)
    }

    static func parseAppendOrCatenateMessage(buffer: inout ByteBuffer, tracker: StackTracker) throws -> AppendOrCatenateMessage {
        func parseAppend(buffer: inout ByteBuffer, tracker: StackTracker) throws -> AppendOrCatenateMessage {
            try .append(self.parseAppendMessage(buffer: &buffer, tracker: tracker))
        }

        func parseCatenate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> AppendOrCatenateMessage {
            try .catenate(self.parseCatenateMessage(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseCatenate,
            parseAppend,
        ], buffer: &buffer, tracker: tracker)
    }

    // append-options = [SP flag-list] [SP date-time] *(SP append-ext)
    static func parseAppendOptions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> AppendOptions {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let flagList = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [Flag] in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseFlagList(buffer: &buffer, tracker: tracker)
            } ?? []
            let internalDate = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> InternalDate in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseInternalDate(buffer: &buffer, tracker: tracker)
            }
            let array = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> TaggedExtension in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseTaggedExtension(buffer: &buffer, tracker: tracker)
            }
            return .init(flagList: flagList, internalDate: internalDate, extensions: array)
        }
    }

    enum CatenatePart {
        case url(ByteBuffer)
        case text(Int)
        case end
    }

    static func parseCatenatePart(expectPrecedingSpace: Bool, buffer: inout ByteBuffer, tracker: StackTracker) throws -> CatenatePart {
        func parseCatenateURL(buffer: inout ByteBuffer, tracker: StackTracker) throws -> CatenatePart {
            if expectPrecedingSpace {
                try space(buffer: &buffer, tracker: tracker)
            }
            try fixedString("URL ", buffer: &buffer, tracker: tracker)
            let url = try self.parseAString(buffer: &buffer, tracker: tracker)
            return .url(url)
        }

        func parseCatenateText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> CatenatePart {
            if expectPrecedingSpace {
                try space(buffer: &buffer, tracker: tracker)
            }
            try fixedString("TEXT {", buffer: &buffer, tracker: tracker)
            let length = try Self.parseNumber(buffer: &buffer, tracker: tracker)
            _ = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try fixedString("+", buffer: &buffer, tracker: tracker)
            }.map { () in false } ?? true
            try fixedString("}", buffer: &buffer, tracker: tracker)
            try newline(buffer: &buffer, tracker: tracker)
            return .text(length)
        }

        func parseCatenateEnd(buffer: inout ByteBuffer, tracker: StackTracker) throws -> CatenatePart {
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return .end
        }

        return try oneOf([
            parseCatenateURL,
            parseCatenateText,
            parseCatenateEnd,
        ], buffer: &buffer, tracker: tracker)
    }

    // astring         = 1*ASTRING-CHAR / string
    static func parseAString(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        func parseOneOrMoreASTRINGCHAR(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
            try ParserLibrary.parseOneOrMoreCharactersByteBuffer(buffer: &buffer, tracker: tracker) { char -> Bool in
                char.isAStringChar
            }
        }
        return try oneOf([
            Self.parseString,
            parseOneOrMoreASTRINGCHAR,
        ], buffer: &buffer, tracker: tracker)
    }

    // atom            = 1*ATOM-CHAR
    static func parseAtom(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            char.isAtomChar
        }
    }

    // RFC 7162 Condstore
    // attr-flag           = "\\Answered" / "\\Flagged" / "\\Deleted" /
    //                          "\\Seen" / "\\Draft" / attr-flag-keyword / attr-flag-extension
    static func parseAttributeFlag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> AttributeFlag {
        func parseAttributeFlag_slashed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> AttributeFlag {
            try fixedString("\\\\", buffer: &buffer, tracker: tracker)
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init(rawValue: "\\\\\(atom)")
        }

        func parseAttributeFlag_unslashed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> AttributeFlag {
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init(rawValue: atom)
        }

        return try oneOf([
            parseAttributeFlag_slashed,
            parseAttributeFlag_unslashed,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseAuthIMAPURL(buffer: inout ByteBuffer, tracker: StackTracker) throws -> AuthIMAPURL {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> AuthIMAPURL in
            try fixedString("imap://", buffer: &buffer, tracker: tracker)
            let server = try self.parseIServer(buffer: &buffer, tracker: tracker)
            try fixedString("/", buffer: &buffer, tracker: tracker)
            let messagePart = try self.parseIMessagePart(buffer: &buffer, tracker: tracker)
            return .init(server: server, messagePart: messagePart)
        }
    }

    static func parseAuthIMAPURLFull(buffer: inout ByteBuffer, tracker: StackTracker) throws -> AuthIMAPURLFull {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> AuthIMAPURLFull in
            let imapURL = try self.parseAuthIMAPURL(buffer: &buffer, tracker: tracker)
            let urlAuth = try self.parseIURLAuth(buffer: &buffer, tracker: tracker)
            return .init(imapURL: imapURL, urlAuth: urlAuth)
        }
    }

    static func parseAuthIMAPURLRump(buffer: inout ByteBuffer, tracker: StackTracker) throws -> AuthIMAPURLRump {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> AuthIMAPURLRump in
            let imapURL = try self.parseAuthIMAPURL(buffer: &buffer, tracker: tracker)
            let authRump = try self.parseIURLAuthRump(buffer: &buffer, tracker: tracker)
            return .init(imapURL: imapURL, authRump: authRump)
        }
    }

    // authenticate  = "AUTHENTICATE" SP auth-type [SP (base64 / "=")] *(CRLF base64)
    static func parseAuthenticate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("AUTHENTICATE ", buffer: &buffer, tracker: tracker)
            let authMethod = try self.parseAtom(buffer: &buffer, tracker: tracker)

            let parseInitialClientResponse = try optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> InitialClientResponse in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseInitialClientResponse(buffer: &buffer, tracker: tracker)
            })

            // NOTE: Spec is super unclear, so we're ignoring the possibility of multiple base 64 chunks right now
//            let data = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [ByteBuffer] in
//                try fixedString("\r\n", buffer: &buffer, tracker: tracker)
//                return [try self.parseBase64(buffer: &buffer, tracker: tracker)]
//            } ?? []
            return .authenticate(method: authMethod, initialClientResponse: parseInitialClientResponse, [])
        }
    }

    static func parseInitialClientResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> InitialClientResponse {
        func parseInitialClientResponse_empty(buffer: inout ByteBuffer, tracker: StackTracker) throws -> InitialClientResponse {
            try fixedString("=", buffer: &buffer, tracker: tracker)
            return .empty
        }

        func parseInitialClientResponse_data(buffer: inout ByteBuffer, tracker: StackTracker) throws -> InitialClientResponse {
            let base64 = try parseBase64(buffer: &buffer, tracker: tracker)
            return .data(base64)
        }

        return try oneOf([
            parseInitialClientResponse_empty,
            parseInitialClientResponse_data,
        ], buffer: &buffer, tracker: tracker)
    }

    // base64          = *(4base64-char) [base64-terminal]
    static func parseBase64(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
            let bytes = try ParserLibrary.parseZeroOrMoreCharactersByteBuffer(buffer: &buffer, tracker: tracker) { $0.isBase64Char || $0 == UInt8(ascii: "=") }
            let readableBytesView = bytes.readableBytesView
            if let firstEq = readableBytesView.firstIndex(of: UInt8(ascii: "=")) {
                for index in firstEq ..< readableBytesView.endIndex {
                    guard readableBytesView[index] == UInt8(ascii: "=") else {
                        throw ParserError(hint: "Found invalid character (expecting =) \(String(decoding: readableBytesView, as: Unicode.UTF8.self))")
                    }
                }
            }

            do {
                let decoded = try Base64.decode(encoded: String(buffer: bytes))
                return ByteBuffer(ByteBufferView(decoded))
            } catch {
                throw ParserError(hint: "Invalid base64 \(error)")
            }
        }
    }

    // body            = "(" (body-type-1part / body-type-mpart) ")"
    static func parseBody(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure {
        func parseBody_singlePart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure {
            try fixedString("(", buffer: &buffer, tracker: tracker)
            let part = try self.parseBodyKindSinglePart(buffer: &buffer, tracker: tracker)
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return .singlepart(part)
        }

        func parseBody_multiPart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure {
            try fixedString("(", buffer: &buffer, tracker: tracker)
            let part = try self.parseBodyKindMultipart(buffer: &buffer, tracker: tracker)
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return .multipart(part)
        }

        return try oneOf([
            parseBody_singlePart,
            parseBody_multiPart,
        ], buffer: &buffer, tracker: tracker)
    }

    // body-extension  = nstring / number /
    //                    "(" body-extension *(SP body-extension) ")"
    static func parseBodyExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [BodyExtension] {
        func parseBodyExtensionKind_string(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyExtension {
            .string(try self.parseNString(buffer: &buffer, tracker: tracker))
        }

        func parseBodyExtensionKind_number(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyExtension {
            .number(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseBodyExtensionKind(buffer: inout ByteBuffer, tracker: StackTracker, into array: inout [BodyExtension]) throws {
            let element = try oneOf([
                parseBodyExtensionKind_string,
                parseBodyExtensionKind_number,
            ], buffer: &buffer, tracker: tracker)
            array.append(element)
        }

        func parseBodyExtension_array(buffer: inout ByteBuffer, tracker: StackTracker, into array: inout [BodyExtension]) throws {
            try fixedString("(", buffer: &buffer, tracker: tracker)
            try parseBodyExtension_arrayOrStatic(buffer: &buffer, tracker: tracker, into: &array)
            var save = buffer
            do {
                while true {
                    save = buffer
                    try space(buffer: &buffer, tracker: tracker)
                    try parseBodyExtension_arrayOrStatic(buffer: &buffer, tracker: tracker, into: &array)
                }
            } catch is ParserError {
                buffer = save
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
        }

        func parseBodyExtension_arrayOrStatic(buffer: inout ByteBuffer, tracker: StackTracker, into array: inout [BodyExtension]) throws {
            let save = buffer
            do {
                try parseBodyExtensionKind(buffer: &buffer, tracker: tracker, into: &array)
            } catch is ParserError {
                buffer = save
                try parseBodyExtension_array(buffer: &buffer, tracker: tracker, into: &array)
            }
        }

        var array = [BodyExtension]()
        try parseBodyExtension_arrayOrStatic(buffer: &buffer, tracker: tracker, into: &array)
        return array
    }

    // body-ext-1part  = body-fld-md5 [SP body-fld-dsp [SP body-fld-lang [SP body-fld-loc *(SP body-extension)]]]
    static func parseBodyExtSinglePart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Singlepart.Extension {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> BodyStructure.Singlepart.Extension in
            let md5 = try self.parseNString(buffer: &buffer, tracker: tracker).flatMap { String(buffer: $0) }
            let dsp = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> BodyStructure.DispositionAndLanguage in
                try space(buffer: &buffer, tracker: tracker)
                return try parseBodyDescriptionLanguage(buffer: &buffer, tracker: tracker)
            }
            return BodyStructure.Singlepart.Extension(fieldMD5: md5, dispositionAndLanguage: dsp)
        }
    }

    // body-ext-mpart  = body-fld-param [SP body-fld-dsp [SP body-fld-lang [SP body-fld-loc *(SP body-extension)]]]
    static func parseBodyExtMpart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Multipart.Extension {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> BodyStructure.Multipart.Extension in
            let param = try self.parseBodyFieldParam(buffer: &buffer, tracker: tracker)
            let dsp = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> BodyStructure.DispositionAndLanguage in
                try space(buffer: &buffer, tracker: tracker)
                return try parseBodyDescriptionLanguage(buffer: &buffer, tracker: tracker)
            }
            return BodyStructure.Multipart.Extension(parameters: param, dispositionAndLanguage: dsp)
        }
    }

    // body-fields     = body-fld-param SP body-fld-id SP body-fld-desc SP
    //                   body-fld-enc SP body-fld-octets
    static func parseBodyFields(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Fields {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> BodyStructure.Fields in
            let fieldParam = try self.parseBodyFieldParam(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let fieldID = try self.parseNString(buffer: &buffer, tracker: tracker).flatMap { String(buffer: $0) }
            try space(buffer: &buffer, tracker: tracker)
            let fieldDescription = try self.parseNString(buffer: &buffer, tracker: tracker).flatMap { String(buffer: $0) }
            try space(buffer: &buffer, tracker: tracker)
            let Encoding = try self.parseBodyEncoding(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let fieldOctets = try self.parseNumber(buffer: &buffer, tracker: tracker)
            return BodyStructure.Fields(
                parameter: fieldParam,
                id: fieldID,
                description: fieldDescription,
                encoding: Encoding,
                octetCount: fieldOctets
            )
        }
    }

    // body-fld-dsp    = "(" string SP body-fld-param ")" / nil
    static func parseBodyFieldDsp(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Disposition? {
        func parseBodyFieldDsp_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Disposition? {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return nil
        }

        func parseBodyFieldDsp_some(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Disposition? {
            try fixedString("(", buffer: &buffer, tracker: tracker)
            let string = String(buffer: try self.parseString(buffer: &buffer, tracker: tracker))
            try space(buffer: &buffer, tracker: tracker)
            let param = try self.parseBodyFieldParam(buffer: &buffer, tracker: tracker)
            try GrammarParser.fixedString(")", buffer: &buffer, tracker: tracker)
            return BodyStructure.Disposition(kind: string, parameter: param)
        }

        return try oneOf([
            parseBodyFieldDsp_nil,
            parseBodyFieldDsp_some,
        ], buffer: &buffer, tracker: tracker)
    }

    // body-fld-enc    = (DQUOTE ("7BIT" / "8BIT" / "BINARY" / "BASE64"/
    //                   "QUOTED-PRINTABLE") DQUOTE) / string
    static func parseBodyEncoding(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Encoding {
        func parseBodyEncoding_string(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Encoding {
            let parsedBuffer = try self.parseString(buffer: &buffer, tracker: tracker)
            return .init(String(buffer: parsedBuffer))
        }

        func parseBodyEncoding_option(_ option: String, result: BodyStructure.Encoding, buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Encoding {
            try fixedString("\"", buffer: &buffer, tracker: tracker)
            try fixedString(option, buffer: &buffer, tracker: tracker)
            try fixedString("\"", buffer: &buffer, tracker: tracker)
            return result
        }

        func parseBodyEncoding_7bit(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Encoding {
            try parseBodyEncoding_option("7BIT", result: .sevenBit, buffer: &buffer, tracker: tracker)
        }

        func parseBodyEncoding_8bit(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Encoding {
            try parseBodyEncoding_option("8BIT", result: .eightBit, buffer: &buffer, tracker: tracker)
        }

        func parseBodyEncoding_binary(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Encoding {
            try parseBodyEncoding_option("BINARY", result: .binary, buffer: &buffer, tracker: tracker)
        }

        func parseBodyEncoding_base64(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Encoding {
            try parseBodyEncoding_option("BASE64", result: .base64, buffer: &buffer, tracker: tracker)
        }

        func parseBodyEncoding_quotePrintable(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Encoding {
            try parseBodyEncoding_option("QUOTED-PRINTABLE", result: .quotedPrintable, buffer: &buffer, tracker: tracker)
        }

        return try oneOf([
            parseBodyEncoding_7bit,
            parseBodyEncoding_8bit,
            parseBodyEncoding_binary,
            parseBodyEncoding_base64,
            parseBodyEncoding_quotePrintable,
            parseBodyEncoding_string,
        ], buffer: &buffer, tracker: tracker)
    }

    // body-fld-lang   = nstring / "(" string *(SP string) ")"
    static func parseBodyFieldLanguage(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [String] {
        func parseBodyFieldLanguage_single(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [String] {
            guard let language = try self.parseNString(buffer: &buffer, tracker: tracker) else {
                return []
            }
            return [String(buffer: language)]
        }

        func parseBodyFieldLanguage_multiple(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [String] {
            try fixedString("(", buffer: &buffer, tracker: tracker)
            var array = [String(buffer: try self.parseString(buffer: &buffer, tracker: tracker))]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> String in
                try space(buffer: &buffer, tracker: tracker)
                return String(buffer: try self.parseString(buffer: &buffer, tracker: tracker))
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }

        return try oneOf([
            parseBodyFieldLanguage_multiple,
            parseBodyFieldLanguage_single,
        ], buffer: &buffer, tracker: tracker)
    }

    // body-fld-param  = "(" string SP string *(SP string SP string) ")" / nil
    static func parseBodyFieldParam(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [BodyStructure.ParameterPair] {
        func parseBodyFieldParam_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [BodyStructure.ParameterPair] {
            try parseNil(buffer: &buffer, tracker: tracker)
            return []
        }

        func parseBodyFieldParam_singlePair(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.ParameterPair {
            let field = String(buffer: try parseString(buffer: &buffer, tracker: tracker))
            try space(buffer: &buffer, tracker: tracker)
            let value = String(buffer: try parseString(buffer: &buffer, tracker: tracker))
            return .init(field: field, value: value)
        }

        func parseBodyFieldParam_pairs(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [BodyStructure.ParameterPair] {
            try fixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try parseBodyFieldParam_singlePair(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> BodyStructure.ParameterPair in
                try space(buffer: &buffer, tracker: tracker)
                return try parseBodyFieldParam_singlePair(buffer: &buffer, tracker: tracker)
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }

        return try oneOf([
            parseBodyFieldParam_pairs,
            parseBodyFieldParam_nil,
        ], buffer: &buffer, tracker: tracker)
    }

    // body-type-1part = (body-type-basic / body-type-msg / body-type-text)
    //                   [SP body-ext-1part]
    static func parseBodyKindSinglePart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Singlepart {
        func parseBodyKindSinglePart_extension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Singlepart.Extension? {
            try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseBodyExtSinglePart(buffer: &buffer, tracker: tracker)
            }
        }

        func parseBodyKindSinglePart_basic(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Singlepart {
            let media = try self.parseMediaBasic(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let fields = try self.parseBodyFields(buffer: &buffer, tracker: tracker)
            let ext = try parseBodyKindSinglePart_extension(buffer: &buffer, tracker: tracker)
            return BodyStructure.Singlepart(type: .basic(media), fields: fields, extension: ext)
        }

        func parseBodyKindSinglePart_message(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Singlepart {
            let mediaMessage = try self.parseMediaMessage(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let fields = try self.parseBodyFields(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let envelope = try self.parseEnvelope(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let body = try self.parseBody(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let fieldLines = try self.parseNumber(buffer: &buffer, tracker: tracker)
            let message = BodyStructure.Singlepart.Message(message: mediaMessage, envelope: envelope, body: body, fieldLines: fieldLines)
            let ext = try parseBodyKindSinglePart_extension(buffer: &buffer, tracker: tracker)
            return BodyStructure.Singlepart(type: .message(message), fields: fields, extension: ext)
        }

        func parseBodyKindSinglePart_text(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Singlepart {
            let media = try self.parseMediaText(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let fields = try self.parseBodyFields(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let fieldLines = try self.parseNumber(buffer: &buffer, tracker: tracker)
            let text = BodyStructure.Singlepart.Text(mediaText: media, lineCount: fieldLines)
            let ext = try parseBodyKindSinglePart_extension(buffer: &buffer, tracker: tracker)
            return BodyStructure.Singlepart(type: .text(text), fields: fields, extension: ext)
        }

        return try oneOf([
            parseBodyKindSinglePart_message,
            parseBodyKindSinglePart_text,
            parseBodyKindSinglePart_basic,
        ], buffer: &buffer, tracker: tracker)
    }

    // body-type-mpart = 1*body SP media-subtype
    //                   [SP body-ext-mpart]
    static func parseBodyKindMultipart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Multipart {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> BodyStructure.Multipart in
            let parts = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> BodyStructure in
                try? GrammarParser.space(buffer: &buffer, tracker: tracker)
                return try self.parseBody(buffer: &buffer, tracker: tracker)
            }
            try space(buffer: &buffer, tracker: tracker)
            let media = try self.parseMediaSubtype(buffer: &buffer, tracker: tracker)
            let ext = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> BodyStructure.Multipart.Extension in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseBodyExtMpart(buffer: &buffer, tracker: tracker)
            }
            return BodyStructure.Multipart(parts: parts, mediaSubtype: media, extension: ext)
        }
    }

    // capability      = ("AUTH=" auth-type) / atom / "MOVE" / "ENABLE" / "FILTERS"
    static func parseCapability(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Capability {
        let string = try self.parseAtom(buffer: &buffer, tracker: tracker)
        return Capability(string)
    }

    // capability-data = "CAPABILITY" *(SP capability) SP "IMAP4rev1"
    //                   *(SP capability)
    static func parseCapabilityData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Capability] {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [Capability] in
            try fixedString("CAPABILITY", buffer: &buffer, tracker: tracker)
            return try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseCapability(buffer: &buffer, tracker: tracker)
            }
        }
    }

    // charset          = atom / quoted
    static func parseCharset(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        func parseCharset_atom(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
            try parseAtom(buffer: &buffer, tracker: tracker)
        }

        func parseCharset_quoted(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
            var buffer = try parseQuoted(buffer: &buffer, tracker: tracker)
            guard let string = buffer.readString(length: buffer.readableBytes) else {
                throw ParserError(hint: "Couldn't read string from buffer")
            }
            return string
        }

        return try oneOf([
            parseCharset_atom,
            parseCharset_quoted,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseChangedSinceModifier(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ChangedSinceModifier {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ChangedSinceModifier in
            try fixedString("CHANGEDSINCE ", buffer: &buffer, tracker: tracker)
            let val = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            return .init(modificationSequence: val)
        }
    }

    static func parseUnchangedSinceModifier(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UnchangedSinceModifier {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> UnchangedSinceModifier in
            try fixedString("UNCHANGEDSINCE ", buffer: &buffer, tracker: tracker)
            let val = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            return .init(modificationSequence: val)
        }
    }

    // childinfo-extended-item =  "CHILDINFO" SP "("
    //             list-select-base-opt-quoted
    //             *(SP list-select-base-opt-quoted) ")"
    static func parseChildinfoExtendedItem(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [ListSelectBaseOption] {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [ListSelectBaseOption] in
            try fixedString("CHILDINFO (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseListSelectBaseOptionQuoted(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ListSelectBaseOption in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseListSelectBaseOptionQuoted(buffer: &buffer, tracker: tracker)
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // command         = tag SP (command-any / command-auth / command-nonauth /
    //                   command-select) CRLF
    static func parseCommand(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedCommand {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let tag = try self.parseTag(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let type = try oneOf([
                self.parseCommandAny,
                self.parseCommandAuth,
                self.parseCommandNonauth,
                self.parseCommandSelect,
                self.parseCommandQuota,
            ], buffer: &buffer, tracker: tracker)
            return TaggedCommand(tag: tag, command: type)
        }
    }

    // command-any     = "CAPABILITY" / "LOGOUT" / "NOOP" / enable / x-command / id
    static func parseCommandAny(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        func parseCommandAny_capability(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try fixedString("CAPABILITY", buffer: &buffer, tracker: tracker)
            return .capability
        }

        func parseCommandAny_logout(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try fixedString("LOGOUT", buffer: &buffer, tracker: tracker)
            return .logout
        }

        func parseCommandAny_noop(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try fixedString("NOOP", buffer: &buffer, tracker: tracker)
            return .noop
        }

        func parseCommandAny_id(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            let id = try self.parseID(buffer: &buffer, tracker: tracker)
            return .id(id)
        }

        func parseCommandAny_enable(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            let enable = try self.parseEnable(buffer: &buffer, tracker: tracker)
            return enable
        }

        return try oneOf([
            parseCommandAny_noop,
            parseCommandAny_logout,
            parseCommandAny_capability,
            parseCommandAny_id,
            parseCommandAny_enable,
        ], buffer: &buffer, tracker: tracker)
    }

    // command-auth    = append / create / delete / examine / list / lsub /
    //                   Namespace-Command /
    //                   rename / select / status / subscribe / unsubscribe /
    //                   idle
    // RFC 6237
    // command-auth =/  esearch
    static func parseCommandAuth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        func parseCommandAuth_getMetadata(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try fixedString("GETMETADATA", buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let options = try optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> [MetadataOption] in
                let options = try self.parseMetadataOptions(buffer: &buffer, tracker: tracker)
                try space(buffer: &buffer, tracker: tracker)
                return options
            }) ?? []
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let entries = try self.parseEntries(buffer: &buffer, tracker: tracker)
            return .getMetadata(options: options, mailbox: mailbox, entries: entries)
        }

        func parseCommandAuth_setMetadata(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try fixedString("SETMETADATA ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let list = try self.parseEntryValues(buffer: &buffer, tracker: tracker)
            return .setMetadata(mailbox: mailbox, entries: list)
        }

        func parseCommandAuth_resetKey(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try fixedString("RESETKEY", buffer: &buffer, tracker: tracker)
            let mailbox = try optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> MailboxName in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseMailbox(buffer: &buffer, tracker: tracker)
            })

            // don't bother parsing mechanisms if there's no mailbox
            guard mailbox != nil else {
                return .resetKey(mailbox: nil, mechanisms: [])
            }

            let mechanisms = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> UAuthMechanism in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseUAuthMechanism(buffer: &buffer, tracker: tracker)
            })
            return .resetKey(mailbox: mailbox, mechanisms: mechanisms)
        }

        func parseCommandAuth_genURLAuth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try fixedString("GENURLAUTH", buffer: &buffer, tracker: tracker)
            var array = [try self.parseURLRumpMechanism(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: self.parseURLRumpMechanism)
            return .genURLAuth(array)
        }

        func parseCommandAuth_urlFetch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try fixedString("URLFETCH", buffer: &buffer, tracker: tracker)
            let array = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> ByteBuffer in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseAString(buffer: &buffer, tracker: tracker)
            })
            return .urlFetch(array)
        }

        return try oneOf([
            self.parseCreate,
            self.parseDelete,
            self.parseExamine,
            self.parseList,
            self.parseLSUB,
            self.parseRename,
            self.parseSelect,
            self.parseStatus,
            self.parseSubscribe,
            self.parseUnsubscribe,
            self.parseIdleStart,
            self.parseNamespaceCommand,
            parseCommandAuth_getMetadata,
            parseCommandAuth_setMetadata,
            parseEsearch,
            parseCommandAuth_resetKey,
            parseCommandAuth_genURLAuth,
            parseCommandAuth_urlFetch,
        ], buffer: &buffer, tracker: tracker)
    }

    // command-nonauth = login / authenticate / "STARTTLS"
    static func parseCommandNonauth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        func parseCommandNonauth_starttls(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try fixedString("STARTTLS", buffer: &buffer, tracker: tracker)
            return .starttls
        }

        return try oneOf([
            self.parseLogin,
            self.parseAuthenticate,
            parseCommandNonauth_starttls,
        ], buffer: &buffer, tracker: tracker)
    }

    // command-select  = "CHECK" / "CLOSE" / "UNSELECT" / "EXPUNGE" / copy / fetch / store /
    //                   uid / search / move
    // RFC 6237
    // command-select =/  esearch
    static func parseCommandSelect(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        func parseCommandSelect_check(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try fixedString("CHECK", buffer: &buffer, tracker: tracker)
            return .check
        }

        func parseCommandSelect_close(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try fixedString("CLOSE", buffer: &buffer, tracker: tracker)
            return .close
        }

        func parseCommandSelect_expunge(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try fixedString("EXPUNGE", buffer: &buffer, tracker: tracker)
            return .expunge
        }

        func parseCommandSelect_unselect(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try fixedString("UNSELECT", buffer: &buffer, tracker: tracker)
            return .unselect
        }

        return try oneOf([
            parseCommandSelect_check,
            parseCommandSelect_close,
            parseCommandSelect_expunge,
            parseCommandSelect_unselect,
            self.parseCopy,
            self.parseFetch,
            self.parseStore,
            self.parseUid,
            self.parseSearch,
            self.parseMove,
            self.parseEsearch,
        ], buffer: &buffer, tracker: tracker)
    }

    // condstore-param = "CONDSTORE"
    static func parseConditionalStoreParameter(buffer: inout ByteBuffer, tracker: StackTracker) throws {
        try fixedString("CONDSTORE", buffer: &buffer, tracker: tracker)
    }

    // continue-req    = "+" SP (resp-text / base64) CRLF
    static func parseContinueRequest(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ContinueRequest {
        func parseContinueReq_responseText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ContinueRequest {
            .responseText(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        func parseContinueReq_base64(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ContinueRequest {
            .data(try self.parseBase64(buffer: &buffer, tracker: tracker))
        }

        return try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ContinueRequest in
            try fixedString("+", buffer: &buffer, tracker: tracker)
            // Allow no space and no additional text after "+":
            let continueReq: ContinueRequest
            if try optional(buffer: &buffer, tracker: tracker, parser: space) != nil {
                continueReq = try oneOf([
                    parseContinueReq_base64,
                    parseContinueReq_responseText,
                ], buffer: &buffer, tracker: tracker)
            } else {
                continueReq = .responseText(ResponseText(code: nil, text: ""))
            }
            try newline(buffer: &buffer, tracker: tracker)
            return continueReq
        }
    }

    // copy            = "COPY" SP sequence-set SP mailbox
    static func parseCopy(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("COPY ", buffer: &buffer, tracker: tracker)
            let sequence = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            try fixedString(" ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .copy(sequence, mailbox)
        }
    }

    // create          = "CREATE" SP mailbox [create-params]
    static func parseCreate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("CREATE ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try optional(buffer: &buffer, tracker: tracker, parser: self.parseCreateParameters) ?? []
            return .create(mailbox, params)
        }
    }

    // create-param = create-param-name [SP create-param-value]

    static func parseCreateParameters(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [CreateParameter] {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try fixedString(" (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseCreateParameter(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { buffer, tracker in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseCreateParameter(buffer: &buffer, tracker: tracker)
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    static func parseCreateParameter(buffer: inout ByteBuffer, tracker: StackTracker) throws -> CreateParameter {
        func parseCreateParameter_parameter(buffer: inout ByteBuffer, tracker: StackTracker) throws -> CreateParameter {
            .labelled(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        func parseCreateParameter_specialUse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> CreateParameter {
            try fixedString("USE (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseUseAttribute(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseUseAttribute(buffer: &buffer, tracker: tracker)
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return .attributes(array)
        }

        return try oneOf([
            parseCreateParameter_specialUse,
            parseCreateParameter_parameter,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseParameter(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Parameter {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let name = try self.parseParameterName(buffer: &buffer, tracker: tracker)
            let value = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ParameterValue in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            }
            return .init(name: name, value: value)
        }
    }

    static func parseUseAttribute(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UseAttribute {
        func parseUseAttribute_fixed(expected: String, returning: UseAttribute, buffer: inout ByteBuffer, tracker: StackTracker) throws -> UseAttribute {
            try fixedString(expected, buffer: &buffer, tracker: tracker)
            return returning
        }

        func parseUseAttribute_all(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\All", returning: .all, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_archive(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Archive", returning: .archive, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_drafts(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Drafts", returning: .drafts, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_flagged(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Flagged", returning: .flagged, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_junk(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Junk", returning: .junk, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_sent(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Sent", returning: .sent, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_trash(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UseAttribute {
            try parseUseAttribute_fixed(expected: "\\Trash", returning: .trash, buffer: &buffer, tracker: tracker)
        }

        func parseUseAttribute_other(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UseAttribute {
            try fixedString("\\", buffer: &buffer, tracker: tracker)
            let att = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init(rawValue: "\\" + att)
        }

        return try oneOf([
            parseUseAttribute_all,
            parseUseAttribute_archive,
            parseUseAttribute_drafts,
            parseUseAttribute_flagged,
            parseUseAttribute_junk,
            parseUseAttribute_sent,
            parseUseAttribute_trash,
            parseUseAttribute_other,
        ], buffer: &buffer, tracker: tracker)
    }

    // date            = date-text / DQUOTE date-text DQUOTE
    static func parseDate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Date {
        func parseDateText_quoted(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Date {
            try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                try fixedString("\"", buffer: &buffer, tracker: tracker)
                let date = try self.parseDateText(buffer: &buffer, tracker: tracker)
                try fixedString("\"", buffer: &buffer, tracker: tracker)
                return date
            }
        }

        return try oneOf([
            parseDateText,
            parseDateText_quoted,
        ], buffer: &buffer, tracker: tracker)
    }

    // date-day        = 1*2DIGIT
    static func parseDateDay(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        let (num, size) = try ParserLibrary.parseUnsignedInteger(buffer: &buffer, tracker: tracker)
        guard size <= 2 else {
            throw ParserError(hint: "Expected 1 or 2 bytes, got \(size)")
        }
        return num
    }

    // date-day-fixed  = (SP DIGIT) / 2DIGIT
    static func parseDateDayFixed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        func parseDateDayFixed_spaced(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
            try fixedString(" ", buffer: &buffer, tracker: tracker)
            return try self.parseNDigits(buffer: &buffer, tracker: tracker, bytes: 1)
        }

        return try oneOf([
            parseDateDayFixed_spaced,
            parse2Digit,
        ], buffer: &buffer, tracker: tracker)
    }

    // date-month      = "Jan" / "Feb" / "Mar" / "Apr" / "May" / "Jun" /
    //                   "Jul" / "Aug" / "Sep" / "Oct" / "Nov" / "Dec"
    static func parseDateMonth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        let string = try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            isalnum(Int32(char)) != 0
        }
        guard let month = Date.month(text: string.lowercased()) else {
            throw ParserError(hint: "No month match for \(string)")
        }
        return month
    }

    // date-text       = date-day "-" date-month "-" date-year
    static func parseDateText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Date {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let day = try self.parseDateDay(buffer: &buffer, tracker: tracker)
            try fixedString("-", buffer: &buffer, tracker: tracker)
            let month = try self.parseDateMonth(buffer: &buffer, tracker: tracker)
            try fixedString("-", buffer: &buffer, tracker: tracker)
            let year = try self.parse4Digit(buffer: &buffer, tracker: tracker)
            guard let date = Date(year: year, month: month, day: day) else {
                throw ParserError(hint: "Invalid date components \(year) \(month) \(day)")
            }
            return date
        }
    }

    // date-time       = DQUOTE date-day-fixed "-" date-month "-" date-year
    //                   SP time SP zone DQUOTE
    static func parseInternalDate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> InternalDate {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try fixedString("\"", buffer: &buffer, tracker: tracker)
            let day = try self.parseDateDayFixed(buffer: &buffer, tracker: tracker)
            try fixedString("-", buffer: &buffer, tracker: tracker)
            let month = try self.parseDateMonth(buffer: &buffer, tracker: tracker)
            try fixedString("-", buffer: &buffer, tracker: tracker)
            let year = try self.parse4Digit(buffer: &buffer, tracker: tracker)
            try fixedString(" ", buffer: &buffer, tracker: tracker)

            // time            = 2DIGIT ":" 2DIGIT ":" 2DIGIT
            let hour = try self.parse2Digit(buffer: &buffer, tracker: tracker)
            try fixedString(":", buffer: &buffer, tracker: tracker)
            let minute = try self.parse2Digit(buffer: &buffer, tracker: tracker)
            try fixedString(":", buffer: &buffer, tracker: tracker)
            let second = try self.parse2Digit(buffer: &buffer, tracker: tracker)

            try fixedString(" ", buffer: &buffer, tracker: tracker)

            func splitZoneMinutes(_ raw: Int) -> Int? {
                guard raw >= 0 else { return nil }
                let minutes = raw % 100
                let hours = (raw - minutes) / 100
                guard minutes <= 60, hour <= 24 else { return nil }
                return hours * 60 + minutes
            }

            // zone            = ("+" / "-") 4DIGIT
            func parseZonePositive(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
                try fixedString("+", buffer: &buffer, tracker: tracker)
                let num = try self.parse4Digit(buffer: &buffer, tracker: tracker)
                guard let zone = splitZoneMinutes(num) else {
                    throw ParserError(hint: "Building TimeZone from \(num) failed")
                }
                return zone
            }

            func parseZoneNegative(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
                try fixedString("-", buffer: &buffer, tracker: tracker)
                let num = try self.parse4Digit(buffer: &buffer, tracker: tracker)
                guard let zone = splitZoneMinutes(num) else {
                    throw ParserError(hint: "Building TimeZone from \(num) failed")
                }
                return -zone
            }

            let zone = try oneOf([
                parseZonePositive,
                parseZoneNegative,
            ], buffer: &buffer, tracker: tracker)

            try fixedString("\"", buffer: &buffer, tracker: tracker)
            guard let d = InternalDate(year: year, month: month, day: day, hour: hour, minute: minute, second: second, zoneMinutes: zone) else {
                throw ParserError(hint: "Invalid internal date.")
            }
            return d
        }
    }

    // delete          = "DELETE" SP mailbox
    static func parseDelete(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("DELETE ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .delete(mailbox)
        }
    }

    // eitem-vendor-tag =  vendor-token "-" atom
    static func parseEitemVendorTag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EItemVendorTag {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EItemVendorTag in
            let token = try self.parseVendorToken(buffer: &buffer, tracker: tracker)
            try fixedString("-", buffer: &buffer, tracker: tracker)
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return EItemVendorTag(token: token, atom: atom)
        }
    }

    // enable          = "ENABLE" 1*(SP capability)
    static func parseEnable(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("ENABLE", buffer: &buffer, tracker: tracker)
            let capabilities = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Capability in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseCapability(buffer: &buffer, tracker: tracker)
            }
            return .enable(capabilities)
        }
    }

    static func parseEncodedAuthenticationType(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EncodedAuthenticationType {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EncodedAuthenticationType in
            let array = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: self.parseAChar).reduce([], +)
            return .init(authType: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    static func parseEncodedMailbox(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EncodedMailbox {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EncodedMailbox in
            let array = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: self.parseBChar).reduce([], +)
            return .init(mailbox: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    static func parseEncodedSearch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EncodedSearch {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EncodedSearch in
            let array = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: self.parseBChar).reduce([], +)
            return .init(query: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    static func parseEncodedSection(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EncodedSection {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EncodedSection in
            let array = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: self.parseBChar).reduce([], +)
            return .init(section: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    static func parseEncodedUser(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EncodedUser {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EncodedUser in
            let array = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: self.parseAChar).reduce([], +)
            return .init(data: String(decoding: array, as: Unicode.UTF8.self))
        }
    }

    static func parseEncodedURLAuth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EncodedURLAuth {
        try composite(buffer: &buffer, tracker: tracker) { buffer, _ -> EncodedURLAuth in
            guard let bytes = buffer.readSlice(length: 32) else {
                throw _IncompleteMessage()
            }
            guard bytes.readableBytesView.allSatisfy({ $0.isHexCharacter }) else {
                throw ParserError(hint: "Found invalid character in \(String(buffer: bytes))")
            }
            return .init(data: String(buffer: bytes))
        }
    }

    // enable-data     = "ENABLED" *(SP capability)
    static func parseEnableData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Capability] {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [Capability] in
            try fixedString("ENABLED", buffer: &buffer, tracker: tracker)
            return try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Capability in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseCapability(buffer: &buffer, tracker: tracker)
            }
        }
    }

    static func parseEntryValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryValue {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EntryValue in
            let name = try self.parseAString(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let value = try self.parseMetadataValue(buffer: &buffer, tracker: tracker)
            return .init(name: name, value: value)
        }
    }

    static func parseEntryValues(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [EntryValue] {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [EntryValue] in
            try fixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseEntryValue(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { buffer, tracker in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseEntryValue(buffer: &buffer, tracker: tracker)
            })
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    static func parseEntries(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [ByteBuffer] {
        func parseEntries_singleUnbracketed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [ByteBuffer] {
            [try self.parseAString(buffer: &buffer, tracker: tracker)]
        }

        func parseEntries_bracketed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [ByteBuffer] {
            try fixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseAString(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { buffer, tracker in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseAString(buffer: &buffer, tracker: tracker)
            })
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }

        return try oneOf([
            parseEntries_singleUnbracketed,
            parseEntries_bracketed,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseEntryList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [ByteBuffer] {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            var array = [try self.parseAString(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { buffer, tracker in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseAString(buffer: &buffer, tracker: tracker)
            })
            return array
        }
    }

    // envelope        = "(" env-date SP env-subject SP env-from SP
    //                   env-sender SP env-reply-to SP env-to SP env-cc SP
    //                   env-bcc SP env-in-reply-to SP env-message-id ")"
    static func parseEnvelope(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Envelope {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Envelope in
            try fixedString("(", buffer: &buffer, tracker: tracker)
            let date = try self.parseNString(buffer: &buffer, tracker: tracker).flatMap { String(buffer: $0) }
            try space(buffer: &buffer, tracker: tracker)
            let subject = try self.parseNString(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let from = try self.parseOptionalEnvelopeAddresses(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let sender = try self.parseOptionalEnvelopeAddresses(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let replyTo = try self.parseOptionalEnvelopeAddresses(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let to = try self.parseOptionalEnvelopeAddresses(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let cc = try self.parseOptionalEnvelopeAddresses(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let bcc = try self.parseOptionalEnvelopeAddresses(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let inReplyTo = try self.parseNString(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let messageID = try self.parseNString(buffer: &buffer, tracker: tracker).flatMap { String(buffer: $0) }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return Envelope(
                date: date,
                subject: subject,
                from: from,
                sender: sender,
                reply: replyTo,
                to: to,
                cc: cc,
                bcc: bcc,
                inReplyTo: inReplyTo,
                messageID: messageID
            )
        }
    }

    static func parseEntryFlagName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryFlagName {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> EntryFlagName in
            try fixedString("\"/flags/", buffer: &buffer, tracker: tracker)
            let flag = try self.parseAttributeFlag(buffer: &buffer, tracker: tracker)
            try fixedString("\"", buffer: &buffer, tracker: tracker)
            return .init(flag: flag)
        }
    }

    // entry-type-req = entry-type-resp / all
    static func parseEntryKindRequest(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryKindRequest {
        func parseEntryKindRequest_all(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryKindRequest {
            try fixedString("all", buffer: &buffer, tracker: tracker)
            return .all
        }

        func parseEntryKindRequest_private(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryKindRequest {
            try fixedString("priv", buffer: &buffer, tracker: tracker)
            return .private
        }

        func parseEntryKindRequest_shared(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryKindRequest {
            try fixedString("shared", buffer: &buffer, tracker: tracker)
            return .shared
        }

        return try oneOf([
            parseEntryKindRequest_all,
            parseEntryKindRequest_private,
            parseEntryKindRequest_shared,
        ], buffer: &buffer, tracker: tracker)
    }

    // entry-type-resp = "priv" / "shared"
    static func parseEntryKindResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryKindResponse {
        func parseEntryKindResponse_private(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryKindResponse {
            try fixedString("priv", buffer: &buffer, tracker: tracker)
            return .private
        }

        func parseEntryKindResponse_shared(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryKindResponse {
            try fixedString("shared", buffer: &buffer, tracker: tracker)
            return .shared
        }

        return try oneOf([
            parseEntryKindResponse_private,
            parseEntryKindResponse_shared,
        ], buffer: &buffer, tracker: tracker)
    }

    // esearch-response  = "ESEARCH" [search-correlator] [SP "UID"]
    //                     *(SP search-return-data)
    static func parseEsearchResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ESearchResponse {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try fixedString("ESEARCH", buffer: &buffer, tracker: tracker)
            let correlator = try optional(buffer: &buffer, tracker: tracker, parser: self.parseSearchCorrelator)
            let uid = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try fixedString(" UID", buffer: &buffer, tracker: tracker)
                return true
            } ?? false
            let searchReturnData = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> SearchReturnData in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseSearchReturnData(buffer: &buffer, tracker: tracker)
            }
            return ESearchResponse(correlator: correlator, uid: uid, returnData: searchReturnData)
        }
    }

    // examine         = "EXAMINE" SP mailbox [select-params
    static func parseExamine(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("EXAMINE ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try optional(buffer: &buffer, tracker: tracker, parser: self.parseParameters) ?? []
            return .examine(mailbox, params)
        }
    }

    static func parseExpire(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Expire {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Expire in
            try fixedString(";EXPIRE=", buffer: &buffer, tracker: tracker)
            let dateTime = try self.parseFullDateTime(buffer: &buffer, tracker: tracker)
            return .init(dateTime: dateTime)
        }
    }

    // fetch           = "FETCH" SP sequence-set SP ("ALL" / "FULL" / "FAST" /
    //                   fetch-att / "(" fetch-att *(SP fetch-att) ")") [fetch-modifiers]
    static func parseFetch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("FETCH ", buffer: &buffer, tracker: tracker)
            let sequence = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let att = try parseFetch_type(buffer: &buffer, tracker: tracker)
            let modifiers = try optional(buffer: &buffer, tracker: tracker, parser: self.parseParameters) ?? []
            return .fetch(sequence, att, modifiers)
        }
    }

    static func parseAccess(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Access {
        func parseAccess_submit(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Access {
            try fixedString("submit+", buffer: &buffer, tracker: tracker)
            return .submit(try self.parseEncodedUser(buffer: &buffer, tracker: tracker))
        }

        func parseAccess_user(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Access {
            try fixedString("user+", buffer: &buffer, tracker: tracker)
            return .user(try self.parseEncodedUser(buffer: &buffer, tracker: tracker))
        }

        func parseAccess_authuser(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Access {
            try fixedString("authuser", buffer: &buffer, tracker: tracker)
            return .authUser
        }

        func parseAccess_anonymous(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Access {
            try fixedString("anonymous", buffer: &buffer, tracker: tracker)
            return .anonymous
        }

        return try oneOf([
            parseAccess_submit,
            parseAccess_user,
            parseAccess_authuser,
            parseAccess_anonymous,
        ], buffer: &buffer, tracker: tracker)
    }

    fileprivate static func parseFetch_type(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [FetchAttribute] {
        func parseFetch_type_all(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [FetchAttribute] {
            try fixedString("ALL", buffer: &buffer, tracker: tracker)
            return [.flags, .internalDate, .rfc822Size, .envelope]
        }

        func parseFetch_type_fast(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [FetchAttribute] {
            try fixedString("FAST", buffer: &buffer, tracker: tracker)
            return [.flags, .internalDate, .rfc822Size]
        }

        func parseFetch_type_full(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [FetchAttribute] {
            try fixedString("FULL", buffer: &buffer, tracker: tracker)
            return [.flags, .internalDate, .rfc822Size, .envelope, .bodyStructure(extensions: false)]
        }

        func parseFetch_type_singleAtt(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [FetchAttribute] {
            [try self.parseFetchAttribute(buffer: &buffer, tracker: tracker)]
        }

        func parseFetch_type_multiAtt(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [FetchAttribute] {
            try fixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseFetchAttribute(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> FetchAttribute in
                try fixedString(" ", buffer: &buffer, tracker: tracker)
                return try self.parseFetchAttribute(buffer: &buffer, tracker: tracker)
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }

        return try oneOf([
            parseFetch_type_all,
            parseFetch_type_full,
            parseFetch_type_fast,
            parseFetch_type_singleAtt,
            parseFetch_type_multiAtt,
        ], buffer: &buffer, tracker: tracker)
    }

    // fetch-att       = "ENVELOPE" / "FLAGS" / "INTERNALDATE" /
    //                   "RFC822.SIZE" /
    //                   "BODY" ["STRUCTURE"] / "UID" /
    //                   "BODY" section [partial] /
    //                   "BODY.PEEK" section [partial] /
    //                   "BINARY" [".PEEK"] section-binary [partial] /
    //                   "BINARY.SIZE" section-binary
    // TODO: rev2
    static func parseFetchAttribute(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
        func parseFetchAttribute_envelope(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try fixedString("ENVELOPE", buffer: &buffer, tracker: tracker)
            return .envelope
        }

        func parseFetchAttribute_flags(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try fixedString("FLAGS", buffer: &buffer, tracker: tracker)
            return .flags
        }

        func parseFetchAttribute_internalDate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try fixedString("INTERNALDATE", buffer: &buffer, tracker: tracker)
            return .internalDate
        }

        func parseFetchAttribute_UID(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try fixedString("UID", buffer: &buffer, tracker: tracker)
            return .uid
        }

        func parseFetchAttribute_rfc822(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            func parseFetchAttribute_rfc822Size(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
                try fixedString("RFC822.SIZE", buffer: &buffer, tracker: tracker)
                return .rfc822Size
            }

            func parseFetchAttribute_rfc822Header(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
                try fixedString("RFC822.HEADER", buffer: &buffer, tracker: tracker)
                return .rfc822Header
            }

            func parseFetchAttribute_rfc822Text(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
                try fixedString("RFC822.TEXT", buffer: &buffer, tracker: tracker)
                return .rfc822Text
            }

            func parseFetchAttribute_rfc822(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
                try fixedString("RFC822", buffer: &buffer, tracker: tracker)
                return .rfc822
            }

            return try oneOf([
                parseFetchAttribute_rfc822Size,
                parseFetchAttribute_rfc822Header,
                parseFetchAttribute_rfc822Text,
                parseFetchAttribute_rfc822,
            ], buffer: &buffer, tracker: tracker)
        }

        func parseFetchAttribute_body(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try fixedString("BODY", buffer: &buffer, tracker: tracker)
            let extensions: Bool = {
                do {
                    try fixedString("STRUCTURE", buffer: &buffer, tracker: tracker)
                    return true
                } catch {
                    return false
                }
            }()
            return .bodyStructure(extensions: extensions)
        }

        func parseFetchAttribute_bodySection(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try fixedString("BODY", buffer: &buffer, tracker: tracker)
            let section = try self.parseSection(buffer: &buffer, tracker: tracker)
            let chevronNumber = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ClosedRange<Int> in
                try self.parsePartial(buffer: &buffer, tracker: tracker)
            }
            return .bodySection(peek: false, section, chevronNumber)
        }

        func parseFetchAttribute_bodyPeekSection(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try fixedString("BODY.PEEK", buffer: &buffer, tracker: tracker)
            let section = try self.parseSection(buffer: &buffer, tracker: tracker)
            let chevronNumber = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ClosedRange<Int> in
                try self.parsePartial(buffer: &buffer, tracker: tracker)
            }
            return .bodySection(peek: true, section, chevronNumber)
        }

        func parseFetchAttribute_modificationSequence(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            .modificationSequenceValue(try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker))
        }

        func parseFetchAttribute_binary(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            func parsePeek(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Bool {
                let save = buffer
                do {
                    try fixedString(".PEEK", buffer: &buffer, tracker: tracker)
                    return true
                } catch {
                    buffer = save
                    return false
                }
            }

            try fixedString("BINARY", buffer: &buffer, tracker: tracker)
            let peek = try parsePeek(buffer: &buffer, tracker: tracker)
            let sectionBinary = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            let partial = try optional(buffer: &buffer, tracker: tracker, parser: self.parsePartial)
            return .binary(peek: peek, section: sectionBinary, partial: partial)
        }

        func parseFetchAttribute_binarySize(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try fixedString("BINARY.SIZE", buffer: &buffer, tracker: tracker)
            let sectionBinary = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            return .binarySize(section: sectionBinary)
        }

        func parseFetchAttribute_gmailMessageID(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try fixedString("X-GM-MSGID", buffer: &buffer, tracker: tracker)
            return .gmailMessageID
        }

        func parseFetchAttribute_gmailThreadID(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try fixedString("X-GM-THRID", buffer: &buffer, tracker: tracker)
            return .gmailThreadID
        }

        func parseFetchAttribute_gmailLabels(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try fixedString("X-GM-LABELS", buffer: &buffer, tracker: tracker)
            return .gmailLabels
        }

        return try oneOf([
            parseFetchAttribute_envelope,
            parseFetchAttribute_flags,
            parseFetchAttribute_internalDate,
            parseFetchAttribute_UID,
            parseFetchAttribute_rfc822,
            parseFetchAttribute_bodySection,
            parseFetchAttribute_bodyPeekSection,
            parseFetchAttribute_body,
            parseFetchAttribute_modificationSequence,
            parseFetchAttribute_binary,
            parseFetchAttribute_binarySize,
            parseFetchAttribute_gmailMessageID,
            parseFetchAttribute_gmailThreadID,
            parseFetchAttribute_gmailLabels,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseFetchModificationResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchModificationResponse {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> FetchModificationResponse in
            try fixedString("MODSEQ (", buffer: &buffer, tracker: tracker)
            let val = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return .init(modifierSequenceValue: val)
        }
    }

    // filter-name = 1*<any ATOM-CHAR except "/">
    static func parseFilterName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            char.isAtomChar && char != UInt8(ascii: "/")
        }
    }

    // flag            = "\Answered" / "\Flagged" / "\Deleted" /
    //                   "\Seen" / "\Draft" / flag-keyword / flag-extension
    static func parseFlag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
        func parseFlag_answered(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
            try fixedString("\\Answered", buffer: &buffer, tracker: tracker)
            return .answered
        }

        func parseFlag_flagged(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
            try fixedString("\\Flagged", buffer: &buffer, tracker: tracker)
            return .flagged
        }

        func parseFlag_deleted(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
            try fixedString("\\Deleted", buffer: &buffer, tracker: tracker)
            return .deleted
        }

        func parseFlag_seen(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
            try fixedString("\\Seen", buffer: &buffer, tracker: tracker)
            return .seen
        }

        func parseFlag_draft(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
            try fixedString("\\Draft", buffer: &buffer, tracker: tracker)
            return .draft
        }

        func parseFlag_keyword(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
            let word = try self.parseFlagKeyword(buffer: &buffer, tracker: tracker)
            return .keyword(word)
        }

        func parseFlag_extension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
            let word = try self.parseFlagExtension(buffer: &buffer, tracker: tracker)
            return .extension(word)
        }

        return try oneOf([
            parseFlag_seen,
            parseFlag_draft,
            parseFlag_answered,
            parseFlag_flagged,
            parseFlag_deleted,
            parseFlag_keyword,
            parseFlag_extension,
        ], buffer: &buffer, tracker: tracker)
    }

    // flag-extension  = "\" atom
    static func parseFlagExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> String in
            try fixedString("\\", buffer: &buffer, tracker: tracker)
            let string = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return "\\\(string)"
        }
    }

    // flag-keyword    = "$MDNSent" / "$Forwarded" / atom
    static func parseFlagKeyword(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag.Keyword {
        let string = try self.parseAtom(buffer: &buffer, tracker: tracker)
        return Flag.Keyword(string)
    }

    // flag-list       = "(" [flag *(SP flag)] ")"
    static func parseFlagList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Flag] {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try fixedString("(", buffer: &buffer, tracker: tracker)
            let flags = try optional(buffer: &buffer, tracker: tracker) { (buffer, _) -> [Flag] in
                var output = [try self.parseFlag(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { buffer, tracker in
                    try fixedString(" ", buffer: &buffer, tracker: tracker)
                    return try self.parseFlag(buffer: &buffer, tracker: tracker)
                }
                return output
            } ?? []
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return flags
        }
    }

    // flag-perm       = flag / "\*"
    static func parseFlagPerm(buffer: inout ByteBuffer, tracker: StackTracker) throws -> PermanentFlag {
        func parseFlagPerm_wildcard(buffer: inout ByteBuffer, tracker: StackTracker) throws -> PermanentFlag {
            try fixedString("\\*", buffer: &buffer, tracker: tracker)
            return .wildcard
        }

        func parseFlagPerm_flag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> PermanentFlag {
            .flag(try self.parseFlag(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseFlagPerm_wildcard,
            parseFlagPerm_flag,
        ], buffer: &buffer, tracker: tracker)
    }

    // greeting        = "*" SP (resp-cond-auth / resp-cond-bye) CRLF
    static func parseGreeting(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Greeting {
        func parseGreeting_auth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Greeting {
            .auth(try self.parseResponseConditionalAuth(buffer: &buffer, tracker: tracker))
        }

        func parseGreeting_bye(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Greeting {
            .bye(try self.parseResponseConditionalBye(buffer: &buffer, tracker: tracker))
        }

        return try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Greeting in
            try fixedString("* ", buffer: &buffer, tracker: tracker)
            let greeting = try oneOf([
                parseGreeting_auth,
                parseGreeting_bye,
            ], buffer: &buffer, tracker: tracker)
            try newline(buffer: &buffer, tracker: tracker)
            return greeting
        }
    }

    // header-fld-name = astring
    static func parseHeaderFieldName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        var buffer = try self.parseAString(buffer: &buffer, tracker: tracker)
        return buffer.readString(length: buffer.readableBytes)!
    }

    // header-list     = "(" header-fld-name *(SP header-fld-name) ")"
    static func parseHeaderList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [String] {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [String] in
            try fixedString("(", buffer: &buffer, tracker: tracker)
            var output = [try self.parseHeaderFieldName(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { (buffer, tracker) -> String in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseHeaderFieldName(buffer: &buffer, tracker: tracker)
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return output
        }
    }

    static func parseICommand(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ICommand {
        func parseICommand_list(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ICommand {
            .messageList(try self.parseIMessageList(buffer: &buffer, tracker: tracker))
        }

        func parseICommand_part(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ICommand {
            let part = try self.parseIMessagePart(buffer: &buffer, tracker: tracker)
            let auth = try optional(buffer: &buffer, tracker: tracker, parser: self.parseIURLAuth)
            return .messagePart(part: part, urlAuth: auth)
        }

        return try oneOf([
            parseICommand_part,
            parseICommand_list,
        ], buffer: &buffer, tracker: tracker)
    }

    // id = "ID" SP id-params-list
    static func parseID(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [IDParameter] {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try fixedString("ID ", buffer: &buffer, tracker: tracker)
            return try parseIDParamsList(buffer: &buffer, tracker: tracker)
        }
    }

    static func parseINetworkPath(buffer: inout ByteBuffer, tracker: StackTracker) throws -> INetworkPath {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> INetworkPath in
            try fixedString("//", buffer: &buffer, tracker: tracker)
            let server = try self.parseIServer(buffer: &buffer, tracker: tracker)
            let query = try self.parseIPathQuery(buffer: &buffer, tracker: tracker)
            return .init(server: server, query: query)
        }
    }

    static func parseIAbsolutePath(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IAbsolutePath {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> IAbsolutePath in
            try fixedString("/", buffer: &buffer, tracker: tracker)
            let command = try optional(buffer: &buffer, tracker: tracker, parser: self.parseICommand)
            return .init(command: command)
        }
    }

    static func parseIAuth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IAuth {
        func parseIAuth_any(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IAuth {
            try fixedString("*", buffer: &buffer, tracker: tracker)
            return .any
        }

        func parseIAuth_encoded(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IAuth {
            let type = try self.parseEncodedAuthenticationType(buffer: &buffer, tracker: tracker)
            return .type(type)
        }

        return try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try fixedString(";AUTH=", buffer: &buffer, tracker: tracker)
            return try oneOf([
                parseIAuth_any,
                parseIAuth_encoded,
            ], buffer: &buffer, tracker: tracker)
        }
    }

    // id-response = "ID" SP id-params-list
    static func parseIDResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [IDParameter] {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try fixedString("ID ", buffer: &buffer, tracker: tracker)
            return try parseIDParamsList(buffer: &buffer, tracker: tracker)
        }
    }

    // id-params-list = "(" *(string SP nstring) ")" / nil
    static func parseIDParamsList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [IDParameter] {
        func parseIDParamsList_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [IDParameter] {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return []
        }

        func parseIDParamsList_element(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IDParameter {
            let key = String(buffer: try self.parseString(buffer: &buffer, tracker: tracker))
            try space(buffer: &buffer, tracker: tracker)
            let value = try self.parseNString(buffer: &buffer, tracker: tracker)
            return .init(key: key, value: value)
        }

        func parseIDParamsList_some(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [IDParameter] {
            try fixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try parseIDParamsList_element(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> IDParameter in
                try space(buffer: &buffer, tracker: tracker)
                return try parseIDParamsList_element(buffer: &buffer, tracker: tracker)
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }

        return try oneOf([
            parseIDParamsList_nil,
            parseIDParamsList_some,
        ], buffer: &buffer, tracker: tracker)
    }

    // idle            = "IDLE" CRLF "DONE"
    static func parseIdleStart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try fixedString("IDLE", buffer: &buffer, tracker: tracker)
        return .idleStart
    }

    static func parseIdleDone(buffer: inout ByteBuffer, tracker: StackTracker) throws {
        try fixedString("DONE", buffer: &buffer, tracker: tracker)
        try newline(buffer: &buffer, tracker: tracker)
    }

    static func parseIPartial(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IPartial {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IPartial in
            try fixedString("/;PARTIAL=", buffer: &buffer, tracker: tracker)
            return .init(range: try self.parsePartialRange(buffer: &buffer, tracker: tracker))
        }
    }

    static func parseIPartialOnly(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IPartialOnly {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IPartialOnly in
            try fixedString(";PARTIAL=", buffer: &buffer, tracker: tracker)
            return .init(range: try self.parsePartialRange(buffer: &buffer, tracker: tracker))
        }
    }

    static func parseIPathQuery(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IPathQuery {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IPathQuery in
            try fixedString("/", buffer: &buffer, tracker: tracker)
            let command = try optional(buffer: &buffer, tracker: tracker, parser: self.parseICommand)
            return .init(command: command)
        }
    }

    static func parseISection(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ISection {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ISection in
            try fixedString("/;SECTION=", buffer: &buffer, tracker: tracker)
            return .init(encodedSection: try self.parseEncodedSection(buffer: &buffer, tracker: tracker))
        }
    }

    static func parseISectionOnly(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ISectionOnly {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ISectionOnly in
            try fixedString(";SECTION=", buffer: &buffer, tracker: tracker)
            return .init(encodedSection: try self.parseEncodedSection(buffer: &buffer, tracker: tracker))
        }
    }

    static func parseIServer(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IServer {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IServer in
            let info = try optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> IUserInfo in
                let info = try self.parseIUserInfo(buffer: &buffer, tracker: tracker)
                try fixedString("@", buffer: &buffer, tracker: tracker)
                return info
            })
            let host = try self.parseHost(buffer: &buffer, tracker: tracker)
            let port = try optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> Int in
                try fixedString(":", buffer: &buffer, tracker: tracker)
                return try self.parseNumber(buffer: &buffer, tracker: tracker)
            })
            return .init(userInfo: info, host: host, port: port)
        }
    }

    static func parseHost(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        // TODO: Enforce IPv6 rules RFC 3986 URI-GEN
        func parseHost_ipv6(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
            try self.parseAtom(buffer: &buffer, tracker: tracker)
        }

        // TODO: Enforce IPv6 rules RFC 3986 URI-GEN
        func parseHost_future(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
            try self.parseAtom(buffer: &buffer, tracker: tracker)
        }

        func parseHost_literal(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
            try fixedString("[", buffer: &buffer, tracker: tracker)
            let address = try oneOf([
                parseHost_ipv6,
                parseHost_future,
            ], buffer: &buffer, tracker: tracker)
            try fixedString("]", buffer: &buffer, tracker: tracker)
            return address
        }

        func parseHost_regularName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
            var newBuffer = ByteBuffer()
            while true {
                do {
                    let chars = try self.parseUChar(buffer: &buffer, tracker: tracker)
                    newBuffer.writeBytes(chars)
                } catch is ParserError {
                    break
                }
            }
            return String(buffer: newBuffer)
        }

        // TODO: This isn't great, but it is functional. Perhaps make it actually enforce IPv4 rules
        func parseHost_ipv4(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
            let num1 = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try fixedString(".", buffer: &buffer, tracker: tracker)
            let num2 = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try fixedString(".", buffer: &buffer, tracker: tracker)
            let num3 = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try fixedString(".", buffer: &buffer, tracker: tracker)
            let num4 = try self.parseNumber(buffer: &buffer, tracker: tracker)
            return "\(num1).\(num2).\(num3).\(num4)"
        }

        return try oneOf([
            parseHost_literal,
            parseHost_regularName,
            parseHost_ipv4,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseIMailboxReference(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IMailboxReference {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IMailboxReference in
            let mailbox = try self.parseEncodedMailbox(buffer: &buffer, tracker: tracker)
            let uidValidity = try optional(buffer: &buffer, tracker: tracker, parser: self.parseUIDValidity)
            return .init(encodeMailbox: mailbox, uidValidity: uidValidity)
        }
    }

    static func parseIMessageList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IMessageList {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IMessageList in
            let mailboxRef = try self.parseIMailboxReference(buffer: &buffer, tracker: tracker)
            let query = try optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> EncodedSearch in
                try fixedString("?", buffer: &buffer, tracker: tracker)
                return try self.parseEncodedSearch(buffer: &buffer, tracker: tracker)
            })
            return .init(mailboxReference: mailboxRef, encodedSearch: query)
        }
    }

    static func parseIMAPURL(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IMAPURL {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IMAPURL in
            try fixedString("imap://", buffer: &buffer, tracker: tracker)
            let server = try self.parseIServer(buffer: &buffer, tracker: tracker)
            let query = try self.parseIPathQuery(buffer: &buffer, tracker: tracker)
            return .init(server: server, query: query)
        }
    }

    static func parseRelativeIMAPURL(buffer: inout ByteBuffer, tracker: StackTracker) throws -> RelativeIMAPURL {
        func parseRelativeIMAPURL_absolute(buffer: inout ByteBuffer, tracker: StackTracker) throws -> RelativeIMAPURL {
            .absolutePath(try self.parseIAbsolutePath(buffer: &buffer, tracker: tracker))
        }

        func parseRelativeIMAPURL_network(buffer: inout ByteBuffer, tracker: StackTracker) throws -> RelativeIMAPURL {
            .networkPath(try self.parseINetworkPath(buffer: &buffer, tracker: tracker))
        }

        func parseRelativeIMAPURL_relative(buffer: inout ByteBuffer, tracker: StackTracker) throws -> RelativeIMAPURL {
            .relativePath(try self.parseIRelativePath(buffer: &buffer, tracker: tracker))
        }

        func parseRelativeIMAPURL_empty(buffer: inout ByteBuffer, tracker: StackTracker) throws -> RelativeIMAPURL {
            .empty
        }

        return try oneOf([
            parseRelativeIMAPURL_network,
            parseRelativeIMAPURL_absolute,
            parseRelativeIMAPURL_relative,
            parseRelativeIMAPURL_empty,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseIRelativePath(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IRelativePath {
        func parseIRelativePath_list(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IRelativePath {
            .list(try self.parseIMessageList(buffer: &buffer, tracker: tracker))
        }

        func parseIRelativePath_messageOrPartial(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IRelativePath {
            .messageOrPartial(try self.parseIMessageOrPartial(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseIRelativePath_list,
            parseIRelativePath_messageOrPartial,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseIMessagePart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IMessagePart {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IMessagePart in
            var ref = try self.parseIMailboxReference(buffer: &buffer, tracker: tracker)

            var uid = try IUID(uid: 1)
            if ref.uidValidity == nil, ref.encodedMailbox.mailbox.last == Character(.init(UInt8(ascii: "/"))) {
                try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                    ref.encodedMailbox.mailbox = String(ref.encodedMailbox.mailbox.dropLast())
                    var newBuffer = ByteBuffer(ByteBufferView([UInt8(ascii: "/")]))
                    newBuffer.writeBuffer(&buffer)
                    uid = try self.parseIUID(buffer: &newBuffer, tracker: tracker)
                    buffer = newBuffer
                }
            } else {
                uid = try self.parseIUID(buffer: &buffer, tracker: tracker)
            }

            var section = try optional(buffer: &buffer, tracker: tracker, parser: self.parseISection)
            var partial: IPartial?
            if section?.encodedSection.section.last == Character(.init(UInt8(ascii: "/"))) {
                try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                    section!.encodedSection.section = String(section!.encodedSection.section.dropLast())
                    var newBuffer = ByteBuffer(ByteBufferView([UInt8(ascii: "/")]))
                    newBuffer.writeBuffer(&buffer)
                    partial = try optional(buffer: &newBuffer, tracker: tracker, parser: self.parseIPartial)
                    buffer = newBuffer
                }
            } else {
                partial = try optional(buffer: &buffer, tracker: tracker, parser: self.parseIPartial)
            }
            return .init(mailboxReference: ref, iUID: uid, iSection: section, iPartial: partial)
        }
    }

    static func parseIMessageOrPartial(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IMessageOrPartial {
        func parseIMessageOrPartial_partialOnly(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IMessageOrPartial {
            let partial = try self.parseIPartialOnly(buffer: &buffer, tracker: tracker)
            return .partialOnly(partial)
        }

        func parseIMessageOrPartial_sectionPartial(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IMessageOrPartial {
            var section = try self.parseISectionOnly(buffer: &buffer, tracker: tracker)
            if section.encodedSection.section.last == Character(.init(UInt8(ascii: "/"))) {
                section.encodedSection.section = String(section.encodedSection.section.dropLast())
                do {
                    let partial = try optional(buffer: &buffer, tracker: tracker, parser: self.parseIPartialOnly)
                    return .sectionPartial(section: section, partial: partial)
                } catch is ParserError {
                    section.encodedSection.section.append("/")
                    return .sectionPartial(section: section, partial: nil)
                }
            }
            let partial = try optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> IPartialOnly in
                try fixedString("/", buffer: &buffer, tracker: tracker)
                return try self.parseIPartialOnly(buffer: &buffer, tracker: tracker)
            })
            return .sectionPartial(section: section, partial: partial)
        }

        func parseIMessageOrPartial_uidSectionPartial(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IMessageOrPartial {
            let uid = try self.parseIUIDOnly(buffer: &buffer, tracker: tracker)
            var section = try optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> ISectionOnly in
                try fixedString("/", buffer: &buffer, tracker: tracker)
                return try self.parseISectionOnly(buffer: &buffer, tracker: tracker)
            })
            if section?.encodedSection.section.last == Character(.init(UInt8(ascii: "/"))) {
                section!.encodedSection.section = String(section!.encodedSection.section.dropLast())
                do {
                    let partial = try optional(buffer: &buffer, tracker: tracker, parser: self.parseIPartialOnly)
                    return .uidSectionPartial(uid: uid, section: section, partial: partial)
                } catch is ParserError {
                    section?.encodedSection.section.append("/")
                    return .uidSectionPartial(uid: uid, section: section, partial: nil)
                }
            }
            let partial = try optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> IPartialOnly in
                try fixedString("/", buffer: &buffer, tracker: tracker)
                return try self.parseIPartialOnly(buffer: &buffer, tracker: tracker)
            })
            return .uidSectionPartial(uid: uid, section: section, partial: partial)
        }

        func parseIMessageOrPartial_refUidSectionPartial(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IMessageOrPartial {
            let ref = try self.parseIMailboxReference(buffer: &buffer, tracker: tracker)
            let uid = try self.parseIUIDOnly(buffer: &buffer, tracker: tracker)
            var section = try optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> ISectionOnly in
                try fixedString("/", buffer: &buffer, tracker: tracker)
                return try self.parseISectionOnly(buffer: &buffer, tracker: tracker)
            })
            if section?.encodedSection.section.last == Character(.init(UInt8(ascii: "/"))) {
                section!.encodedSection.section = String(section!.encodedSection.section.dropLast())
                do {
                    let partial = try optional(buffer: &buffer, tracker: tracker, parser: self.parseIPartialOnly)
                    return .refUidSectionPartial(ref: ref, uid: uid, section: section, partial: partial)
                } catch is ParserError {
                    section?.encodedSection.section.append("/")
                    return .refUidSectionPartial(ref: ref, uid: uid, section: section, partial: nil)
                }
            }
            let partial = try optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> IPartialOnly in
                try fixedString("/", buffer: &buffer, tracker: tracker)
                return try self.parseIPartialOnly(buffer: &buffer, tracker: tracker)
            })
            return .refUidSectionPartial(ref: ref, uid: uid, section: section, partial: partial)
        }

        return try oneOf([
            parseIMessageOrPartial_refUidSectionPartial,
            parseIMessageOrPartial_uidSectionPartial,
            parseIMessageOrPartial_sectionPartial,
            parseIMessageOrPartial_partialOnly,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseUChar(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [UInt8] {
        func parseUChar_unreserved(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [UInt8] {
            guard let num = buffer.readInteger(as: UInt8.self) else {
                throw _IncompleteMessage()
            }
            guard num.isUnreserved else {
                throw ParserError(hint: "Expected unreserved char, got \(num)")
            }
            return [num]
        }

        func parseUChar_subDelimsSH(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [UInt8] {
            guard let num = buffer.readInteger(as: UInt8.self) else {
                throw _IncompleteMessage()
            }
            guard num.isSubDelimsSh else {
                throw ParserError(hint: "Expected sub-delims-sh char, got \(num)")
            }
            return [num]
        }

        // "%" HEXDIGIT HEXDIGIT
        // e.g. %1F
        func parseUChar_pctEncoded(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [UInt8] {
            try fixedString("%", buffer: &buffer, tracker: tracker)
            guard
                var h1 = buffer.readInteger(as: UInt8.self),
                var h2 = buffer.readInteger(as: UInt8.self)
            else {
                throw _IncompleteMessage()
            }

            guard h1.isHexCharacter, h2.isHexCharacter else {
                throw ParserError(hint: "Expected 2 hex digits, got \(h1) and \(h2)")
            }

            if h1 > UInt8(ascii: "F") {
                h1 -= 32
            }
            if h2 > UInt8(ascii: "F") {
                h2 -= 32
            }

            return [UInt8(ascii: "%"), h1, h2]
        }

        return try oneOf([
            parseUChar_unreserved,
            parseUChar_subDelimsSH,
            parseUChar_pctEncoded,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseAChar(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [UInt8] {
        func parseAChar_other(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [UInt8] {
            guard let char = buffer.readInteger(as: UInt8.self) else {
                throw _IncompleteMessage()
            }
            switch char {
            case UInt8(ascii: "&"), UInt8(ascii: "="):
                return [char]
            default:
                throw ParserError(hint: "Expect achar, got \(char)")
            }
        }

        return try oneOf([
            parseUChar,
            parseAChar_other,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseBChar(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [UInt8] {
        func parseBChar_other(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [UInt8] {
            guard let char = buffer.readInteger(as: UInt8.self) else {
                throw _IncompleteMessage()
            }
            switch char {
            case UInt8(ascii: ":"), UInt8(ascii: "@"), UInt8(ascii: "/"):
                return [char]
            default:
                throw ParserError(hint: "Expect bchar, got \(char)")
            }
        }

        return try oneOf([
            parseAChar,
            parseBChar_other,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseIUID(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IUID {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try fixedString("/;UID=", buffer: &buffer, tracker: tracker)
            return try IUID(uid: try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }
    }

    static func parseIUIDOnly(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IUIDOnly {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try fixedString(";UID=", buffer: &buffer, tracker: tracker)
            return try IUIDOnly(uid: try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }
    }

    static func parseIURLAuth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IURLAuth {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IURLAuth in
            let rump = try self.parseIURLAuthRump(buffer: &buffer, tracker: tracker)
            let verifier = try self.parseIUAVerifier(buffer: &buffer, tracker: tracker)
            return .init(auth: rump, verifier: verifier)
        }
    }

    static func parseURLRumpMechanism(buffer: inout ByteBuffer, tracker: StackTracker) throws -> URLRumpMechanism {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> URLRumpMechanism in
            try space(buffer: &buffer, tracker: tracker)
            let rump = try self.parseAString(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let mechanism = try self.parseUAuthMechanism(buffer: &buffer, tracker: tracker)
            return .init(urlRump: rump, mechanism: mechanism)
        }
    }

    static func parseIURLAuthRump(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IURLAuthRump {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IURLAuthRump in
            let expiry = try optional(buffer: &buffer, tracker: tracker, parser: self.parseExpire)
            try fixedString(";URLAUTH=", buffer: &buffer, tracker: tracker)
            let access = try self.parseAccess(buffer: &buffer, tracker: tracker)
            return .init(expire: expiry, access: access)
        }
    }

    static func parseIUAVerifier(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IUAVerifier {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IUAVerifier in
            try fixedString(":", buffer: &buffer, tracker: tracker)
            let authMechanism = try self.parseUAuthMechanism(buffer: &buffer, tracker: tracker)
            try fixedString(":", buffer: &buffer, tracker: tracker)
            let urlAuth = try self.parseEncodedURLAuth(buffer: &buffer, tracker: tracker)
            return .init(uAuthMechanism: authMechanism, encodedURLAuth: urlAuth)
        }
    }

    static func parseIUserInfo(buffer: inout ByteBuffer, tracker: StackTracker) throws -> IUserInfo {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> IUserInfo in
            let encodedUser = try optional(buffer: &buffer, tracker: tracker, parser: self.parseEncodedUser)
            let iauth = try optional(buffer: &buffer, tracker: tracker, parser: self.parseIAuth)
            guard (encodedUser != nil || iauth != nil) else {
                throw ParserError(hint: "Need one of encoded user or iauth")
            }
            return .init(encodedUser: encodedUser, iAuth: iauth)
        }
    }

    // list            = "LIST" [SP list-select-opts] SP mailbox SP mbox-or-pat [SP list-return-opts]
    static func parseList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try fixedString("LIST", buffer: &buffer, tracker: tracker)
            let selectOptions = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ListSelectOptions in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseListSelectOptions(buffer: &buffer, tracker: tracker)
            }
            try space(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let mailboxPatterns = try self.parseMailboxPatterns(buffer: &buffer, tracker: tracker)
            let returnOptions = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [ReturnOption] in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseListReturnOptions(buffer: &buffer, tracker: tracker)
            } ?? []
            return .list(selectOptions, reference: mailbox, mailboxPatterns, returnOptions)
        }
    }

    // list-select-base-opt =  "SUBSCRIBED" / option-extension
    static func parseListSelectBaseOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectBaseOption {
        func parseListSelectBaseOption_subscribed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectBaseOption {
            try fixedString("SUBSCRIBED", buffer: &buffer, tracker: tracker)
            return .subscribed
        }

        func parseListSelectBaseOption_optionExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectBaseOption {
            .option(try self.parseOptionExtension(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseListSelectBaseOption_subscribed,
            parseListSelectBaseOption_optionExtension,
        ], buffer: &buffer, tracker: tracker)
    }

    // list-select-base-opt-quoted =  DQUOTE list-select-base-opt DQUOTE
    static func parseListSelectBaseOptionQuoted(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectBaseOption {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ListSelectBaseOption in
            try fixedString("\"", buffer: &buffer, tracker: tracker)
            let option = try self.parseListSelectBaseOption(buffer: &buffer, tracker: tracker)
            try fixedString("\"", buffer: &buffer, tracker: tracker)
            return option
        }
    }

    // list-select-independent-opt =  "REMOTE" / option-extension
    static func parseListSelectIndependentOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectIndependentOption {
        func parseListSelectIndependentOption_subscribed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectIndependentOption {
            try fixedString("REMOTE", buffer: &buffer, tracker: tracker)
            return .remote
        }

        func parseListSelectIndependentOption_optionExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectIndependentOption {
            .option(try self.parseOptionExtension(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseListSelectIndependentOption_subscribed,
            parseListSelectIndependentOption_optionExtension,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseFullDateTime(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FullDateTime {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let date = try self.parseFullDate(buffer: &buffer, tracker: tracker)
            try fixedString("T", buffer: &buffer, tracker: tracker)
            let time = try self.parseFullTime(buffer: &buffer, tracker: tracker)
            return .init(date: date, time: time)
        }
    }

    static func parseFullDate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FullDate {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let year = try parse4Digit(buffer: &buffer, tracker: tracker)
            try fixedString("-", buffer: &buffer, tracker: tracker)
            let month = try parse2Digit(buffer: &buffer, tracker: tracker)
            try fixedString("-", buffer: &buffer, tracker: tracker)
            let day = try parse2Digit(buffer: &buffer, tracker: tracker)
            return .init(year: year, month: month, day: day)
        }
    }

    static func parseFullTime(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FullTime {
        let hour = try parse2Digit(buffer: &buffer, tracker: tracker)
        try fixedString(":", buffer: &buffer, tracker: tracker)
        let minute = try parse2Digit(buffer: &buffer, tracker: tracker)
        try fixedString(":", buffer: &buffer, tracker: tracker)
        let second = try parse2Digit(buffer: &buffer, tracker: tracker)
        let fraction = try optional(buffer: &buffer, tracker: tracker, parser: { buffer, tracker -> Int in
            try fixedString(".", buffer: &buffer, tracker: tracker)
            return try self.parseNumber(buffer: &buffer, tracker: tracker)
        })
        return .init(hour: hour, minute: minute, second: second, fraction: fraction)
    }

    // list-select-opt =  list-select-base-opt / list-select-independent-opt
    //                    / list-select-mod-opt
    static func parseListSelectOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectOption {
        func parseListSelectOption_subscribed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectOption {
            try fixedString("SUBSCRIBED", buffer: &buffer, tracker: tracker)
            return .subscribed
        }

        func parseListSelectOption_remote(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectOption {
            try fixedString("REMOTE", buffer: &buffer, tracker: tracker)
            return .remote
        }

        func parseListSelectOption_recursiveMatch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectOption {
            try fixedString("RECURSIVEMATCH", buffer: &buffer, tracker: tracker)
            return .recursiveMatch
        }

        func parseListSelectOption_specialUse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectOption {
            try fixedString("SPECIAL-USE", buffer: &buffer, tracker: tracker)
            return .specialUse
        }

        func parseListSelectOption_optionExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectOption {
            .option(try self.parseOptionExtension(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseListSelectOption_subscribed,
            parseListSelectOption_remote,
            parseListSelectOption_recursiveMatch,
            parseListSelectOption_specialUse,
            parseListSelectOption_optionExtension,
        ], buffer: &buffer, tracker: tracker)
    }

    // list-select-opts =  "(" [
    //                    (*(list-select-opt SP) list-select-base-opt
    //                    *(SP list-select-opt))
    //                   / (list-select-independent-opt
    //                    *(SP list-select-independent-opt))
    //                      ] ")"
    static func parseListSelectOptions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectOptions {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try fixedString("(", buffer: &buffer, tracker: tracker)
            var selectOptions = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ListSelectOption in
                let option = try self.parseListSelectOption(buffer: &buffer, tracker: tracker)
                try space(buffer: &buffer, tracker: tracker)
                return option
            }
            let baseOption = try self.parseListSelectBaseOption(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &selectOptions, tracker: tracker) { (buffer, tracker) -> ListSelectOption in
                let option = try self.parseListSelectOption(buffer: &buffer, tracker: tracker)
                try space(buffer: &buffer, tracker: tracker)
                return option
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return .init(baseOption: baseOption, options: selectOptions)
        }
    }

    static func parseLiteralSize(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Int in
            try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try fixedString("~", buffer: &buffer, tracker: tracker)
            }
            try fixedString("{", buffer: &buffer, tracker: tracker)
            let length = try Self.parseNumber(buffer: &buffer, tracker: tracker)
            try fixedString("}", buffer: &buffer, tracker: tracker)
            try newline(buffer: &buffer, tracker: tracker)
            return length
        }
    }

    // mbox-or-pat  = list-mailbox / patterns
    static func parseMailboxPatterns(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxPatterns {
        func parseMailboxPatterns_list(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxPatterns {
            .mailbox(try self.parseListMailbox(buffer: &buffer, tracker: tracker))
        }

        func parseMailboxPatterns_patterns(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxPatterns {
            .pattern(try self.parsePatterns(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseMailboxPatterns_list,
            parseMailboxPatterns_patterns,
        ], buffer: &buffer, tracker: tracker)
    }

    // list-return-opt = "RETURN" SP "(" [return-option *(SP return-option)] ")"
    static func parseListReturnOptions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [ReturnOption] {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try fixedString("RETURN (", buffer: &buffer, tracker: tracker)
            let options = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [ReturnOption] in
                var array = [try self.parseReturnOption(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ReturnOption in
                    try space(buffer: &buffer, tracker: tracker)
                    return try self.parseReturnOption(buffer: &buffer, tracker: tracker)
                }
                return array
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return options ?? []
        }
    }

    // list-mailbox    = 1*list-char / string
    static func parseListMailbox(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        func parseListMailbox_string(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
            try self.parseString(buffer: &buffer, tracker: tracker)
        }

        func parseListMailbox_chars(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
            try ParserLibrary.parseOneOrMoreCharactersByteBuffer(buffer: &buffer, tracker: tracker) { char -> Bool in
                char.isListChar
            }
        }

        return try oneOf([
            parseListMailbox_string,
            parseListMailbox_chars,
        ], buffer: &buffer, tracker: tracker)
    }

    // list-wildcards  = "%" / "*"
    static func parseListWildcards(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        guard let char = buffer.readInteger(as: UInt8.self) else {
            throw _IncompleteMessage()
        }
        guard char.isListWildcard else {
            throw ParserError()
        }
        return String(decoding: CollectionOfOne(char), as: Unicode.UTF8.self)
    }

    // literal         = "{" number ["+"] "}" CRLF *CHAR8
    static func parseLiteral(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
            try fixedString("{", buffer: &buffer, tracker: tracker)
            let length = try Self.parseNumber(buffer: &buffer, tracker: tracker)
            try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try fixedString("+", buffer: &buffer, tracker: tracker)
            }
            try fixedString("}", buffer: &buffer, tracker: tracker)
            try newline(buffer: &buffer, tracker: tracker)
            if let bytes = buffer.readSlice(length: length) {
                if bytes.readableBytesView.contains(0) {
                    throw ParserError(hint: "Found NUL byte in literal")
                }
                return bytes
            } else {
                throw _IncompleteMessage()
            }
        }
    }

    // literal8         = "~{" number ["+"] "}" CRLF *CHAR8
    static func parseLiteral8(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
            try fixedString("~{", buffer: &buffer, tracker: tracker)
            let length = try Self.parseNumber(buffer: &buffer, tracker: tracker)
            try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try fixedString("+", buffer: &buffer, tracker: tracker)
            }
            try fixedString("}", buffer: &buffer, tracker: tracker)
            try newline(buffer: &buffer, tracker: tracker)
            if let bytes = buffer.readSlice(length: length) {
                if bytes.readableBytesView.contains(0) {
                    throw ParserError(hint: "Found NUL byte in literal")
                }
                return bytes
            } else {
                throw _IncompleteMessage()
            }
        }
    }

    // login           = "LOGIN" SP userid SP password
    static func parseLogin(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("LOGIN ", buffer: &buffer, tracker: tracker)
            let userid = try Self.parseUserId(buffer: &buffer, tracker: tracker)
            try fixedString(" ", buffer: &buffer, tracker: tracker)
            let password = try Self.parsePassword(buffer: &buffer, tracker: tracker)
            return .login(username: userid, password: password)
        }
    }

    // lsub = "LSUB" SP mailbox SP list-mailbox
    static func parseLSUB(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Command in
            try fixedString("LSUB ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let listMailbox = try self.parseListMailbox(buffer: &buffer, tracker: tracker)
            return .lsub(reference: mailbox, pattern: listMailbox)
        }
    }

    // mailbox         = "INBOX" / astring
    static func parseMailbox(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName {
        let string = try self.parseAString(buffer: &buffer, tracker: tracker)
        return MailboxName(string)
    }

    // mailbox-data    =  "FLAGS" SP flag-list / "LIST" SP mailbox-list /
    //                    esearch-response /
    //                    "STATUS" SP mailbox SP "(" [status-att-list] ")" /
    //                    number SP "EXISTS" / Namespace-Response
    static func parseMailboxData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
        func parseMailboxData_flags(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
            try fixedString("FLAGS ", buffer: &buffer, tracker: tracker)
            return .flags(try self.parseFlagList(buffer: &buffer, tracker: tracker))
        }

        func parseMailboxData_list(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
            try fixedString("LIST ", buffer: &buffer, tracker: tracker)
            return .list(try self.parseMailboxList(buffer: &buffer, tracker: tracker))
        }

        func parseMailboxData_lsub(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
            try fixedString("LSUB ", buffer: &buffer, tracker: tracker)
            return .lsub(try self.parseMailboxList(buffer: &buffer, tracker: tracker))
        }

        func parseMailboxData_esearch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
            let response = try self.parseEsearchResponse(buffer: &buffer, tracker: tracker)
            return .esearch(response)
        }

        func parseMailboxData_search(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
            try fixedString("SEARCH", buffer: &buffer, tracker: tracker)
            let nums = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Int in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            }
            return .search(nums)
        }

        func parseMailboxData_searchSort(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
            try fixedString("SEARCH", buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            var array = [try self.parseNZNumber(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { (buffer, tracker) in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            })
            try space(buffer: &buffer, tracker: tracker)
            let seq = try self.parseSearchSortModificationSequence(buffer: &buffer, tracker: tracker)
            return .searchSort(.init(identifiers: array, modificationSequence: seq))
        }

        func parseMailboxData_status(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
            try fixedString("STATUS ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            try fixedString("(", buffer: &buffer, tracker: tracker)
            let status = try optional(buffer: &buffer, tracker: tracker, parser: self.parseMailboxStatus)
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return .status(mailbox, status ?? .init())
        }

        func parseMailboxData_exists(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
            let number = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try fixedString(" EXISTS", buffer: &buffer, tracker: tracker)
            return .exists(number)
        }

        func parseMailboxData_recent(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
            let number = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try fixedString(" RECENT", buffer: &buffer, tracker: tracker)
            return .recent(number)
        }

        func parseMailboxData_namespace(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
            .namespace(try self.parseNamespaceResponse(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseMailboxData_flags,
            parseMailboxData_list,
            parseMailboxData_lsub,
            parseMailboxData_esearch,
            parseMailboxData_status,
            parseMailboxData_exists,
            parseMailboxData_recent,
            parseMailboxData_searchSort,
            parseMailboxData_search,
            parseMailboxData_namespace,
        ], buffer: &buffer, tracker: tracker)
    }

    // mailbox-list    = "(" [mbx-list-flags] ")" SP
    //                    (DQUOTE QUOTED-CHAR DQUOTE / nil) SP mailbox
    //                    [SP mbox-list-extended]
    static func parseMailboxList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxInfo {
        func parseMailboxList_quotedChar_some(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Character? {
            try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Character? in
                try fixedString("\"", buffer: &buffer, tracker: tracker)

                guard let character = buffer.readSlice(length: 1)?.readableBytesView.first else {
                    throw _IncompleteMessage()
                }
                guard character.isQuotedChar else {
                    throw ParserError(hint: "Expected quoted char found \(String(decoding: [character], as: Unicode.UTF8.self))")
                }

                try fixedString("\"", buffer: &buffer, tracker: tracker)
                return Character(UnicodeScalar(character))
            }
        }

        func parseMailboxList_quotedChar_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Character? {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return nil
        }

        return try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> MailboxInfo in
            try fixedString("(", buffer: &buffer, tracker: tracker)
            let flags = try optional(buffer: &buffer, tracker: tracker, parser: self.parseMailboxListFlags) ?? []
            try fixedString(")", buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let character = try oneOf([
                parseMailboxList_quotedChar_some,
                parseMailboxList_quotedChar_nil,
            ], buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let listExtended = try optional(buffer: &buffer, tracker: tracker, parser: { (buffer, tracker) -> [ListExtendedItem] in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseMailboxListExtended(buffer: &buffer, tracker: tracker)
            }) ?? []
            return MailboxInfo(attributes: flags, path: try .init(name: mailbox, pathSeparator: character), extensions: listExtended)
        }
    }

    // mbox-list-extended =  "(" [mbox-list-extended-item
    //                       *(SP mbox-list-extended-item)] ")"
    static func parseMailboxListExtended(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [ListExtendedItem] {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [ListExtendedItem] in
            try fixedString("(", buffer: &buffer, tracker: tracker)
            let data = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [ListExtendedItem] in
                var array = [try self.parseMailboxListExtendedItem(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ListExtendedItem in
                    try space(buffer: &buffer, tracker: tracker)
                    return try self.parseMailboxListExtendedItem(buffer: &buffer, tracker: tracker)
                }
                return array
            } ?? []
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return data
        }
    }

    // mbox-list-extended-item =  mbox-list-extended-item-tag SP
    //                            tagged-ext-val
    static func parseMailboxListExtendedItem(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListExtendedItem {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ListExtendedItem in
            let tag = try self.parseAString(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let val = try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            return ListExtendedItem(tag: tag, extensionValue: val)
        }
    }

    // mbox-or-pat =  list-mailbox / patterns
    static func parseMailboxOrPat(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxPatterns {
        func parseMailboxOrPat_list(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxPatterns {
            .mailbox(try self.parseListMailbox(buffer: &buffer, tracker: tracker))
        }

        func parseMailboxOrPat_patterns(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxPatterns {
            .pattern(try self.parsePatterns(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseMailboxOrPat_list,
            parseMailboxOrPat_patterns,
        ], buffer: &buffer, tracker: tracker)
    }

    // mbx-list-flags  = *(mbx-list-oflag SP) mbx-list-sflag
    //                   *(SP mbx-list-oflag) /
    //                   mbx-list-oflag *(SP mbx-list-oflag)
    static func parseMailboxListFlags(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [MailboxInfo.Attribute] {
        var results = [MailboxInfo.Attribute(try self.parseFlagExtension(buffer: &buffer, tracker: tracker))]
        do {
            while true {
                try space(buffer: &buffer, tracker: tracker)
                let att = try self.parseFlagExtension(buffer: &buffer, tracker: tracker)
                results.append(.init(att))
            }
        } catch {
            // do nothing
        }
        return results
    }

    // media-basic     = ((DQUOTE ("APPLICATION" / "AUDIO" / "IMAGE" /
    //                   "MESSAGE" / "VIDEO") DQUOTE) / string) SP
    //                   media-subtype
    static func parseMediaBasic(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.Basic {
        func parseMediaBasic_Kind_defined(_ option: String, result: Media.BasicKind, buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            try fixedString("\"", buffer: &buffer, tracker: tracker)
            try fixedString(option, buffer: &buffer, tracker: tracker)
            try fixedString("\"", buffer: &buffer, tracker: tracker)
            return result
        }

        func parseMediaBasic_Kind_application(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            try parseMediaBasic_Kind_defined("APPLICATION", result: .application, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Kind_audio(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            try parseMediaBasic_Kind_defined("AUDIO", result: .audio, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Kind_image(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            try parseMediaBasic_Kind_defined("IMAGE", result: .image, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Kind_message(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            try parseMediaBasic_Kind_defined("MESSAGE", result: .message, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Kind_video(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            try parseMediaBasic_Kind_defined("VIDEO", result: .video, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Kind_other(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicKind {
            let buffer = try self.parseString(buffer: &buffer, tracker: tracker)
            return .other(String(buffer: buffer))
        }

        return try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Media.Basic in
            let basicType = try oneOf([
                parseMediaBasic_Kind_application,
                parseMediaBasic_Kind_audio,
                parseMediaBasic_Kind_image,
                parseMediaBasic_Kind_message,
                parseMediaBasic_Kind_video,
                parseMediaBasic_Kind_other,
            ], buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let subtype = try self.parseMediaSubtype(buffer: &buffer, tracker: tracker)
            return Media.Basic(kind: basicType, subtype: subtype)
        }
    }

    // media-message   = DQUOTE "MESSAGE" DQUOTE SP
    //                   DQUOTE ("RFC822" / "GLOBAL") DQUOTE
    static func parseMediaMessage(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.Message {
        func parseMediaMessage_rfc(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.Message {
            try fixedString("RFC822", buffer: &buffer, tracker: tracker)
            return .rfc822
        }

        func parseMediaMessage_global(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.Message {
            try fixedString("GLOBAL", buffer: &buffer, tracker: tracker)
            return .global
        }

        return try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Media.Message in
            try fixedString("\"MESSAGE\" \"", buffer: &buffer, tracker: tracker)
            let message = try oneOf([
                parseMediaMessage_rfc,
                parseMediaMessage_global,
            ], buffer: &buffer, tracker: tracker)
            try fixedString("\"", buffer: &buffer, tracker: tracker)
            return message
        }
    }

    // media-subtype   = string
    static func parseMediaSubtype(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.MediaSubtype {
        let buffer = try self.parseString(buffer: &buffer, tracker: tracker)
        let string = String(buffer: buffer)
        return .init(string)
    }

    // media-text      = DQUOTE "TEXT" DQUOTE SP media-subtype
    static func parseMediaText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> String in
            try fixedString("\"TEXT\" ", buffer: &buffer, tracker: tracker)
            let subtype = try self.parseString(buffer: &buffer, tracker: tracker)
            return String(buffer: subtype)
        }
    }

    // message-data    = nz-number SP ("EXPUNGE" / ("FETCH" SP msg-att))
    static func parseMessageData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageData {
        func parseMessageData_expunge(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageData {
            let number = try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            try fixedString(" EXPUNGE", buffer: &buffer, tracker: tracker)
            return .expunge(number)
        }

        func parseMessageData_vanished(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageData {
            try fixedString("VANISHED ", buffer: &buffer, tracker: tracker)
            return .vanished(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        func parseMessageData_vanishedEarlier(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageData {
            try fixedString("VANISHED (EARLIER) ", buffer: &buffer, tracker: tracker)
            return .vanishedEarlier(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseMessageData_expunge,
            parseMessageData_vanished,
            parseMessageData_vanishedEarlier,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseMetadataOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MetadataOption {
        func parseMetadataOption_maxSize(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MetadataOption {
            try fixedString("MAXSIZE ", buffer: &buffer, tracker: tracker)
            return .maxSize(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseMetadataOption_scope(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MetadataOption {
            .scope(try self.parseScopeOption(buffer: &buffer, tracker: tracker))
        }

        func parseMetadataOption_param(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MetadataOption {
            .other(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseMetadataOption_maxSize,
            parseMetadataOption_scope,
            parseMetadataOption_param,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseMetadataOptions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [MetadataOption] {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try fixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseMetadataOption(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { buffer, tracker in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseMetadataOption(buffer: &buffer, tracker: tracker)
            })
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    static func parseMetadataResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MetadataResponse {
        func parseMetadataResponse_values(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MetadataResponse {
            try fixedString("METADATA ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let values = try self.parseEntryValues(buffer: &buffer, tracker: tracker)
            return .values(values: values, mailbox: mailbox)
        }

        func parseMetadataResponse_list(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MetadataResponse {
            try fixedString("METADATA ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let list = try self.parseEntryList(buffer: &buffer, tracker: tracker)
            return .list(list: list, mailbox: mailbox)
        }

        return try oneOf([
            parseMetadataResponse_values,
            parseMetadataResponse_list,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseMetadataValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MetadataValue {
        func parseMetadataValue_nstring(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MetadataValue {
            .init(rawValue: try self.parseNString(buffer: &buffer, tracker: tracker))
        }

        func parseMetadataValue_literal8(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MetadataValue {
            .init(rawValue: try self.parseLiteral8(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseMetadataValue_nstring,
            parseMetadataValue_literal8,
        ], buffer: &buffer, tracker: tracker)
    }

    // mod-sequence-valzer = "0" / mod-sequence-value
    static func parseModificationSequenceValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ModificationSequenceValue {
        let number = try self.parseNumber(buffer: &buffer, tracker: tracker)
        guard let value = ModificationSequenceValue(number) else {
            throw ParserError(hint: "Unable to create ModifiersSequenceValueZero")
        }
        return value
    }

    // move            = "MOVE" SP sequence-set SP mailbox
    static func parseMove(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("MOVE ", buffer: &buffer, tracker: tracker)
            let set = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .move(set, mailbox)
        }
    }

    static func parseMechanismBase64(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MechanismBase64 {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> MechanismBase64 in
            try space(buffer: &buffer, tracker: tracker)
            let mechanism = try self.parseUAuthMechanism(buffer: &buffer, tracker: tracker)
            let base64 = try optional(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
                try fixedString("=", buffer: &buffer, tracker: tracker)
                return try self.parseBase64(buffer: &buffer, tracker: tracker)
            }
            return .init(mechanism: mechanism, base64: base64)
        }
    }

    static func parseFetchStreamingResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> StreamingKind {
        func parseFetchStreamingResponse_rfc822(buffer: inout ByteBuffer, tracker: StackTracker) throws -> StreamingKind {
            try fixedString("RFC822.TEXT", buffer: &buffer, tracker: tracker)
            return .rfc822
        }

        func parseFetchStreamingResponse_bodySectionText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> StreamingKind {
            try fixedString("BODY[TEXT]", buffer: &buffer, tracker: tracker)
            let number = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Int in
                try fixedString("<", buffer: &buffer, tracker: tracker)
                let num = try self.parseNumber(buffer: &buffer, tracker: tracker)
                try fixedString(">", buffer: &buffer, tracker: tracker)
                return num
            }
            return .body(partial: number)
        }

        func parseFetchStreamingResponse_binary(buffer: inout ByteBuffer, tracker: StackTracker) throws -> StreamingKind {
            try fixedString("BINARY", buffer: &buffer, tracker: tracker)
            let section = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            return .binary(section: section)
        }

        return try oneOf([
            parseFetchStreamingResponse_rfc822,
            parseFetchStreamingResponse_bodySectionText,
            parseFetchStreamingResponse_binary,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseFetchModifier(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchModifier {
        func parseFetchModifier_changedSince(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchModifier {
            .changedSince(try self.parseChangedSinceModifier(buffer: &buffer, tracker: tracker))
        }

        func parseFetchModifier_other(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchModifier {
            .other(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseFetchModifier_changedSince,
            parseFetchModifier_other,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseFetchResponseStart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchResponse {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try fixedString("* ", buffer: &buffer, tracker: tracker)
            let number = try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            try fixedString(" FETCH (", buffer: &buffer, tracker: tracker)
            return .start(number)
        }
    }

    static func parseFetchResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchResponse {
        func parseFetchResponse_simpleAttribute(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchResponse {
            let attribute = try self.parseMessageAttribute(buffer: &buffer, tracker: tracker)
            return .simpleAttribute(attribute)
        }

        func parseFetchResponse_streamingBegin(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchResponse {
            let type = try self.parseFetchStreamingResponse(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let literalSize = try self.parseLiteralSize(buffer: &buffer, tracker: tracker)
            return .streamingBegin(kind: type, byteCount: literalSize)
        }

        func parseFetchResponse_finish(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchResponse {
            try fixedString(")", buffer: &buffer, tracker: tracker)
            try newline(buffer: &buffer, tracker: tracker)
            return .finish
        }

        return try oneOf([
            parseFetchResponse_streamingBegin,
            parseFetchResponse_simpleAttribute,
            parseFetchResponse_finish,
        ], buffer: &buffer, tracker: tracker)
    }

    // msg-att-static  = "ENVELOPE" SP envelope / "INTERNALDATE" SP date-time /
    //                   "RFC822.SIZE" SP number /
    //                   "BODY" ["STRUCTURE"] SP body /
    //                   "BODY" section ["<" number ">"] SP nstring /
    //                   "BINARY" section-binary SP (nstring / literal8) /
    //                   "BINARY.SIZE" section-binary SP number /
    //                   "UID" SP uniqueid
    // msg-att-dynamic = "FLAGS" SP "(" [flag-fetch *(SP flag-fetch)] ")"
    // ---- This function combines static and dynamic
    static func parseMessageAttribute(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
        func parseMessageAttribute_flags(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> MessageAttribute in
                try fixedString("FLAGS (", buffer: &buffer, tracker: tracker)
                var array = [try self.parseFlag(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> Flag in
                    try space(buffer: &buffer, tracker: tracker)
                    return try self.parseFlag(buffer: &buffer, tracker: tracker)
                }
                try fixedString(")", buffer: &buffer, tracker: tracker)
                return .flags(array)
            }
        }

        func parseMessageAttribute_envelope(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try fixedString("ENVELOPE ", buffer: &buffer, tracker: tracker)
            return .envelope(try self.parseEnvelope(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_internalDate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try fixedString("INTERNALDATE ", buffer: &buffer, tracker: tracker)
            return .internalDate(try self.parseInternalDate(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_rfc822(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try fixedString("RFC822 ", buffer: &buffer, tracker: tracker)
            let string = try self.parseNString(buffer: &buffer, tracker: tracker)
            return .rfc822(string)
        }

        func parseMessageAttribute_rfc822Header(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try fixedString("RFC822.HEADER ", buffer: &buffer, tracker: tracker)
            let string = try self.parseNString(buffer: &buffer, tracker: tracker)
            return .rfc822Header(string)
        }

        func parseMessageAttribute_rfc822Text(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try fixedString("RFC822.TEXT ", buffer: &buffer, tracker: tracker)
            let string = try self.parseNString(buffer: &buffer, tracker: tracker)
            return .rfc822Text(string)
        }

        func parseMessageAttribute_rfc822Size(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try fixedString("RFC822.SIZE ", buffer: &buffer, tracker: tracker)
            return .rfc822Size(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_body(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try fixedString("BODY", buffer: &buffer, tracker: tracker)
            let hasExtensionData: Bool = {
                do {
                    try fixedString("STRUCTURE", buffer: &buffer, tracker: tracker)
                    return true
                } catch {
                    return false
                }
            }()
            try space(buffer: &buffer, tracker: tracker)
            let body = try self.parseBody(buffer: &buffer, tracker: tracker)
            return .body(body, hasExtensionData: hasExtensionData)
        }

        func parseMessageAttribute_bodySection(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try fixedString("BODY", buffer: &buffer, tracker: tracker)
            let section = try self.parseSection(buffer: &buffer, tracker: tracker)
            let offset = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Int in
                try fixedString("<", buffer: &buffer, tracker: tracker)
                let num = try self.parseNumber(buffer: &buffer, tracker: tracker)
                try fixedString(">", buffer: &buffer, tracker: tracker)
                return num
            }
            try space(buffer: &buffer, tracker: tracker)
            let string = try self.parseNString(buffer: &buffer, tracker: tracker)
            return .bodySection(section ?? SectionSpecifier(kind: .complete), offset: offset, data: string)
        }

        func parseMessageAttribute_uid(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try fixedString("UID ", buffer: &buffer, tracker: tracker)
            return .uid(try self.parseUID(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_binarySize(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try fixedString("BINARY.SIZE", buffer: &buffer, tracker: tracker)
            let section = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let number = try self.parseNumber(buffer: &buffer, tracker: tracker)
            return .binarySize(section: section, size: number)
        }

        func parseMessageAttribute_binary(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try fixedString("BINARY", buffer: &buffer, tracker: tracker)
            let section = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let string = try self.parseNString(buffer: &buffer, tracker: tracker)
            return .binary(section: section, data: string)
        }

        func parseMessageAttribute_fetchModifierResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            .fetchModificationResponse(try self.parseFetchModificationResponse(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_gmailMessageID(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try fixedString("X-GM-MSGID", buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let (id, _) = try ParserLibrary.parseUInt64(buffer: &buffer, tracker: tracker)
            return .gmailMessageID(id)
        }

        func parseMessageAttribute_gmailThreadID(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try fixedString("X-GM-THRID", buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let (id, _) = try ParserLibrary.parseUInt64(buffer: &buffer, tracker: tracker)
            return .gmailThreadID(id)
        }

        func parseMessageAttribute_gmailLabels(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            var attributes: [GmailLabel] = []
            try fixedString("X-GM-LABELS (", buffer: &buffer, tracker: tracker)

            let first: GmailLabel? = try optional(buffer: &buffer, tracker: tracker) { buffer, tracker in
                try parseGmailLabel(buffer: &buffer, tracker: tracker)
            }

            if let first = first {
                attributes.append(first)

                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &attributes, tracker: tracker) { buffer, tracker in
                    try space(buffer: &buffer, tracker: tracker)
                    return try parseGmailLabel(buffer: &buffer, tracker: tracker)
                }
            }

            try fixedString(")", buffer: &buffer, tracker: tracker)
            return .gmailLabels(attributes)
        }

        return try oneOf([
            parseMessageAttribute_envelope,
            parseMessageAttribute_internalDate,
            parseMessageAttribute_rfc822,
            parseMessageAttribute_rfc822Size,
            parseMessageAttribute_rfc822Header,
            parseMessageAttribute_rfc822Text,
            parseMessageAttribute_body,
            parseMessageAttribute_bodySection,
            parseMessageAttribute_uid,
            parseMessageAttribute_binarySize,
            parseMessageAttribute_binary,
            parseMessageAttribute_flags,
            parseMessageAttribute_fetchModifierResponse,
            parseMessageAttribute_gmailMessageID,
            parseMessageAttribute_gmailThreadID,
            parseMessageAttribute_gmailLabels,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseGmailLabel(buffer: inout ByteBuffer, tracker: StackTracker) throws -> GmailLabel {
        func parseGmailLabel_backslash(buffer: inout ByteBuffer, tracker: StackTracker) throws -> GmailLabel {
            try fixedString("\\", buffer: &buffer, tracker: tracker)
            let att = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return .init(rawValue: ByteBuffer(ByteBufferView("\\\(att)".utf8)))
        }

        func parseGmailLabel_string(buffer: inout ByteBuffer, tracker: StackTracker) throws -> GmailLabel {
            let raw = try parseAString(buffer: &buffer, tracker: tracker)
            return .init(rawValue: raw)
        }

        return try oneOf([
            parseGmailLabel_backslash,
            parseGmailLabel_string,
        ], buffer: &buffer, tracker: tracker)
    }

    // Namespace         = nil / "(" 1*Namespace-Descr ")"
    static func parseNamespace(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NamespaceDescription] {
        func parseNamespace_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NamespaceDescription] {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return []
        }

        func parseNamespace_some(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NamespaceDescription] {
            try fixedString("(", buffer: &buffer, tracker: tracker)
            let descriptions = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: self.parseNamespaceDescription)
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return descriptions
        }

        return try oneOf([
            parseNamespace_nil,
            parseNamespace_some,
        ], buffer: &buffer, tracker: tracker)
    }

    // Namespace-Command = "NAMESPACE"
    static func parseNamespaceCommand(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try fixedString("NAMESPACE", buffer: &buffer, tracker: tracker)
        return .namespace
    }

    // Namespace-Descr   = "(" string SP
    //                        (DQUOTE QUOTED-CHAR DQUOTE / nil)
    //                         [Namespace-Response-Extensions] ")"
    static func parseNamespaceDescription(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NamespaceDescription {
        func parseNamespaceDescr_quotedChar(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Character? {
            try fixedString("\"", buffer: &buffer, tracker: tracker)
            guard let char = buffer.readBytes(length: 1)?.first else {
                throw _IncompleteMessage()
            }
            guard char.isQuotedChar else {
                throw ParserError(hint: "Invalid character")
            }
            try fixedString("\"", buffer: &buffer, tracker: tracker)
            return Character(.init(char))
        }

        func parseNamespaceDescr_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Character? {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return nil
        }

        return try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NamespaceDescription in
            try fixedString("(", buffer: &buffer, tracker: tracker)
            let string = try self.parseString(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let char = try oneOf([
                parseNamespaceDescr_quotedChar,
                parseNamespaceDescr_nil,
            ], buffer: &buffer, tracker: tracker)
            let extensions = try self.parseNamespaceResponseExtensions(buffer: &buffer, tracker: tracker)
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return .init(string: string, char: char, responseExtensions: extensions)
        }
    }

    // Namespace-Response-Extensions = *(Namespace-Response-Extension)
    static func parseNamespaceResponseExtensions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NamespaceResponseExtension] {
        try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> NamespaceResponseExtension in
            try self.parseNamespaceResponseExtension(buffer: &buffer, tracker: tracker)
        }
    }

    // Namespace-Response-Extension = SP string SP
    //                   "(" string *(SP string) ")"
    static func parseNamespaceResponseExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NamespaceResponseExtension {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NamespaceResponseExtension in
            try space(buffer: &buffer, tracker: tracker)
            let s1 = try self.parseString(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            try fixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseString(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ByteBuffer in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseString(buffer: &buffer, tracker: tracker)
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return NamespaceResponseExtension(string: s1, array: array)
        }
    }

    // Namespace-Response = "*" SP "NAMESPACE" SP Namespace
    //                       SP Namespace SP Namespace
    static func parseNamespaceResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NamespaceResponse {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NamespaceResponse in
            try fixedString("NAMESPACE ", buffer: &buffer, tracker: tracker)
            let n1 = try self.parseNamespace(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let n2 = try self.parseNamespace(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let n3 = try self.parseNamespace(buffer: &buffer, tracker: tracker)
            return NamespaceResponse(userNamespace: n1, otherUserNamespace: n2, sharedNamespace: n3)
        }
    }

    // nil             = "NIL"
    static func parseNil(buffer: inout ByteBuffer, tracker: StackTracker) throws {
        try fixedString("nil", buffer: &buffer, tracker: tracker)
    }

    // nstring         = string / nil
    static func parseNString(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer? {
        func parseNString_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer? {
            try fixedString("NIL", buffer: &buffer, tracker: tracker)
            return nil
        }

        func parseNString_some(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer? {
            try self.parseString(buffer: &buffer, tracker: tracker)
        }

        return try oneOf([
            parseNString_nil,
            parseNString_some,
        ], buffer: &buffer, tracker: tracker)
    }

    // number          = 1*DIGIT
    static func parseNumber(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        let (num, _) = try ParserLibrary.parseUnsignedInteger(buffer: &buffer, tracker: tracker)
        return num
    }

    // nz-number       = digit-nz *DIGIT
    static func parseNZNumber(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        if case .some(UInt8(ascii: "0")) = buffer.readableBytesView.first {
            throw ParserError(hint: "Number began with 0 ")
        }
        let (num, _) = try ParserLibrary.parseUnsignedInteger(buffer: &buffer, tracker: tracker)
        return num
    }

    // option-extension = (option-standard-tag / option-vendor-tag)
    //                    [SP option-value]
    static func parseOptionExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionExtension {
        func parseOptionExtensionKind_standard(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionExtensionKind {
            .standard(try self.parseAtom(buffer: &buffer, tracker: tracker))
        }

        func parseOptionExtensionKind_vendor(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionExtensionKind {
            .vendor(try self.parseOptionVendorTag(buffer: &buffer, tracker: tracker))
        }

        return try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> OptionExtension in
            let type = try oneOf([
                parseOptionExtensionKind_standard,
                parseOptionExtensionKind_vendor,
            ], buffer: &buffer, tracker: tracker)
            let value = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> OptionValueComp in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseOptionValue(buffer: &buffer, tracker: tracker)
            }
            return OptionExtension(kind: type, value: value)
        }
    }

    // option-val-comp =  astring /
    //                    option-val-comp *(SP option-val-comp) /
    //                    "(" option-val-comp ")"
    static func parseOptionValueComp(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionValueComp {
        func parseOptionValueComp_string(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionValueComp {
            .string(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseOptionValueComp_single(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionValueComp {
            try fixedString("(", buffer: &buffer, tracker: tracker)
            let comp = try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return .array([comp])
        }

        func parseOptionValueComp_array(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionValueComp {
            var array = [try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> OptionValueComp in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)
            }
            return .array(array)
        }

        return try oneOf([
            parseOptionValueComp_string,
            parseOptionValueComp_single,
            parseOptionValueComp_array,
        ], buffer: &buffer, tracker: tracker)
    }

    // option-value =  "(" option-val-comp ")"
    static func parseOptionValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionValueComp {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> OptionValueComp in
            try fixedString("(", buffer: &buffer, tracker: tracker)
            let comp = try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return comp
        }
    }

    // option-vendor-tag =  vendor-token "-" atom
    static func parseOptionVendorTag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionVendorTag {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> OptionVendorTag in
            let token = try self.parseVendorToken(buffer: &buffer, tracker: tracker)
            try fixedString("-", buffer: &buffer, tracker: tracker)
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return OptionVendorTag(token: token, atom: atom)
        }
    }

    // partial         = "<" number "." nz-number ">"
    static func parsePartial(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ClosedRange<Int> {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ClosedRange<Int> in
            try fixedString("<", buffer: &buffer, tracker: tracker)
            guard let num1 = UInt32(exactly: try self.parseNumber(buffer: &buffer, tracker: tracker)) else {
                throw ParserError(hint: "Partial range start is invalid.")
            }
            try fixedString(".", buffer: &buffer, tracker: tracker)
            guard let num2 = UInt32(exactly: try self.parseNZNumber(buffer: &buffer, tracker: tracker)) else {
                throw ParserError(hint: "Partial range count is invalid.")
            }
            guard num2 > 0 else { throw ParserError(hint: "Partial range is invalid: <\(num1).\(num2)>.") }
            try fixedString(">", buffer: &buffer, tracker: tracker)
            let upper1 = num1.addingReportingOverflow(num2)
            guard !upper1.overflow else { throw ParserError(hint: "Range is invalid: <\(num1).\(num2)>.") }
            let upper2 = upper1.partialValue.subtractingReportingOverflow(1)
            guard !upper2.overflow else { throw ParserError(hint: "Range is invalid: <\(num1).\(num2)>.") }
            return Int(num1) ... Int(upper2.partialValue)
        }
    }

    static func parsePartialRange(buffer: inout ByteBuffer, tracker: StackTracker) throws -> PartialRange {
        func parsePartialRange_length(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
            try fixedString(".", buffer: &buffer, tracker: tracker)
            return try self.parseNumber(buffer: &buffer, tracker: tracker)
        }

        return try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> PartialRange in
            let offset = try self.parseNumber(buffer: &buffer, tracker: tracker)
            let length = try optional(buffer: &buffer, tracker: tracker, parser: parsePartialRange_length)
            return .init(offset: offset, length: length)
        }
    }

    // password        = astring
    static func parsePassword(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        var buffer = try Self.parseAString(buffer: &buffer, tracker: tracker)
        return buffer.readString(length: buffer.readableBytes)!
    }

    // patterns        = "(" list-mailbox *(SP list-mailbox) ")"
    static func parsePatterns(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [ByteBuffer] {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [ByteBuffer] in
            try fixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseListMailbox(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ByteBuffer in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseListMailbox(buffer: &buffer, tracker: tracker)
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // quoted          = DQUOTE *QUOTED-CHAR DQUOTE
    static func parseQuoted(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
            try fixedString("\"", buffer: &buffer, tracker: tracker)
            let data = try ParserLibrary.parseZeroOrMoreCharactersByteBuffer(buffer: &buffer, tracker: tracker) { char in
                char.isQuotedChar
            }
            try fixedString("\"", buffer: &buffer, tracker: tracker)
            return data
        }
    }

    // rename          = "RENAME" SP mailbox SP mailbox [rename-params]
    static func parseRename(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("RENAME ", buffer: &buffer, tracker: tracker)
            let from = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try fixedString(" ", caseSensitive: false, buffer: &buffer, tracker: tracker)
            let to = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try optional(buffer: &buffer, tracker: tracker, parser: self.parseParameters) ?? []
            return .rename(from: from, to: to, params: params)
        }
    }

    // response-data   = "*" SP response-payload CRLF
    static func parseResponseData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponsePayload {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try fixedString("* ", buffer: &buffer, tracker: tracker)
            let payload = try self.parseResponsePayload(buffer: &buffer, tracker: tracker)
            try newline(buffer: &buffer, tracker: tracker)
            return payload
        }
    }

    // response-fatal  = "*" SP resp-cond-bye CRLF
    static func parseResponseFatal(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseText {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ResponseText in
            try fixedString("* ", buffer: &buffer, tracker: tracker)
            let bye = try self.parseResponseConditionalBye(buffer: &buffer, tracker: tracker)
            try newline(buffer: &buffer, tracker: tracker)
            return bye
        }
    }

    // response-tagged = tag SP resp-cond-state CRLF
    static func parseTaggedResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedResponse {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> TaggedResponse in
            let tag = try self.parseTag(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let state = try self.parseResponseConditionalState(buffer: &buffer, tracker: tracker)
            try newline(buffer: &buffer, tracker: tracker)
            return TaggedResponse(tag: tag, state: state)
        }
    }

    // resp-code-apnd  = "APPENDUID" SP nz-number SP append-uid
    static func parseResponseCodeAppend(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseCodeAppend {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ResponseCodeAppend in
            try fixedString("APPENDUID ", buffer: &buffer, tracker: tracker)
            let number = try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let uid = try self.parseUID(buffer: &buffer, tracker: tracker)
            return ResponseCodeAppend(num: number, uid: uid)
        }
    }

    // resp-code-copy  = "COPYUID" SP nz-number SP uid-set SP uid-set
    static func parseResponseCodeCopy(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseCodeCopy {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ResponseCodeCopy in
            try fixedString("COPYUID ", buffer: &buffer, tracker: tracker)
            let num = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let set1 = try self.parseUIDSet(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let set2 = try self.parseUIDSet(buffer: &buffer, tracker: tracker)
            return ResponseCodeCopy(num: num, set1: set1, set2: set2)
        }
    }

    // resp-cond-auth  = ("OK" / "PREAUTH") SP resp-text
    static func parseResponseConditionalAuth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseConditionalAuth {
        func parseResponseConditionalAuth_ok(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseConditionalAuth {
            try fixedString("OK ", buffer: &buffer, tracker: tracker)
            return .ok(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        func parseResponseConditionalAuth_preauth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseConditionalAuth {
            try fixedString("PREAUTH ", buffer: &buffer, tracker: tracker)
            return .preauth(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseResponseConditionalAuth_ok,
            parseResponseConditionalAuth_preauth,
        ], buffer: &buffer, tracker: tracker)
    }

    // resp-cond-bye   = "BYE" SP resp-text
    static func parseResponseConditionalBye(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseText {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ResponseText in
            try fixedString("BYE ", buffer: &buffer, tracker: tracker)
            return try self.parseResponseText(buffer: &buffer, tracker: tracker)
        }
    }

    // resp-cond-state = ("OK" / "NO" / "BAD") SP resp-text
    static func parseResponseConditionalState(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseConditionalState {
        func parseResponseConditionalState_ok(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseConditionalState {
            try fixedString("OK ", buffer: &buffer, tracker: tracker)
            return .ok(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        func parseResponseConditionalState_no(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseConditionalState {
            try fixedString("NO ", buffer: &buffer, tracker: tracker)
            return .no(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        func parseResponseConditionalState_bad(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseConditionalState {
            try fixedString("BAD ", buffer: &buffer, tracker: tracker)
            return .bad(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseResponseConditionalState_ok,
            parseResponseConditionalState_no,
            parseResponseConditionalState_bad,
        ], buffer: &buffer, tracker: tracker)
    }

    // response-payload = resp-cond-state / resp-cond-bye / mailbox-data / message-data / capability-data / id-response / enable-data
    static func parseResponsePayload(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponsePayload {
        func parseResponsePayload_conditionalState(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponsePayload {
            .conditionalState(try self.parseResponseConditionalState(buffer: &buffer, tracker: tracker))
        }

        func parseResponsePayload_conditionalBye(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponsePayload {
            .conditionalBye(try self.parseResponseConditionalBye(buffer: &buffer, tracker: tracker))
        }

        func parseResponsePayload_mailboxData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponsePayload {
            .mailboxData(try self.parseMailboxData(buffer: &buffer, tracker: tracker))
        }

        func parseResponsePayload_messageData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponsePayload {
            .messageData(try self.parseMessageData(buffer: &buffer, tracker: tracker))
        }

        func parseResponsePayload_capabilityData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponsePayload {
            .capabilityData(try self.parseCapabilityData(buffer: &buffer, tracker: tracker))
        }

        func parseResponsePayload_idResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponsePayload {
            .id(try self.parseIDResponse(buffer: &buffer, tracker: tracker))
        }

        func parseResponsePayload_enableData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponsePayload {
            .enableData(try self.parseEnableData(buffer: &buffer, tracker: tracker))
        }

        func parseResponsePayload_metadata(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponsePayload {
            .metadata(try self.parseMetadataResponse(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseResponsePayload_conditionalState,
            parseResponsePayload_conditionalBye,
            parseResponsePayload_mailboxData,
            parseResponsePayload_messageData,
            parseResponsePayload_capabilityData,
            parseResponsePayload_idResponse,
            parseResponsePayload_enableData,
            parseResponsePayload_quota,
            parseResponsePayload_quotaRoot,
            parseResponsePayload_metadata,
        ], buffer: &buffer, tracker: tracker)
    }

    // resp-text       = ["[" resp-text-code "]" SP] text
    static func parseResponseText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseText {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ResponseText in
            let code = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ResponseTextCode in
                try fixedString("[", buffer: &buffer, tracker: tracker)
                let code = try self.parseResponseTextCode(buffer: &buffer, tracker: tracker)
                try fixedString("] ", buffer: &buffer, tracker: tracker)
                return code
            }
            let text = try self.parseText(buffer: &buffer, tracker: tracker)
            return ResponseText(code: code, text: String(buffer: text))
        }
    }

    // resp-text-code  = "ALERT" /
    //                   "BADCHARSET" [SP "(" charset *(SP charset) ")" ] /
    //                   capability-data / "PARSE" /
    //                   "PERMANENTFLAGS" SP "("
    //                   [flag-perm *(SP flag-perm)] ")" /
    //                   "READ-ONLY" / "READ-WRITE" / "TRYCREATE" /
    //                   "UIDNEXT" SP nz-number / "UIDVALIDITY" SP nz-number /
    //                   "UNSEEN" SP nz-number
    //                   atom [SP 1*<any TEXT-CHAR except "]">] /
    //                   "NOTSAVED"
    static func parseResponseTextCode(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
        func parseResponseTextCode_alert(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try fixedString("ALERT", buffer: &buffer, tracker: tracker)
            return .alert
        }

        func parseResponseTextCode_noModifierSequence(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try fixedString("NOMODSEQ", buffer: &buffer, tracker: tracker)
            return .noModificationSequence
        }

        func parseResponseTextCode_modified(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try fixedString("MODIFIED ", buffer: &buffer, tracker: tracker)
            return .modificationSequence(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_highestModifiedSequence(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try fixedString("HIGHESTMODSEQ ", buffer: &buffer, tracker: tracker)
            return .highestModificationSequence(try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_referral(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try fixedString("REFERRAL ", buffer: &buffer, tracker: tracker)
            return .referral(try self.parseIMAPURL(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_badCharset(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try fixedString("BADCHARSET", buffer: &buffer, tracker: tracker)
            let charsets = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [String] in
                try fixedString(" (", buffer: &buffer, tracker: tracker)
                var array = [try self.parseCharset(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> String in
                    try space(buffer: &buffer, tracker: tracker)
                    return try self.parseCharset(buffer: &buffer, tracker: tracker)
                }
                try fixedString(")", buffer: &buffer, tracker: tracker)
                return array
            } ?? []
            return .badCharset(charsets)
        }

        func parseResponseTextCode_capabilityData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            .capability(try self.parseCapabilityData(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_parse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try fixedString("PARSE", buffer: &buffer, tracker: tracker)
            return .parse
        }

        func parseResponseTextCode_permanentFlags(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try fixedString("PERMANENTFLAGS (", buffer: &buffer, tracker: tracker)
            let array = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [PermanentFlag] in
                var array = [try self.parseFlagPerm(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) in
                    try space(buffer: &buffer, tracker: tracker)
                    return try self.parseFlagPerm(buffer: &buffer, tracker: tracker)
                }
                return array
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return .permanentFlags(array ?? [])
        }

        func parseResponseTextCode_readOnly(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try fixedString("READ-ONLY", buffer: &buffer, tracker: tracker)
            return .readOnly
        }

        func parseResponseTextCode_readWrite(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try fixedString("READ-WRITE", buffer: &buffer, tracker: tracker)
            return .readWrite
        }

        func parseResponseTextCode_tryCreate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try fixedString("TRYCREATE", buffer: &buffer, tracker: tracker)
            return .tryCreate
        }

        func parseResponseTextCode_uidNext(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try fixedString("UIDNEXT ", buffer: &buffer, tracker: tracker)
            return .uidNext(try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_uidValidity(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try fixedString("UIDVALIDITY ", buffer: &buffer, tracker: tracker)
            return .uidValidity(try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_unseen(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try fixedString("UNSEEN ", buffer: &buffer, tracker: tracker)
            return .unseen(try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_namespace(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            .namespace(try self.parseNamespaceResponse(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_atom(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            let string = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> String in
                try space(buffer: &buffer, tracker: tracker)
                return try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { (char) -> Bool in
                    char.isTextChar && char != UInt8(ascii: "]")
                }
            }
            return .other(atom, string)
        }

        func parseResponseTextCode_uidNotSticky(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try fixedString("UIDNOTSTICKY", buffer: &buffer, tracker: tracker)
            return .uidNotSticky
        }

        func parseResponseTextCode_closed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try fixedString("CLOSED", buffer: &buffer, tracker: tracker)
            return .closed
        }

        func parseResponseTextCode_uidCopy(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            .uidCopy(try self.parseResponseCodeCopy(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_uidAppend(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            .uidAppend(try self.parseResponseCodeAppend(buffer: &buffer, tracker: tracker))
        }

        // RFC 5182
        func parseResponseTextCode_notSaved(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try fixedString("NOTSAVED", buffer: &buffer, tracker: tracker)
            return .notSaved
        }

        func parseResponseTextCode_metadataLongEntries(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try fixedString("METADATA LONGENTRIES ", buffer: &buffer, tracker: tracker)
            let num = try self.parseNumber(buffer: &buffer, tracker: tracker)
            return .metadataLongEntries(num)
        }

        func parseResponseTextCode_metadataMaxSize(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try fixedString("METADATA MAXSIZE ", buffer: &buffer, tracker: tracker)
            let num = try self.parseNumber(buffer: &buffer, tracker: tracker)
            return .metadataMaxsize(num)
        }

        func parseResponseTextCode_metadataTooMany(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try fixedString("METADATA TOOMANY", buffer: &buffer, tracker: tracker)
            return .metadataTooMany
        }

        func parseResponseTextCode_metadataNoPrivate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try fixedString("METADATA NOPRIVATE", buffer: &buffer, tracker: tracker)
            return .metadataNoPrivate
        }

        func parseResponseTextCode_urlMechanisms(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try fixedString("URLMECH INTERNAL", buffer: &buffer, tracker: tracker)
            let array = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker, parser: self.parseMechanismBase64)
            return .urlMechanisms(array)
        }

        return try oneOf([
            parseResponseTextCode_alert,
            parseResponseTextCode_noModifierSequence,
            parseResponseTextCode_modified,
            parseResponseTextCode_highestModifiedSequence,
            parseResponseTextCode_badCharset,
            parseResponseTextCode_capabilityData,
            parseResponseTextCode_parse,
            parseResponseTextCode_permanentFlags,
            parseResponseTextCode_readOnly,
            parseResponseTextCode_readWrite,
            parseResponseTextCode_tryCreate,
            parseResponseTextCode_uidNext,
            parseResponseTextCode_uidValidity,
            parseResponseTextCode_unseen,
            parseResponseTextCode_namespace,
            parseResponseTextCode_uidNotSticky,
            parseResponseTextCode_notSaved,
            parseResponseTextCode_uidCopy,
            parseResponseTextCode_uidAppend,
            parseResponseTextCode_closed,
            parseResponseTextCode_metadataLongEntries,
            parseResponseTextCode_metadataMaxSize,
            parseResponseTextCode_metadataTooMany,
            parseResponseTextCode_metadataNoPrivate,
            parseResponseTextCode_urlMechanisms,
            parseResponseTextCode_referral,
            parseResponseTextCode_atom,
        ], buffer: &buffer, tracker: tracker)
    }

    // return-option   =  "SUBSCRIBED" / "CHILDREN" / status-option /
    //                    option-extension
    static func parseReturnOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ReturnOption {
        func parseReturnOption_subscribed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ReturnOption {
            try fixedString("SUBSCRIBED", buffer: &buffer, tracker: tracker)
            return .subscribed
        }

        func parseReturnOption_children(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ReturnOption {
            try fixedString("CHILDREN", buffer: &buffer, tracker: tracker)
            return .children
        }

        func parseReturnOption_statusOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ReturnOption {
            .statusOption(try self.parseStatusOption(buffer: &buffer, tracker: tracker))
        }

        func parseReturnOption_optionExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ReturnOption {
            .optionExtension(try self.parseOptionExtension(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseReturnOption_subscribed,
            parseReturnOption_children,
            parseReturnOption_statusOption,
            parseReturnOption_optionExtension,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseScopeOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ScopeOption {
        func parseScopeOption_zero(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ScopeOption {
            try fixedString("0", buffer: &buffer, tracker: tracker)
            return .zero
        }

        func parseScopeOption_one(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ScopeOption {
            try fixedString("1", buffer: &buffer, tracker: tracker)
            return .one
        }

        func parseScopeOption_infinity(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ScopeOption {
            try fixedString("infinity", buffer: &buffer, tracker: tracker)
            return .infinity
        }

        return try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try fixedString("DEPTH ", buffer: &buffer, tracker: tracker)
            return try oneOf([
                parseScopeOption_zero,
                parseScopeOption_one,
                parseScopeOption_infinity,
            ], buffer: &buffer, tracker: tracker)
        }
    }

    // search          = "SEARCH" [search-return-opts] SP search-program
    static func parseSearch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try fixedString("SEARCH", buffer: &buffer, tracker: tracker)
            let returnOpts = try optional(buffer: &buffer, tracker: tracker, parser: self.parseSearchReturnOptions) ?? []
            try space(buffer: &buffer, tracker: tracker)
            let (charset, program) = try parseSearchProgram(buffer: &buffer, tracker: tracker)
            return .search(key: program, charset: charset, returnOptions: returnOpts)
        }
    }

    // search-program     = ["CHARSET" SP charset SP]
    //                         search-key *(SP search-key)
    //                         ;; CHARSET argument to SEARCH MUST be
    //                         ;; registered with IANA.
    static func parseSearchProgram(buffer: inout ByteBuffer, tracker: StackTracker) throws -> (String?, SearchKey) {
        let charset = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> String in
            try fixedString("CHARSET ", buffer: &buffer, tracker: tracker)
            let charset = try self.parseCharset(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            return charset
        }
        var array = [try self.parseSearchKey(buffer: &buffer, tracker: tracker)]
        try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> SearchKey in
            try space(buffer: &buffer, tracker: tracker)
            return try self.parseSearchKey(buffer: &buffer, tracker: tracker)
        }

        if case .and = array.first!, array.count == 1 {
            return (charset, array.first!)
        } else if array.count == 1 {
            return (charset, array.first!)
        } else {
            return (charset, .and(array))
        }
    }

    // RFC 6237
    // one-correlator =  ("TAG" SP tag-string) / ("MAILBOX" SP astring) /
    //                      ("UIDVALIDITY" SP nz-number)
    //                      ; Each correlator MUST appear exactly once.
    // search-correlator =  SP "(" one-correlator *(SP one-correlator) ")"
    static func parseSearchCorrelator(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchCorrelator {
        var tag: ByteBuffer?
        var mailbox: MailboxName?
        var uidValidity: Int?

        func parseSearchCorrelator_tag(buffer: inout ByteBuffer, tracker: StackTracker) throws {
            try fixedString("TAG ", buffer: &buffer, tracker: tracker)
            tag = try self.parseString(buffer: &buffer, tracker: tracker)
        }

        func parseSearchCorrelator_mailbox(buffer: inout ByteBuffer, tracker: StackTracker) throws {
            try fixedString("MAILBOX ", buffer: &buffer, tracker: tracker)
            mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
        }

        func parseSearchCorrelator_uidValidity(buffer: inout ByteBuffer, tracker: StackTracker) throws {
            try fixedString("UIDVALIDITY ", buffer: &buffer, tracker: tracker)
            uidValidity = try self.parseNZNumber(buffer: &buffer, tracker: tracker)
        }

        func parseSearchCorrelator_once(buffer: inout ByteBuffer, tracker: StackTracker) throws {
            try oneOf([
                parseSearchCorrelator_tag,
                parseSearchCorrelator_mailbox,
                parseSearchCorrelator_uidValidity,
            ], buffer: &buffer, tracker: tracker)
        }

        return try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try fixedString(" (", buffer: &buffer, tracker: tracker)

            try parseSearchCorrelator_once(buffer: &buffer, tracker: tracker)
            var result: SearchCorrelator
            if try optional(buffer: &buffer, tracker: tracker, parser: space) != nil {
                // If we have 2, we must have the third.
                try parseSearchCorrelator_once(buffer: &buffer, tracker: tracker)
                try space(buffer: &buffer, tracker: tracker)
                try parseSearchCorrelator_once(buffer: &buffer, tracker: tracker)
                if let tag = tag, mailbox != nil, uidValidity != nil {
                    result = SearchCorrelator(tag: tag, mailbox: mailbox, uidValidity: uidValidity)
                } else {
                    throw ParserError(hint: "Not all components present for SearchCorrelator")
                }
            } else {
                if let tag = tag {
                    result = SearchCorrelator(tag: tag)
                } else {
                    throw ParserError(hint: "tag missing for SearchCorrelator")
                }
            }

            try fixedString(")", buffer: &buffer, tracker: tracker)
            return result
        }
    }

    // search-critera = search-key *(search-key)
    static func parseSearchCriteria(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [SearchKey] {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            var array = [try self.parseSearchKey(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            }
            return array
        }
    }

    // search-key      = "ALL" / "ANSWERED" / "BCC" SP astring /
    //                   "BEFORE" SP date / "BODY" SP astring /
    //                   "CC" SP astring / "DELETED" / "FLAGGED" /
    //                   "FROM" SP astring / "KEYWORD" SP flag-keyword /
    //                   "NEW" / "OLD" / "ON" SP date / "RECENT" / "SEEN" /
    //                   "SINCE" SP date / "SUBJECT" SP astring /
    //                   "TEXT" SP astring / "TO" SP astring /
    //                   "UNANSWERED" / "UNDELETED" / "UNFLAGGED" /
    //                   "UNKEYWORD" SP flag-keyword / "UNSEEN" /
    //                   "DRAFT" / "HEADER" SP header-fld-name SP astring /
    //                   "LARGER" SP number / "NOT" SP search-key /
    //                   "OR" SP search-key SP search-key /
    //                   "SENTBEFORE" SP date / "SENTON" SP date /
    //                   "SENTSINCE" SP date / "SMALLER" SP number /
    //                   "UID" SP sequence-set / "UNDRAFT" / sequence-set /
    //                   "(" search-key *(SP search-key) ")"
    static func parseSearchKey(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
        func parseSearchKey_fixed(string: String, result: SearchKey, buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString(string, buffer: &buffer, tracker: tracker)
            return result
        }

        func parseSearchKey_fixedOptions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            let inputs: [(String, SearchKey)] = [
                ("ALL", .all),
                ("ANSWERED", .answered),
                ("DELETED", .deleted),
                ("FLAGGED", .flagged),
                ("NEW", .new),
                ("OLD", .old),
                ("RECENT", .recent),
                ("SEEN", .seen),
                ("UNSEEN", .unseen),
                ("UNANSWERED", .unanswered),
                ("UNDELETED", .undeleted),
                ("UNFLAGGED", .unflagged),
                ("DRAFT", .draft),
                ("UNDRAFT", .undraft),
            ]
            let save = buffer
            for (key, value) in inputs {
                do {
                    return try parseSearchKey_fixed(string: key, result: value, buffer: &buffer, tracker: tracker)
                } catch is ParserError {
                    buffer = save
                }
            }
            throw ParserError()
        }

        func parseSearchKey_bcc(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("BCC ", buffer: &buffer, tracker: tracker)
            return .bcc(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_before(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("BEFORE ", buffer: &buffer, tracker: tracker)
            return .before(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_body(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("BODY ", buffer: &buffer, tracker: tracker)
            return .body(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_cc(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("CC ", buffer: &buffer, tracker: tracker)
            return .cc(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_from(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("FROM ", buffer: &buffer, tracker: tracker)
            return .from(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_keyword(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("KEYWORD ", buffer: &buffer, tracker: tracker)
            return .keyword(try self.parseFlagKeyword(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_on(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("ON ", buffer: &buffer, tracker: tracker)
            return .on(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_since(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("SINCE ", buffer: &buffer, tracker: tracker)
            return .since(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_subject(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("SUBJECT ", buffer: &buffer, tracker: tracker)
            return .subject(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_text(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("TEXT ", buffer: &buffer, tracker: tracker)
            return .text(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_to(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("TO ", buffer: &buffer, tracker: tracker)
            return .to(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_unkeyword(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("UNKEYWORD ", buffer: &buffer, tracker: tracker)
            return .unkeyword(try self.parseFlagKeyword(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_filter(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("FILTER ", buffer: &buffer, tracker: tracker)
            return .filter(try self.parseFilterName(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_header(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("HEADER ", buffer: &buffer, tracker: tracker)
            let header = try self.parseHeaderFieldName(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let string = try self.parseAString(buffer: &buffer, tracker: tracker)
            return .header(header, string)
        }

        func parseSearchKey_larger(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("LARGER ", buffer: &buffer, tracker: tracker)
            return .messageSizeLarger(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_smaller(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("SMALLER ", buffer: &buffer, tracker: tracker)
            return .messageSizeSmaller(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_not(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("NOT ", buffer: &buffer, tracker: tracker)
            return .not(try self.parseSearchKey(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_or(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("OR ", buffer: &buffer, tracker: tracker)
            let key1 = try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let key2 = try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            return .or(key1, key2)
        }

        func parseSearchKey_sentBefore(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("SENTBEFORE ", buffer: &buffer, tracker: tracker)
            return .sentBefore(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_sentOn(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("SENTON ", buffer: &buffer, tracker: tracker)
            return .sentOn(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_sentSince(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("SENTSINCE ", buffer: &buffer, tracker: tracker)
            return .sentSince(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_uid(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("UID ", buffer: &buffer, tracker: tracker)
            return .uid(try self.parseUIDSet(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_sequenceSet(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            .sequenceNumbers(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_array(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseSearchKey(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> SearchKey in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)

            if array.count == 1 {
                return array.first!
            } else {
                return .and(array)
            }
        }

        func parseSearchKey_older(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("OLDER ", buffer: &buffer, tracker: tracker)
            return .older(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_younger(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try fixedString("YOUNGER ", buffer: &buffer, tracker: tracker)
            return .younger(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_modificationSequence(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            .modificationSequence(try self.parseSearchModificationSequence(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseSearchKey_older,
            parseSearchKey_fixedOptions,
            parseSearchKey_younger,
            parseSearchKey_bcc,
            parseSearchKey_before,
            parseSearchKey_body,
            parseSearchKey_cc,
            parseSearchKey_from,
            parseSearchKey_keyword,
            parseSearchKey_on,
            parseSearchKey_since,
            parseSearchKey_subject,
            parseSearchKey_text,
            parseSearchKey_to,
            parseSearchKey_unkeyword,
            parseSearchKey_header,
            parseSearchKey_larger,
            parseSearchKey_smaller,
            parseSearchKey_not,
            parseSearchKey_or,
            parseSearchKey_sentBefore,
            parseSearchKey_sentOn,
            parseSearchKey_sentSince,
            parseSearchKey_uid,
            parseSearchKey_sequenceSet,
            parseSearchKey_array,
            parseSearchKey_filter,
            parseSearchKey_modificationSequence,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseSearchModificationSequence(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchModificationSequence {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> SearchModificationSequence in
            try fixedString("MODSEQ", buffer: &buffer, tracker: tracker)
            let extensions = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker, parser: self.parseSearchModificationSequenceExtension)
            try space(buffer: &buffer, tracker: tracker)
            let val = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            return .init(extensions: extensions, sequenceValue: val)
        }
    }

    static func parseSearchModificationSequenceExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchModificationSequenceExtension {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> SearchModificationSequenceExtension in
            try space(buffer: &buffer, tracker: tracker)
            let flag = try self.parseEntryFlagName(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let request = try self.parseEntryKindRequest(buffer: &buffer, tracker: tracker)
            return .init(name: flag, request: request)
        }
    }

    // search-ret-data-ext = search-modifier-name SP search-return-value
    static func parseSearchReturnDataExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnDataExtension {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> SearchReturnDataExtension in
            let modifier = try self.parseParameterName(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let value = try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            return SearchReturnDataExtension(modifierName: modifier, returnValue: value)
        }
    }

    // search-return-data = "MIN" SP nz-number /
    //                     "MAX" SP nz-number /
    //                     "ALL" SP sequence-set /
    //                     "COUNT" SP number /
    //                     search-ret-data-ext
    static func parseSearchReturnData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnData {
        func parseSearchReturnData_min(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnData {
            try fixedString("MIN ", buffer: &buffer, tracker: tracker)
            return .min(try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_max(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnData {
            try fixedString("MAX ", buffer: &buffer, tracker: tracker)
            return .max(try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_all(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnData {
            try fixedString("ALL ", buffer: &buffer, tracker: tracker)
            return .all(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_count(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnData {
            try fixedString("COUNT ", buffer: &buffer, tracker: tracker)
            return .count(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_modificationSequence(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnData {
            try fixedString("MODSEQ ", buffer: &buffer, tracker: tracker)
            return .modificationSequence(try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_dataExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnData {
            .dataExtension(try self.parseSearchReturnDataExtension(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseSearchReturnData_min,
            parseSearchReturnData_max,
            parseSearchReturnData_all,
            parseSearchReturnData_count,
            parseSearchReturnData_modificationSequence,
            parseSearchReturnData_dataExtension,
        ], buffer: &buffer, tracker: tracker)
    }

    // search-return-opts   = SP "RETURN" SP "(" [search-return-opt *(SP search-return-opt)] ")"
    static func parseSearchReturnOptions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [SearchReturnOption] {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try fixedString(" RETURN (", buffer: &buffer, tracker: tracker)
            let array = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [SearchReturnOption] in
                var array = [try self.parseSearchReturnOption(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> SearchReturnOption in
                    try space(buffer: &buffer, tracker: tracker)
                    return try self.parseSearchReturnOption(buffer: &buffer, tracker: tracker)
                }
                return array
            } ?? []
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // search-return-opt  = "MIN" / "MAX" / "ALL" / "COUNT" /
    //                      "SAVE" /
    //                      search-ret-opt-ext
    static func parseSearchReturnOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
        func parseSearchReturnOption_min(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            try fixedString("MIN", buffer: &buffer, tracker: tracker)
            return .min
        }

        func parseSearchReturnOption_max(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            try fixedString("MAX", buffer: &buffer, tracker: tracker)
            return .max
        }

        func parseSearchReturnOption_all(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            try fixedString("ALL", buffer: &buffer, tracker: tracker)
            return .all
        }

        func parseSearchReturnOption_count(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            try fixedString("COUNT", buffer: &buffer, tracker: tracker)
            return .count
        }

        func parseSearchReturnOption_save(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            try fixedString("SAVE", buffer: &buffer, tracker: tracker)
            return .save
        }

        func parseSearchReturnOption_extension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            let optionExtension = try self.parseSearchReturnOptionExtension(buffer: &buffer, tracker: tracker)
            return .optionExtension(optionExtension)
        }

        return try oneOf([
            parseSearchReturnOption_min,
            parseSearchReturnOption_max,
            parseSearchReturnOption_all,
            parseSearchReturnOption_count,
            parseSearchReturnOption_save,
            parseSearchReturnOption_extension,
        ], buffer: &buffer, tracker: tracker)
    }

    // search-ret-opt-ext = search-modifier-name [SP search-mod-params]
    static func parseSearchReturnOptionExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOptionExtension {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> SearchReturnOptionExtension in
            let name = try self.parseParameterName(buffer: &buffer, tracker: tracker)
            let params = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ParameterValue in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            }
            return SearchReturnOptionExtension(modifierName: name, params: params)
        }
    }

    static func parseSearchSortModificationSequence(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchSortModificationSequence {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> SearchSortModificationSequence in
            try fixedString("(MODSEQ ", buffer: &buffer, tracker: tracker)
            let modSeq = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return .init(modifierSequenceValue: modSeq)
        }
    }

    // section         = "[" [section-spec] "]"
    static func parseSection(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier? {
        func parseSection_none(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier? {
            try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> SectionSpecifier? in
                try fixedString("[]", buffer: &buffer, tracker: tracker)
                return nil
            }
        }

        func parseSection_some(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier? {
            try fixedString("[", buffer: &buffer, tracker: tracker)
            let spec = try self.parseSectionSpecifier(buffer: &buffer, tracker: tracker)
            try fixedString("]", buffer: &buffer, tracker: tracker)
            return spec
        }

        return try oneOf([
            parseSection_none,
            parseSection_some,
        ], buffer: &buffer, tracker: tracker)
    }

    // section-binary  = "[" [section-part] "]"
    static func parseSectionBinary(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier.Part {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> SectionSpecifier.Part in
            try fixedString("[", buffer: &buffer, tracker: tracker)
            let part = try optional(buffer: &buffer, tracker: tracker, parser: self.parseSectionPart)
            try fixedString("]", buffer: &buffer, tracker: tracker)
            return part ?? .init(rawValue: [])
        }
    }

    // section-part    = nz-number *("." nz-number)
    static func parseSectionPart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier.Part {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> SectionSpecifier.Part in
            var output = [try self.parseNZNumber(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { (buffer, tracker) -> Int in
                try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Int in
                    try fixedString(".", buffer: &buffer, tracker: tracker)
                    return try self.parseNZNumber(buffer: &buffer, tracker: tracker)
                }
            }
            return .init(rawValue: output)
        }
    }

    // section-spec    = section-msgtext / (section-part ["." section-text])
    static func parseSectionSpecifier(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier {
        func parseSectionSpecifier_noPart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier {
            let kind = try self.parseSectionSpecifierKind(buffer: &buffer, tracker: tracker)
            return .init(kind: kind)
        }

        func parseSectionSpecifier_withPart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier {
            let part = try self.parseSectionPart(buffer: &buffer, tracker: tracker)
            let kind = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> SectionSpecifier.Kind in
                try fixedString(".", buffer: &buffer, tracker: tracker)
                return try self.parseSectionSpecifierKind(buffer: &buffer, tracker: tracker)
            } ?? .complete
            return .init(part: part, kind: kind)
        }

        return try oneOf([
            parseSectionSpecifier_withPart,
            parseSectionSpecifier_noPart,
        ], buffer: &buffer, tracker: tracker)
    }

    // section-text    = section-msgtext / "MIME"
    static func parseSectionSpecifierKind(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
        func parseSectionSpecifierKind_mime(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            try fixedString("MIME", buffer: &buffer, tracker: tracker)
            return .MIMEHeader
        }

        func parseSectionSpecifierKind_header(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            try fixedString("HEADER", buffer: &buffer, tracker: tracker)
            return .header
        }

        func parseSectionSpecifierKind_headerFields(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            try fixedString("HEADER.FIELDS ", buffer: &buffer, tracker: tracker)
            return .headerFields(try self.parseHeaderList(buffer: &buffer, tracker: tracker))
        }

        func parseSectionSpecifierKind_notHeaderFields(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            try fixedString("HEADER.FIELDS.NOT ", buffer: &buffer, tracker: tracker)
            return .headerFieldsNot(try self.parseHeaderList(buffer: &buffer, tracker: tracker))
        }

        func parseSectionSpecifierKind_text(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            try fixedString("TEXT", buffer: &buffer, tracker: tracker)
            return .text
        }

        func parseSectionSpecifierKind_complete(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpecifier.Kind {
            .complete
        }

        return try oneOf([
            parseSectionSpecifierKind_mime,
            parseSectionSpecifierKind_headerFields,
            parseSectionSpecifierKind_notHeaderFields,
            parseSectionSpecifierKind_header,
            parseSectionSpecifierKind_text,
            parseSectionSpecifierKind_complete,
        ], buffer: &buffer, tracker: tracker)
    }

    // select          = "SELECT" SP mailbox [select-params]
    static func parseSelect(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("SELECT ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [SelectParameter] in
                try space(buffer: &buffer, tracker: tracker)
                try fixedString("(", buffer: &buffer, tracker: tracker)
                var array = [try self.parseSelectParameter(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { (buffer, tracker) in
                    try space(buffer: &buffer, tracker: tracker)
                    return try self.parseSelectParameter(buffer: &buffer, tracker: tracker)
                })
                try fixedString(")", buffer: &buffer, tracker: tracker)
                return array
            }
            return .select(mailbox, params ?? [])
        }
    }

    static func parseSelectParameter(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SelectParameter {
        func parseSelectParameter_basic(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SelectParameter {
            .basic(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        func parseSelectParameter_condstore(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SelectParameter {
            try fixedString("CONDSTORE", buffer: &buffer, tracker: tracker)
            return .condstore
        }

        func parseSelectParameter_qresync(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SelectParameter {
            try fixedString("QRESYNC (", buffer: &buffer, tracker: tracker)
            let uidValidity = try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let modSeqVal = try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker)
            let knownUids = try optional(buffer: &buffer, tracker: tracker, parser: { (buffer, tracker) -> SequenceSet in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseKnownUids(buffer: &buffer, tracker: tracker)
            })
            let seqMatchData = try optional(buffer: &buffer, tracker: tracker, parser: { (buffer, tracker) -> SequenceMatchData in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseSequenceMatchData(buffer: &buffer, tracker: tracker)
            })
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return .qresync(.init(uidValiditiy: uidValidity, modificationSequenceValue: modSeqVal, knownUids: knownUids, sequenceMatchData: seqMatchData))
        }

        return try oneOf([
            parseSelectParameter_qresync,
            parseSelectParameter_condstore,
            parseSelectParameter_basic,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseKnownUids(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SequenceSet {
        try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
    }

    // select-params = SP "(" select-param *(SP select-param ")"
    static func parseParameters(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Parameter] {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [Parameter] in
            try fixedString(" (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseParameter(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> Parameter in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseParameter(buffer: &buffer, tracker: tracker)
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // Sequence Range
    static func parseSequenceRange(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SequenceRange {
        func parse_wildcard(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SequenceNumber {
            try fixedString("*", buffer: &buffer, tracker: tracker)
            return .max
        }

        func parse_SequenceOrWildcard(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SequenceNumber {
            try oneOf([
                parse_wildcard,
                GrammarParser.parseSequenceNumber,
            ], buffer: &buffer, tracker: tracker)
        }

        func parse_colonAndSequenceOrWildcard(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SequenceNumber {
            try fixedString(":", buffer: &buffer, tracker: tracker)
            return try parse_SequenceOrWildcard(buffer: &buffer, tracker: tracker)
        }

        return try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> SequenceRange in
            let id1 = try parse_SequenceOrWildcard(buffer: &buffer, tracker: tracker)
            let id2 = try optional(buffer: &buffer, tracker: tracker, parser: parse_colonAndSequenceOrWildcard)
            if let id = id2 {
                return SequenceRange(left: id1, right: id)
            } else if id1 == .max {
                return .all
            } else {
                return SequenceRange(id1)
            }
        }
    }

    static func parseSequenceMatchData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SequenceMatchData {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try fixedString("(", buffer: &buffer, tracker: tracker)
            let knownSequenceSet = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let knownUidSet = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return SequenceMatchData(knownSequenceSet: knownSequenceSet, knownUidSet: knownUidSet)
        }
    }

    // SequenceNumber
    // Note: the formal syntax is bogus here.
    // "*" is a sequence range, but not a sequence number.
    static func parseSequenceNumber(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SequenceNumber {
        guard let seq = SequenceNumber(rawValue: try self.parseNZNumber(buffer: &buffer, tracker: tracker)) else {
            throw ParserError(hint: "Sequence number out of range.")
        }
        return seq
    }

    // sequence-set    = (seq-number / seq-range) ["," sequence-set]
    // And from RFC 5182
    // sequence-set       =/ seq-last-command
    // seq-last-command   = "$"
    static func parseSequenceSet(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SequenceSet {
        func parseSequenceSet_number(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SequenceRange {
            let num = try self.parseSequenceNumber(buffer: &buffer, tracker: tracker)
            return SequenceRange(num)
        }

        func parseSequenceSet_element(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SequenceRange {
            try oneOf([
                self.parseSequenceRange,
                parseSequenceSet_number,
            ], buffer: &buffer, tracker: tracker)
        }

        func parseSequenceSet_base(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SequenceSet {
            try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                var output = [try parseSequenceSet_element(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { buffer, tracker in
                    try fixedString(",", buffer: &buffer, tracker: tracker)
                    return try parseSequenceSet_element(buffer: &buffer, tracker: tracker)
                }
                guard let s = SequenceRangeSet(output) else {
                    throw ParserError(hint: "Sequence set is empty.")
                }
                return .range(s)
            }
        }

        func parseSequenceSet_lastCommand(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SequenceSet {
            try fixedString("$", buffer: &buffer, tracker: tracker)
            return .lastCommand
        }

        return try oneOf([
            parseSequenceSet_base,
            parseSequenceSet_lastCommand,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseSortData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SortData? {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> SortData? in
            try fixedString("SORT", buffer: &buffer, tracker: tracker)
            let _components = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ([Int], SearchSortModificationSequence) in
                try space(buffer: &buffer, tracker: tracker)
                var array = [try self.parseNZNumber(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { (buffer, tracker) in
                    try space(buffer: &buffer, tracker: tracker)
                    return try self.parseNZNumber(buffer: &buffer, tracker: tracker)
                })
                try space(buffer: &buffer, tracker: tracker)
                let seq = try self.parseSearchSortModificationSequence(buffer: &buffer, tracker: tracker)
                return (array, seq)
            }

            guard let components = _components else {
                return nil
            }
            return SortData(identifiers: components.0, modificationSequence: components.1)
        }
    }

    // uid-set
    static func parseUIDSet(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UIDSet {
        func parseUIDSet_number(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UIDRange {
            let num = try self.parseUID(buffer: &buffer, tracker: tracker)
            return UIDRange(num)
        }

        func parseUIDSet_element(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UIDRange {
            try oneOf([
                self.parseUIDRange,
                parseUIDSet_number,
            ], buffer: &buffer, tracker: tracker)
        }

        return try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            var output = [try parseUIDSet_element(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { buffer, tracker in
                try fixedString(",", buffer: &buffer, tracker: tracker)
                return try parseUIDSet_element(buffer: &buffer, tracker: tracker)
            }
            guard let s = UIDSet(output) else {
                throw ParserError(hint: "UID set is empty.")
            }
            return s
        }
    }

    // status          = "STATUS" SP mailbox SP
    //                   "(" status-att *(SP status-att) ")"
    static func parseStatus(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("STATUS ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try fixedString(" (", buffer: &buffer, tracker: tracker)
            var atts = [try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &atts, tracker: tracker) { buffer, tracker -> MailboxAttribute in
                try fixedString(" ", buffer: &buffer, tracker: tracker)
                return try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return .status(mailbox, atts)
        }
    }

    // status-att      = "MESSAGES" / "UIDNEXT" / "UIDVALIDITY" /
    //                   "UNSEEN" / "DELETED" / "SIZE"
    static func parseStatusAttribute(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxAttribute {
        let string = try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { c -> Bool in
            isalpha(Int32(c)) != 0
        }
        guard let att = MailboxAttribute(rawValue: string.uppercased()) else {
            throw ParserError(hint: "Found \(string) which was not a status attribute")
        }
        return att
    }

    // status-att-list  = status-att-val *(SP status-att-val)
    static func parseMailboxStatus(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxStatus {
        enum MailboxValue: Equatable {
            case messages(Int)
            case uidNext(Int)
            case uidValidity(Int)
            case unseen(Int)
            case size(Int)
            case recent(Int)
            case highestModifierSequence(ModificationSequenceValue)
        }

        func parseStatusAttributeValue_messages(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try fixedString("MESSAGES ", buffer: &buffer, tracker: tracker)
            return .messages(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_uidnext(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try fixedString("UIDNEXT ", buffer: &buffer, tracker: tracker)
            return .uidNext(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_uidvalidity(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try fixedString("UIDVALIDITY ", buffer: &buffer, tracker: tracker)
            return .uidValidity(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_unseen(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try fixedString("UNSEEN ", buffer: &buffer, tracker: tracker)
            return .unseen(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_size(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try fixedString("SIZE ", buffer: &buffer, tracker: tracker)
            return .size(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_modificationSequence(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try fixedString("HIGHESTMODSEQ ", buffer: &buffer, tracker: tracker)
            return .highestModifierSequence(try self.parseModificationSequenceValue(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_recent(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try fixedString("RECENT ", buffer: &buffer, tracker: tracker)
            return .recent(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try oneOf([
                parseStatusAttributeValue_messages,
                parseStatusAttributeValue_uidnext,
                parseStatusAttributeValue_uidvalidity,
                parseStatusAttributeValue_unseen,
                parseStatusAttributeValue_size,
                parseStatusAttributeValue_modificationSequence,
                parseStatusAttributeValue_recent,
            ], buffer: &buffer, tracker: tracker)
        }

        return try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> MailboxStatus in

            var array = [try parseStatusAttributeValue(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> MailboxValue in
                try space(buffer: &buffer, tracker: tracker)
                return try parseStatusAttributeValue(buffer: &buffer, tracker: tracker)
            }

            var status = MailboxStatus()
            for value in array {
                switch value {
                case .messages(let messages):
                    status.messageCount = messages
                case .highestModifierSequence(let modSequence):
                    status.highestModificationSequence = modSequence
                case .size(let size):
                    status.size = size
                case .uidNext(let uidNext):
                    status.nextUID = uidNext
                case .uidValidity(let uidValidity):
                    status.uidValidity = uidValidity
                case .unseen(let unseen):
                    status.unseenCount = unseen
                case .recent(let recent):
                    status.recentCount = recent
                }
            }
            return status
        }
    }

    // status-option = "STATUS" SP "(" status-att *(SP status-att) ")"
    static func parseStatusOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [MailboxAttribute] {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [MailboxAttribute] in
            try fixedString("STATUS (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> MailboxAttribute in
                try space(buffer: &buffer, tracker: tracker)
                return try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // store           = "STORE" SP sequence-set SP store-att-flags
    static func parseStore(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("STORE ", buffer: &buffer, tracker: tracker)
            let sequence = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            let modifiers = try optional(buffer: &buffer, tracker: tracker) { buffer, tracker -> [StoreModifier] in
                try space(buffer: &buffer, tracker: tracker)
                try fixedString("(", buffer: &buffer, tracker: tracker)
                var array = [try self.parseStoreModifier(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker, parser: { (buffer, tracker) in
                    try space(buffer: &buffer, tracker: tracker)
                    return try self.parseStoreModifier(buffer: &buffer, tracker: tracker)
                })
                try fixedString(")", buffer: &buffer, tracker: tracker)
                return array
            } ?? []
            try space(buffer: &buffer, tracker: tracker)
            let flags = try self.parseStoreAttributeFlags(buffer: &buffer, tracker: tracker)
            return .store(sequence, modifiers, flags)
        }
    }

    static func parseStoreModifier(buffer: inout ByteBuffer, tracker: StackTracker) throws -> StoreModifier {
        func parseFetchModifier_unchangedSince(buffer: inout ByteBuffer, tracker: StackTracker) throws -> StoreModifier {
            .unchangedSince(try self.parseUnchangedSinceModifier(buffer: &buffer, tracker: tracker))
        }

        func parseFetchModifier_other(buffer: inout ByteBuffer, tracker: StackTracker) throws -> StoreModifier {
            .other(try self.parseParameter(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseFetchModifier_unchangedSince,
            parseFetchModifier_other,
        ], buffer: &buffer, tracker: tracker)
    }

    // store-att-flags = (["+" / "-"] "FLAGS" [".SILENT"]) SP
    //                   (flag-list / (flag *(SP flag)))
    static func parseStoreAttributeFlags(buffer: inout ByteBuffer, tracker: StackTracker) throws -> StoreFlags {
        func parseStoreAttributeFlags_silent(buffer: inout ByteBuffer, tracker: StackTracker) -> Bool {
            do {
                try fixedString(".SILENT", buffer: &buffer, tracker: tracker)
                return true
            } catch {
                return false
            }
        }

        func parseStoreAttributeFlags_array(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Flag] {
            try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [Flag] in
                var output = [try self.parseFlag(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { (buffer, tracker) -> Flag in
                    try space(buffer: &buffer, tracker: tracker)
                    return try self.parseFlag(buffer: &buffer, tracker: tracker)
                }
                return output
            }
        }

        func parseStoreAttributeFlags_operation(buffer: inout ByteBuffer, tracker: StackTracker) throws -> StoreFlags.Operation {
            try oneOf([
                { (buffer: inout ByteBuffer, tracker: StackTracker) -> StoreFlags.Operation in
                    try fixedString("+FLAGS", buffer: &buffer, tracker: tracker)
                    return .add
                },
                { (buffer: inout ByteBuffer, tracker: StackTracker) -> StoreFlags.Operation in
                    try fixedString("-FLAGS", buffer: &buffer, tracker: tracker)
                    return .remove
                },
                { (buffer: inout ByteBuffer, tracker: StackTracker) -> StoreFlags.Operation in
                    try fixedString("FLAGS", buffer: &buffer, tracker: tracker)
                    return .replace
                },
            ], buffer: &buffer, tracker: tracker)
        }

        return try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> StoreFlags in
            let operation = try parseStoreAttributeFlags_operation(buffer: &buffer, tracker: tracker)
            let silent = parseStoreAttributeFlags_silent(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let flags = try oneOf([
                parseStoreAttributeFlags_array,
                parseFlagList,
            ], buffer: &buffer, tracker: tracker)
            return StoreFlags(operation: operation, silent: silent, flags: flags)
        }
    }

    // string          = quoted / literal
    static func parseString(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try oneOf([
            Self.parseQuoted,
            Self.parseLiteral,
        ], buffer: &buffer, tracker: tracker)
    }

    // subscribe       = "SUBSCRIBE" SP mailbox
    static func parseSubscribe(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("SUBSCRIBE ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .subscribe(mailbox)
        }
    }

    // tag             = 1*<any ASTRING-CHAR except "+">
    static func parseTag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            char.isAStringChar && char != UInt8(ascii: "+")
        }
    }

    // tagged-ext = tagged-ext-label SP tagged-ext-val
    static func parseTaggedExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedExtension {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let label = try self.parseParameterName(buffer: &buffer, tracker: tracker)

            // Warning: weird hack alert.
            // CATENATE (RFC 4469) has basically identical syntax to tagged extensions, but it is actually append-data.
            // to avoid that being a problem here, we check if we just parsed `CATENATE`. If we did, we bail out: this is
            // data now.
            if label.lowercased() == "catenate" {
                throw ParserError(hint: "catenate extension")
            }

            try space(buffer: &buffer, tracker: tracker)
            let value = try self.parseParameterValue(buffer: &buffer, tracker: tracker)
            return .init(label: label, value: value)
        }
    }

    // tagged-ext-label    = tagged-label-fchar *tagged-label-char
    static func parseParameterName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> String in

            guard let fchar = buffer.readBytes(length: 1)?.first else {
                throw _IncompleteMessage()
            }
            guard fchar.isTaggedLabelFchar else {
                throw ParserError(hint: "\(fchar) is not a valid fchar’")
            }

            let trailing = try ParserLibrary.parseZeroOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
                char.isTaggedLabelChar
            }

            return String(decoding: [fchar], as: Unicode.UTF8.self) + trailing
        }
    }

    // astring
    // continuation = ( SP tagged-ext-comp )*
    // tagged-ext-comp = astring continuation | '(' tagged-ext-comp ')' continuation
    static func parseTaggedExtensionComplex_continuation(
        into: inout [String],
        buffer: inout ByteBuffer,
        tracker: StackTracker
    ) throws {
        while true {
            do {
                try space(buffer: &buffer, tracker: tracker)
                try self.parseTaggedExtensionComplex_helper(into: &into, buffer: &buffer, tracker: tracker)
            } catch {
                return
            }
        }
    }

    static func parseTaggedExtensionComplex_helper(
        into: inout [String],
        buffer: inout ByteBuffer,
        tracker: StackTracker
    ) throws {
        func parseTaggedExtensionComplex_string(
            into: inout [String],
            buffer: inout ByteBuffer,
            tracker: StackTracker
        ) throws {
            into.append(String(buffer: try self.parseAString(buffer: &buffer, tracker: tracker)))
            try self.parseTaggedExtensionComplex_continuation(into: &into, buffer: &buffer, tracker: tracker)
        }

        func parseTaggedExtensionComplex_bracketed(
            into: inout [String],
            buffer: inout ByteBuffer,
            tracker: StackTracker
        ) throws {
            try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try fixedString("(", buffer: &buffer, tracker: tracker)
                try self.parseTaggedExtensionComplex_helper(into: &into, buffer: &buffer, tracker: tracker)
                try fixedString(")", buffer: &buffer, tracker: tracker)
                try self.parseTaggedExtensionComplex_continuation(into: &into, buffer: &buffer, tracker: tracker)
            }
        }

        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let save = buffer
            do {
                try parseTaggedExtensionComplex_string(into: &into, buffer: &buffer, tracker: tracker)
            } catch {
                buffer = save
                try parseTaggedExtensionComplex_bracketed(into: &into, buffer: &buffer, tracker: tracker)
            }
        }
    }

    // NOTE: Left-recursive, modification above, this needs some work
    // tagged-ext-comp     = astring /
    //                       tagged-ext-comp *(SP tagged-ext-comp) /
    //                       "(" tagged-ext-comp ")"
    static func parseTaggedExtensionComplex(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [String] {
        var result = [String]()
        try self.parseTaggedExtensionComplex_helper(into: &result, buffer: &buffer, tracker: tracker)
        return result
    }

    // tagged-ext-val      = tagged-ext-simple /
    //                       "(" [tagged-ext-comp] ")"
    static func parseParameterValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ParameterValue {
        func parseTaggedExtensionSimple_set(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ParameterValue {
            .sequence(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        func parseTaggedExtensionVal_comp(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ParameterValue {
            try fixedString("(", buffer: &buffer, tracker: tracker)
            let comp = try optional(buffer: &buffer, tracker: tracker, parser: self.parseTaggedExtensionComplex) ?? []
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return .comp(comp)
        }

        return try oneOf([
            parseTaggedExtensionSimple_set,
            parseTaggedExtensionVal_comp,
        ], buffer: &buffer, tracker: tracker)
    }

    // text            = 1*TEXT-CHAR
    static func parseText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try ParserLibrary.parseOneOrMoreCharactersByteBuffer(buffer: &buffer, tracker: tracker) { char -> Bool in
            char.isTextChar
        }
    }

    static func parseUAuthMechanism(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UAuthMechanism {
        let string = try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker, where: { char in
            switch char {
            case UInt8(ascii: "a") ... UInt8(ascii: "z"),
                 UInt8(ascii: "A") ... UInt8(ascii: "Z"),
                 UInt8(ascii: "0") ... UInt8(ascii: "9"),
                 UInt8(ascii: "-"),
                 UInt8(ascii: "."):
                return true
            default:
                return false
            }
        })
        return UAuthMechanism(rawValue: string)
    }

    // uid             = "UID" SP
    //                   (copy / move / fetch / search / store / uid-expunge)
    static func parseUid(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        func parseUid_copy(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
                try fixedString("COPY ", buffer: &buffer, tracker: tracker)
                let set = try self.parseUIDSet(buffer: &buffer, tracker: tracker)
                try fixedString(" ", buffer: &buffer, tracker: tracker)
                let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
                return .uidCopy(set, mailbox)
            }
        }

        func parseUid_move(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
                try fixedString("MOVE ", buffer: &buffer, tracker: tracker)
                let set = try self.parseUIDSet(buffer: &buffer, tracker: tracker)
                try space(buffer: &buffer, tracker: tracker)
                let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
                return .uidMove(set, mailbox)
            }
        }

        func parseUid_fetch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
                try fixedString("FETCH ", buffer: &buffer, tracker: tracker)
                let set = try self.parseUIDSet(buffer: &buffer, tracker: tracker)
                try space(buffer: &buffer, tracker: tracker)
                let att = try parseFetch_type(buffer: &buffer, tracker: tracker)
                let modifiers = try optional(buffer: &buffer, tracker: tracker, parser: self.parseParameters) ?? []
                return .uidFetch(set, att, modifiers)
            }
        }

        func parseUid_search(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            guard case .search(let key, let charset, let returnOptions) = try self.parseSearch(buffer: &buffer, tracker: tracker) else {
                fatalError("This should never happen")
            }
            return .uidSearch(key: key, charset: charset, returnOptions: returnOptions)
        }

        func parseUid_store(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
                try fixedString("STORE ", buffer: &buffer, tracker: tracker)
                let set = try self.parseUIDSet(buffer: &buffer, tracker: tracker)
                let modifiers = try optional(buffer: &buffer, tracker: tracker, parser: self.parseParameters) ?? []
                try space(buffer: &buffer, tracker: tracker)
                let flags = try self.parseStoreAttributeFlags(buffer: &buffer, tracker: tracker)
                return .uidStore(set, modifiers, flags)
            }
        }

        func parseUid_expunge(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try fixedString("EXPUNGE ", buffer: &buffer, tracker: tracker)
            let set = try self.parseUIDSet(buffer: &buffer, tracker: tracker)
            return .uidExpunge(set)
        }

        return try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("UID ", buffer: &buffer, tracker: tracker)
            return try oneOf([
                parseUid_copy,
                parseUid_move,
                parseUid_fetch,
                parseUid_search,
                parseUid_store,
                parseUid_expunge,
            ], buffer: &buffer, tracker: tracker)
        }
    }

    // uid-range       = (uniqueid ":" uniqueid)
    static func parseUIDRange(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UIDRange {
        func parse_wildcard(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UID {
            try fixedString("*", buffer: &buffer, tracker: tracker)
            return .max
        }

        func parse_UIDOrWildcard(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UID {
            try oneOf([
                parse_wildcard,
                GrammarParser.parseUID,
            ], buffer: &buffer, tracker: tracker)
        }

        func parse_colonAndUIDOrWildcard(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UID {
            try fixedString(":", buffer: &buffer, tracker: tracker)
            return try parse_UIDOrWildcard(buffer: &buffer, tracker: tracker)
        }

        return try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> UIDRange in
            let id1 = try parse_UIDOrWildcard(buffer: &buffer, tracker: tracker)
            let id2 = try optional(buffer: &buffer, tracker: tracker, parser: parse_colonAndUIDOrWildcard)
            if let id = id2 {
                return UIDRange(left: id1, right: id)
            } else if id1 == .max {
                return .all
            } else {
                return UIDRange(id1)
            }
        }
    }

    // uniqueid        = nz-number
    static func parseUID(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UID {
        guard let uid = UID(rawValue: try self.parseNZNumber(buffer: &buffer, tracker: tracker)) else {
            throw ParserError(hint: "UID out of range.")
        }
        return uid
    }

    // uniqueid        = nz-number
    static func parseUIDValidity(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UIDValidity {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try fixedString(";UIDVALIDITY=", buffer: &buffer, tracker: tracker)
            let num = try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            return try UIDValidity(uid: num)
        }
    }

    // unsubscribe     = "UNSUBSCRIBE" SP mailbox
    static func parseUnsubscribe(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try fixedString("UNSUBSCRIBE ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .unsubscribe(mailbox)
        }
    }

    // userid          = astring
    static func parseUserId(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        var astring = try Self.parseAString(buffer: &buffer, tracker: tracker)
        return astring.readString(length: astring.readableBytes)! // if this fails, something has gone very, very wrong
    }

    // vendor-token     = atom (maybe?!?!?!)
    static func parseVendorToken(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            char.isAlpha
        }
    }

    // RFC 2087 = "GETQUOTA" / "GETQUOTAROOT" / "SETQUOTA"
    static func parseCommandQuota(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        func parseQuotaRoot(buffer: inout ByteBuffer, tracker: StackTracker) throws -> QuotaRoot {
            let string = try self.parseAString(buffer: &buffer, tracker: tracker)
            return QuotaRoot(string)
        }

        // setquota_list   ::= "(" 0#setquota_resource ")"
        func parseQuotaLimits(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [QuotaLimit] {
            // setquota_resource ::= atom SP number
            func parseQuotaLimit(buffer: inout ByteBuffer, tracker: StackTracker) throws -> QuotaLimit {
                try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                    let resourceName = try parseAtom(buffer: &buffer, tracker: tracker)
                    try space(buffer: &buffer, tracker: tracker)
                    let limit = try parseNumber(buffer: &buffer, tracker: tracker)
                    return QuotaLimit(resourceName: resourceName, limit: limit)
                }
            }

            return try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) throws -> [QuotaLimit] in
                try fixedString("(", buffer: &buffer, tracker: tracker)
                var limits: [QuotaLimit] = []
                try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                    while let limit = try optional(buffer: &buffer, tracker: tracker, parser: parseQuotaLimit) {
                        limits.append(limit)
                        if try optional(buffer: &buffer, tracker: tracker, parser: space) == nil {
                            break
                        }
                    }
                }
                try fixedString(")", buffer: &buffer, tracker: tracker)
                return limits
            }
        }

        // getquota        ::= "GETQUOTA" SP astring
        func parseCommandQuota_getQuota(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                try fixedString("GETQUOTA ", buffer: &buffer, tracker: tracker)
                let quotaRoot = try parseQuotaRoot(buffer: &buffer, tracker: tracker)
                return .getQuota(quotaRoot)
            }
        }

        // getquotaroot    ::= "GETQUOTAROOT" SP astring
        func parseCommandQuota_getQuotaRoot(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                try fixedString("GETQUOTAROOT ", buffer: &buffer, tracker: tracker)
                let mailbox = try parseMailbox(buffer: &buffer, tracker: tracker)
                return .getQuotaRoot(mailbox)
            }
        }

        // setquota        ::= "SETQUOTA" SP astring SP setquota_list
        func parseCommandQuota_setQuota(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                try fixedString("SETQUOTA ", buffer: &buffer, tracker: tracker)
                let quotaRoot = try parseQuotaRoot(buffer: &buffer, tracker: tracker)
                try space(buffer: &buffer, tracker: tracker)
                let quotaLimits = try parseQuotaLimits(buffer: &buffer, tracker: tracker)
                return .setQuota(quotaRoot, quotaLimits)
            }
        }

        return try oneOf([
            parseCommandQuota_getQuota,
            parseCommandQuota_getQuotaRoot,
            parseCommandQuota_setQuota,
        ], buffer: &buffer, tracker: tracker)
    }

    // quota_response  ::= "QUOTA" SP astring SP quota_list
    static func parseResponsePayload_quota(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponsePayload {
        // quota_resource  ::= atom SP number SP number
        func parseQuotaResource(buffer: inout ByteBuffer, tracker: StackTracker) throws -> QuotaResource {
            try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                let resourceName = try parseAtom(buffer: &buffer, tracker: tracker)
                try space(buffer: &buffer, tracker: tracker)
                let usage = try parseNumber(buffer: &buffer, tracker: tracker)
                try space(buffer: &buffer, tracker: tracker)
                let limit = try parseNumber(buffer: &buffer, tracker: tracker)
                return QuotaResource(resourceName: resourceName, usage: usage, limit: limit)
            }
        }

        // quota_list      ::= "(" #quota_resource ")"
        func parseQuotaList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [QuotaResource] {
            try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                try fixedString("(", buffer: &buffer, tracker: tracker)
                var resources: [QuotaResource] = []
                while let resource = try optional(buffer: &buffer, tracker: tracker, parser: parseQuotaResource) {
                    resources.append(resource)
                    if try optional(buffer: &buffer, tracker: tracker, parser: space) == nil {
                        break
                    }
                }
                try fixedString(")", buffer: &buffer, tracker: tracker)
                return resources
            }
        }

        return try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try fixedString("QUOTA ", buffer: &buffer, tracker: tracker)
            let quotaRoot = try parseAString(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let resources = try parseQuotaList(buffer: &buffer, tracker: tracker)
            return .quota(.init(quotaRoot), resources)
        }
    }

    // quotaroot_response ::= "QUOTAROOT" SP astring *(SP astring)
    static func parseResponsePayload_quotaRoot(buffer: inout ByteBuffer,
                                               tracker: StackTracker) throws -> ResponsePayload {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try fixedString("QUOTAROOT ", buffer: &buffer, tracker: tracker)
            let mailbox = try parseMailbox(buffer: &buffer, tracker: tracker)
            try space(buffer: &buffer, tracker: tracker)
            let quotaRoot = try parseAString(buffer: &buffer, tracker: tracker)
            return .quotaRoot(mailbox, .init(quotaRoot))
        }
    }

    // RFC 5465
    // one-or-more-mailbox = mailbox / many-mailboxes
    static func parseOneOrMoreMailbox(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Mailboxes {
        // many-mailboxes  = "(" mailbox *(SP mailbox) ")
        func parseManyMailboxes(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Mailboxes {
            try fixedString("(", buffer: &buffer, tracker: tracker)
            var mailboxes: [MailboxName] = [try parseMailbox(buffer: &buffer, tracker: tracker)]
            while try optional(buffer: &buffer, tracker: tracker, parser: space) != nil {
                mailboxes.append(try parseMailbox(buffer: &buffer, tracker: tracker))
            }
            try fixedString(")", buffer: &buffer, tracker: tracker)
            if let returnValue = Mailboxes(mailboxes) {
                return returnValue
            } else {
                throw ParserError(hint: "Failed to unwrap mailboxes which should be impossible")
            }
        }

        func parseSingleMailboxes(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Mailboxes {
            let mailboxes: [MailboxName] = [try parseMailbox(buffer: &buffer, tracker: tracker)]
            if let returnValue = Mailboxes(mailboxes) {
                return returnValue
            } else {
                throw ParserError(hint: "Failed to unwrap single mailboxes which should be impossible")
            }
        }

        return try oneOf([
            parseManyMailboxes,
            parseSingleMailboxes,
        ], buffer: &buffer, tracker: tracker)
    }

    // RFC 5465
    // filter-mailboxes = filter-mailboxes-selected / filter-mailboxes-other
    static func parseFilterMailboxes(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxFilter {
        // filter-mailboxes-selected = "selected" / "selected-delayed"
        func parseFilterMailboxes_Selected(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try fixedString("selected", buffer: &buffer, tracker: tracker)
            return .selected
        }

        func parseFilterMailboxes_SelectedDelayed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try fixedString("selected-delayed", buffer: &buffer, tracker: tracker)
            return .selectedDelayed
        }

        // filter-mailboxes-other = "inboxes" / "personal" / "subscribed" /
        // ( "subtree" SP one-or-more-mailbox ) /
        // ( "mailboxes" SP one-or-more-mailbox )
        func parseFilterMailboxes_Inboxes(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try fixedString("inboxes", buffer: &buffer, tracker: tracker)
            return .inboxes
        }

        func parseFilterMailboxes_Personal(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try fixedString("personal", buffer: &buffer, tracker: tracker)
            return .personal
        }

        func parseFilterMailboxes_Subscribed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try fixedString("subscribed", buffer: &buffer, tracker: tracker)
            return .subscribed
        }

        func parseFilterMailboxes_Subtree(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try fixedString("subtree ", buffer: &buffer, tracker: tracker)
            return .subtree(try parseOneOrMoreMailbox(buffer: &buffer, tracker: tracker))
        }

        func parseFilterMailboxes_Mailboxes(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try fixedString("mailboxes ", buffer: &buffer, tracker: tracker)
            return .mailboxes(try parseOneOrMoreMailbox(buffer: &buffer, tracker: tracker))
        }

        // RFC 6237
        // filter-mailboxes-other =/  ("subtree-one" SP one-or-more-mailbox)
        func parseFilterMailboxes_SubtreeOne(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxFilter {
            try fixedString("subtree-one ", buffer: &buffer, tracker: tracker)
            return .subtreeOne(try parseOneOrMoreMailbox(buffer: &buffer, tracker: tracker))
        }

        return try oneOf([
            parseFilterMailboxes_SelectedDelayed,
            parseFilterMailboxes_SubtreeOne,
            parseFilterMailboxes_Selected,
            parseFilterMailboxes_Inboxes,
            parseFilterMailboxes_Personal,
            parseFilterMailboxes_Subscribed,
            parseFilterMailboxes_Subtree,
            parseFilterMailboxes_Mailboxes,
        ], buffer: &buffer, tracker: tracker)
    }

    // RFC 6237
    // scope-option =  scope-option-name [SP scope-option-value]
    // scope-option-name =  tagged-ext-label
    // scope-option-value =  tagged-ext-val
    static func parseESearchScopeOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ESearchScopeOption {
        func parseESearchScopeOption_value(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ParameterValue {
            try space(buffer: &buffer, tracker: tracker)
            return try self.parseParameterValue(buffer: &buffer, tracker: tracker)
        }

        let label = try self.parseParameterName(buffer: &buffer, tracker: tracker)
        let value = try optional(buffer: &buffer,
                                 tracker: tracker,
                                 parser: parseESearchScopeOption_value)
        return ESearchScopeOption(name: label, value: value)
    }

    // RFC 6237
    // scope-options =  scope-option *(SP scope-option)
    static func parseESearchScopeOptions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ESearchScopeOptions {
        var options: [ESearchScopeOption] = [try parseESearchScopeOption(buffer: &buffer, tracker: tracker)]
        while try optional(buffer: &buffer, tracker: tracker, parser: space) != nil {
            options.append(try parseESearchScopeOption(buffer: &buffer, tracker: tracker))
        }
        if let returnValue = ESearchScopeOptions(options) {
            return returnValue
        } else {
            throw ParserError(hint: "Failed to unwrap ESearchScopeOptions which should be impossible.")
        }
    }

    // RFC 6237
    // esearch-source-opts =  "IN" SP "(" source-mbox [SP "(" scope-options ")"] ")"
    static func parseEsearchSourceOptions(buffer: inout ByteBuffer,
                                          tracker: StackTracker) throws -> ESearchSourceOptions {
        func parseEsearchSourceOptions_spaceFilter(buffer: inout ByteBuffer,
                                                   tracker: StackTracker) throws -> MailboxFilter {
            try space(buffer: &buffer, tracker: tracker)
            return try parseFilterMailboxes(buffer: &buffer, tracker: tracker)
        }

        // source-mbox =  filter-mailboxes *(SP filter-mailboxes)
        func parseEsearchSourceOptions_sourceMBox(buffer: inout ByteBuffer,
                                                  tracker: StackTracker) throws -> [MailboxFilter] {
            var sources = [try parseFilterMailboxes(buffer: &buffer, tracker: tracker)]
            while let anotherSource = try optional(buffer: &buffer,
                                                   tracker: tracker,
                                                   parser: parseEsearchSourceOptions_spaceFilter) {
                sources.append(anotherSource)
            }
            return sources
        }

        func parseEsearchSourceOptions_scopeOptions(buffer: inout ByteBuffer,
                                                    tracker: StackTracker) throws -> ESearchScopeOptions {
            try fixedString(" (", buffer: &buffer, tracker: tracker)
            let result = try parseESearchScopeOptions(buffer: &buffer, tracker: tracker)
            try fixedString(")", buffer: &buffer, tracker: tracker)
            return result
        }

        return try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try fixedString("IN (", buffer: &buffer, tracker: tracker)
            let sourceMbox = try parseEsearchSourceOptions_sourceMBox(buffer: &buffer, tracker: tracker)
            let scopeOptions = try optional(buffer: &buffer,
                                            tracker: tracker,
                                            parser: parseEsearchSourceOptions_scopeOptions)
            try fixedString(")", buffer: &buffer, tracker: tracker)
            if let result = ESearchSourceOptions(sourceMailbox: sourceMbox, scopeOptions: scopeOptions) {
                return result
            } else {
                throw ParserError(hint: "Failed to construct esearch source options")
            }
        }
    }

    // RFC 6237
    // esearch =  "ESEARCH" [SP esearch-source-opts]
    // [SP search-return-opts] SP search-program
    // Ignoring the command here.
    static func parseEsearchOptions(buffer: inout ByteBuffer,
                                    tracker: StackTracker) throws -> ESearchOptions {
        func parseEsearchOptions_sourceOptions(buffer: inout ByteBuffer,
                                               tracker: StackTracker) throws -> ESearchSourceOptions {
            try space(buffer: &buffer, tracker: tracker)
            let result = try parseEsearchSourceOptions(buffer: &buffer, tracker: tracker)
            return result
        }

        let sourceOptions = try optional(buffer: &buffer,
                                         tracker: tracker,
                                         parser: parseEsearchOptions_sourceOptions)
        let returnOpts = try optional(buffer: &buffer,
                                      tracker: tracker,
                                      parser: self.parseSearchReturnOptions) ?? []
        try space(buffer: &buffer, tracker: tracker)
        let (charset, program) = try parseSearchProgram(buffer: &buffer, tracker: tracker)
        return ESearchOptions(key: program, charset: charset, returnOptions: returnOpts, sourceOptions: sourceOptions)
    }

    // RFC 6237
    // esearch =  "ESEARCH" [SP esearch-source-opts]
    // [SP search-return-opts] SP search-program
    static func parseEsearch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try fixedString("ESEARCH", buffer: &buffer, tracker: tracker)
            return .esearch(try parseEsearchOptions(buffer: &buffer, tracker: tracker))
        }
    }
}

// MARK: - Helper Parsers

extension GrammarParser {
    static func parseBodyLocationExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.LocationAndExtensions {
        let fieldLocation = try self.parseNString(buffer: &buffer, tracker: tracker).flatMap { String(buffer: $0) }
        let extensions = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [BodyExtension] in
            try space(buffer: &buffer, tracker: tracker)
            return try self.parseBodyExtension(buffer: &buffer, tracker: tracker)
        }
        return BodyStructure.LocationAndExtensions(location: fieldLocation, extensions: extensions)
    }

    static func parseBodyLanguageLocation(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.LanguageLocation {
        let fieldLanguage = try self.parseBodyFieldLanguage(buffer: &buffer, tracker: tracker)
        let locationExtension = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> BodyStructure.LocationAndExtensions in
            try space(buffer: &buffer, tracker: tracker)
            return try parseBodyLocationExtension(buffer: &buffer, tracker: tracker)
        }
        return BodyStructure.LanguageLocation(languages: fieldLanguage, location: locationExtension)
    }

    static func parseBodyDescriptionLanguage(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.DispositionAndLanguage {
        let description = try self.parseBodyFieldDsp(buffer: &buffer, tracker: tracker)
        let language = try optional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> BodyStructure.LanguageLocation in
            try space(buffer: &buffer, tracker: tracker)
            return try parseBodyLanguageLocation(buffer: &buffer, tracker: tracker)
        }
        return BodyStructure.DispositionAndLanguage(disposition: description, language: language)
    }

    static func parse2Digit(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        try self.parseNDigits(buffer: &buffer, tracker: tracker, bytes: 2)
    }

    static func parse4Digit(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        try self.parseNDigits(buffer: &buffer, tracker: tracker, bytes: 4)
    }

    static func parseNDigits(buffer: inout ByteBuffer, tracker: StackTracker, bytes: Int) throws -> Int {
        try composite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let (num, size) = try ParserLibrary.parseUnsignedInteger(buffer: &buffer, tracker: tracker)
            guard size == bytes else {
                throw ParserError(hint: "Expected \(bytes) digits, got \(size)")
            }
            return num
        }
    }

    // reusable for a lot of the env-* types
    static func parseEnvelopeAddresses(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Address] {
        try fixedString("(", buffer: &buffer, tracker: tracker)
        let addresses = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try self.parseAddress(buffer: &buffer, tracker: tracker)
        }
        try fixedString(")", buffer: &buffer, tracker: tracker)
        return addresses
    }

    static func parseOptionalEnvelopeAddresses(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Address] {
        func parseOptionalEnvelopeAddresses_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Address] {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return []
        }
        return try oneOf([
            parseEnvelopeAddresses,
            parseOptionalEnvelopeAddresses_nil,
        ], buffer: &buffer, tracker: tracker)
    }
}

struct StackTracker {
    private var stackDepth = 0
    private let maximumStackDepth: Int

    static var makeNewDefaultLimitStackTracker: StackTracker {
        StackTracker(maximumParserStackDepth: 100)
    }

    init(maximumParserStackDepth: Int) {
        self.maximumStackDepth = maximumParserStackDepth
    }

    mutating func newStackFrame() throws {
        self.stackDepth += 1
        guard self.stackDepth < self.maximumStackDepth else {
            throw TooDeep()
        }
    }
}

// MARK: - Parser Library

extension GrammarParser {
    static func space(buffer: inout ByteBuffer, tracker: StackTracker) throws {
        try composite(buffer: &buffer, tracker: tracker) { buffer, _ in

            // need at least one readable byte
            guard buffer.readableBytes > 0 else { throw _IncompleteMessage() }

            // if there are only spaces then just consume it all and move on
            guard let index = buffer.readableBytesView.firstIndex(where: { $0 != UInt8(ascii: " ") }) else {
                buffer.moveReaderIndex(to: buffer.writerIndex)
                return
            }

            // first character wasn't a space
            guard index > buffer.readableBytesView.startIndex else {
                throw ParserError(hint: "Expected space, found \(buffer.readableBytesView[index])")
            }

            buffer.moveReaderIndex(to: index)
        }
    }

    static func fixedString(_ needle: String, caseSensitive: Bool = false, buffer: inout ByteBuffer, tracker: StackTracker) throws {
        try composite(buffer: &buffer, tracker: tracker) { buffer, _ in
            let needleCount = needle.utf8.count
            guard let actual = buffer.readString(length: needleCount) else {
                guard needle.utf8.starts(with: buffer.readableBytesView, by: { $0 & 0xDF == $1 & 0xDF }) else {
                    throw ParserError(hint: "Tried to parse \(needle) in \(String(decoding: buffer.readableBytesView, as: Unicode.UTF8.self))")
                }
                throw _IncompleteMessage()
            }

            assert(needle.utf8.allSatisfy { $0 & 0b1000_0000 == 0 }, "needle needs to be ASCII but \(needle) isn't")
            if actual == needle {
                // great, we just match
                return
            } else if !caseSensitive {
                // we know this is all ASCII so we can do an ASCII case-insensitive compare here
                guard needleCount == actual.utf8.count,
                    actual.utf8.elementsEqual(needle.utf8, by: { ($0 & 0xDF) == ($1 & 0xDF) }) else {
                    throw ParserError(hint: "case insensitively looking for \(needle) found \(actual)")
                }
                return
            } else {
                throw ParserError(hint: "case sensitively looking for \(needle) found \(actual)")
            }
        }
    }

    static func oneOf<T>(_ subParsers: [SubParser<T>], buffer: inout ByteBuffer, tracker: StackTracker, file: String = (#file), line: Int = #line) throws -> T {
        for parser in subParsers {
            do {
                return try composite(buffer: &buffer, tracker: tracker, parser)
            } catch is ParserError {
                continue
            }
        }
        throw ParserError(hint: "none of the options match", file: file, line: line)
    }

    static func optional<T>(buffer: inout ByteBuffer, tracker: StackTracker, parser: SubParser<T>) throws -> T? {
        do {
            return try composite(buffer: &buffer, tracker: tracker, parser)
        } catch is ParserError {
            return nil
        }
    }

    static func composite<T>(buffer: inout ByteBuffer, tracker: StackTracker, _ body: SubParser<T>) throws -> T {
        var tracker = tracker
        try tracker.newStackFrame()

        let save = buffer
        do {
            return try body(&buffer, tracker)
        } catch {
            buffer = save
            throw error
        }
    }

    static func newline(buffer: inout ByteBuffer, tracker: StackTracker) throws {
        switch buffer.getInteger(at: buffer.readerIndex, as: UInt16.self) {
        case .some(UInt16(0x0D0A /* CRLF */ )):
            // fast path: we find CRLF
            buffer.moveReaderIndex(forwardBy: 2)
            return
        case .some(let x) where UInt8(x >> 8) == UInt8(ascii: "\n"):
            // other fast path: we find LF + some other byte
            buffer.moveReaderIndex(forwardBy: 1)
            return
        case .some(let x) where UInt8(x >> 8) == UInt8(ascii: " "):
            // found a space that we’ll skip. Some servers insert an extra space at the end.
            try GrammarParser.composite(buffer: &buffer, tracker: tracker) { buffer, _ in
                buffer.moveReaderIndex(forwardBy: 1)
                try newline(buffer: &buffer, tracker: tracker)
            }
        case .none:
            guard let first = buffer.getInteger(at: buffer.readerIndex, as: UInt8.self) else {
                throw _IncompleteMessage()
            }
            switch first {
            case UInt8(ascii: "\n"):
                buffer.moveReaderIndex(forwardBy: 1)
                return
            case UInt8(ascii: "\r"):
                throw _IncompleteMessage()
            default:
                // found only one byte which is neither CR nor LF.
                throw ParserError()
            }
        default:
            // found two bytes but they're neither CRLF, nor start with a NL.
            throw ParserError()
        }
    }
}
