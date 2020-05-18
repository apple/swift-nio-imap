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

public enum ParsingError: Error {
    case lineTooLong
    case incompleteMessage
}

public enum GrammarParser {}

// MARK: - Grammar Parsers

extension GrammarParser {
    // address         = "(" addr-name SP addr-adl SP addr-mailbox SP
    //                   addr-host ")"
    static func parseAddress(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Address {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Address in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let name = try self.parseNString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
            let adl = try self.parseNString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseNString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
            let host = try self.parseNString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return Address(name: name, adl: adl, mailbox: mailbox, host: host)
        }
    }

    // append          = "APPEND" SP mailbox 1*append-message
    static func parseAppend(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("APPEND ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let firstMessage = try self.parseAppendMessage(buffer: &buffer, tracker: tracker)
            return .append(to: mailbox, firstMessageMetadata: firstMessage)
        }
    }

    // append-data = literal / literal8 / append-data-ext
    static func parseAppendData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> AppendData {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> AppendData in
            let needs8BitCleanTransport = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try ParserLibrary.parseFixedString("~", buffer: &buffer, tracker: tracker)
            }.map { () in true } ?? false
            try ParserLibrary.parseFixedString("{", buffer: &buffer, tracker: tracker)
            let length = try Self.parseNumber(buffer: &buffer, tracker: tracker)
            let synchronising = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try ParserLibrary.parseFixedString("+", buffer: &buffer, tracker: tracker)
            }.map { () in false } ?? true
            try ParserLibrary.parseFixedString("}\r\n", buffer: &buffer, tracker: tracker)
            return .init(byteCount: length, needs8BitCleanTransport: needs8BitCleanTransport, synchronizing: synchronising)
        }
    }

    // append-data-ext = tagged-ext
    static func parseAppendDataExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedExtension {
        try self.parseTaggedExtension(buffer: &buffer, tracker: tracker)
    }

    // append-ext = append-ext-name SP append-ext-value
    static func parseAppendExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> AppendExtension {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let name = try self.parseAppendExtensionName(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let value = try self.parseAppendExtensionValue(buffer: &buffer, tracker: tracker)
            return .init(name: name, value: value)
        }
    }

    // append-ext-name = tagged-ext-label
    static func parseAppendExtensionName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try self.parseTaggedExtensionLabel(buffer: &buffer, tracker: tracker)
    }

    // append-ext-value = tagged-ext-value
    static func parseAppendExtensionValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedExtensionValue {
        try self.parseTaggedExtensionValue(buffer: &buffer, tracker: tracker)
    }

    // append-message = appents-opts SP append-data
    static func parseAppendMessage(buffer: inout ByteBuffer, tracker: StackTracker) throws -> AppendMessage {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> AppendMessage in
            let options = try self.parseAppendOptions(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let data = try self.parseAppendData(buffer: &buffer, tracker: tracker)
            return .init(options: options, data: data)
        }
    }

    // append-options = [SP flag-list] [SP date-time] *(SP append-ext)
    static func parseAppendOptions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> AppendOptions {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let flagList = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [Flag] in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseFlagList(buffer: &buffer, tracker: tracker)
            } ?? []
            let dateTime = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Date.DateTime in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseDateTime(buffer: &buffer, tracker: tracker)
            }
            let array = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> AppendExtension in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseAppendExtension(buffer: &buffer, tracker: tracker)
            }
            return .init(flagList: flagList, dateTime: dateTime, extensions: array)
        }
    }

    // append-uid      = uniqueid
    static func parseAppendUid(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        try self.parseUniqueID(buffer: &buffer, tracker: tracker)
    }

    // astring         = 1*ASTRING-CHAR / string
    static func parseAString(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        func parseOneOrMoreASTRINGCHAR(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
            try ParserLibrary.parseOneOrMoreCharactersByteBuffer(buffer: &buffer, tracker: tracker) { char -> Bool in
                char.isAStringChar
            }
        }
        return try ParserLibrary.parseOneOf([
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

    // authenticate    = "AUTHENTICATE" SP auth-type [SP initial-resp] *(CRLF base64)
    static func parseAuthenticate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("AUTHENTICATE ", buffer: &buffer, tracker: tracker)
            let authType = try self.parseAuthType(buffer: &buffer, tracker: tracker)

            let initial = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> InitialResponse in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseInitialResp(buffer: &buffer, tracker: tracker)
            }

            // NOTE: Spec is super unclear, so we're ignoring the possibility of multiple base 64 chunks right now
//            let data = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [ByteBuffer] in
//                try ParserLibrary.parseFixedString("\r\n", buffer: &buffer, tracker: tracker)
//                return [try self.parseBase64(buffer: &buffer, tracker: tracker)]
//            } ?? []
            return .authenticate(authType, initial, [])
        }
    }

    // auth-type       = atom
    static func parseAuthType(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try self.parseAtom(buffer: &buffer, tracker: tracker)
    }

    // base64          = *(4base64-char) [base64-terminal]
    static func parseBase64(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
            let bytes = try ParserLibrary.parseZeroOrMoreCharactersByteBuffer(buffer: &buffer, tracker: tracker) { $0.isBase64Char || $0 == UInt8(ascii: "=") }
            let readableBytesView = bytes.readableBytesView
            if let firstEq = readableBytesView.firstIndex(of: UInt8(ascii: "=")) {
                for index in firstEq ..< readableBytesView.endIndex {
                    guard readableBytesView[index] == UInt8(ascii: "=") else {
                        throw ParserError(hint: "Found invalid character (expecting =) \(String(decoding: readableBytesView, as: Unicode.UTF8.self))")
                    }
                }
            }
            guard bytes.readableBytes % 4 == 0 else {
                throw ParserError(hint: "Base64 not divisible by 4 \(readableBytesView)")
            }
            return bytes
        }
    }

    // body            = "(" (body-type-1part / body-type-mpart) ")"
    static func parseBody(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure {
        func parseBody_singlePart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let part = try self.parseBodyTypeSinglePart(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .singlepart(part)
        }

        func parseBody_multiPart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let part = try self.parseBodyTypeMultipart(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .multipart(part)
        }

        return try ParserLibrary.parseOneOf([
            parseBody_singlePart,
            parseBody_multiPart,
        ], buffer: &buffer, tracker: tracker)
    }

    // body-extension  = nstring / number /
    //                    "(" body-extension *(SP body-extension) ")"
    static func parseBodyExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [BodyExtensionType] {
        func parseBodyExtensionType_string(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyExtensionType {
            .string(try self.parseNString(buffer: &buffer, tracker: tracker))
        }

        func parseBodyExtensionType_number(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyExtensionType {
            .number(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseBodyExtensionType(buffer: inout ByteBuffer, tracker: StackTracker, into array: inout [BodyExtensionType]) throws {
            let element = try ParserLibrary.parseOneOf([
                parseBodyExtensionType_string,
                parseBodyExtensionType_number,
            ], buffer: &buffer, tracker: tracker)
            array.append(element)
        }

        func parseBodyExtension_array(buffer: inout ByteBuffer, tracker: StackTracker, into array: inout [BodyExtensionType]) throws {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            try parseBodyExtension_arrayOrStatic(buffer: &buffer, tracker: tracker, into: &array)
            var save = buffer
            do {
                while true {
                    save = buffer
                    try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                    try parseBodyExtension_arrayOrStatic(buffer: &buffer, tracker: tracker, into: &array)
                }
            } catch is ParserError {
                buffer = save
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
        }

        func parseBodyExtension_arrayOrStatic(buffer: inout ByteBuffer, tracker: StackTracker, into array: inout [BodyExtensionType]) throws {
            let save = buffer
            do {
                try parseBodyExtensionType(buffer: &buffer, tracker: tracker, into: &array)
            } catch is ParserError {
                buffer = save
                try parseBodyExtension_array(buffer: &buffer, tracker: tracker, into: &array)
            }
        }

        var array = [BodyExtensionType]()
        try parseBodyExtension_arrayOrStatic(buffer: &buffer, tracker: tracker, into: &array)
        return array
    }

    // body-ext-1part  = body-fld-md5 [SP body-fld-dsp [SP body-fld-lang [SP body-fld-loc *(SP body-extension)]]]
    static func parseBodyExtSinglePart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Singlepart.Extension {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> BodyStructure.Singlepart.Extension in
            let md5 = try self.parseNString(buffer: &buffer, tracker: tracker)
            let dsp = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> BodyStructure.FieldDSPLanguage in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try parseBodyDescriptionLanguage(buffer: &buffer, tracker: tracker)
            }
            return BodyStructure.Singlepart.Extension(fieldMD5: md5, dspLanguage: dsp)
        }
    }

    // body-ext-mpart  = body-fld-param [SP body-fld-dsp [SP body-fld-lang [SP body-fld-loc *(SP body-extension)]]]
    static func parseBodyExtMpart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Multipart.Extension {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> BodyStructure.Multipart.Extension in
            let param = try self.parseBodyFieldParam(buffer: &buffer, tracker: tracker)
            let dsp = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> BodyStructure.FieldDSPLanguage in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try parseBodyDescriptionLanguage(buffer: &buffer, tracker: tracker)
            }
            return BodyStructure.Multipart.Extension(parameters: param, dspLanguage: dsp)
        }
    }

    // body-fields     = body-fld-param SP body-fld-id SP body-fld-desc SP
    //                   body-fld-enc SP body-fld-octets
    static func parseBodyFields(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Fields {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> BodyStructure.Fields in
            let fieldParam = try self.parseBodyFieldParam(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let fieldID = try self.parseNString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let fieldDescription = try self.parseNString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let Encoding = try self.parseBodyEncoding(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let fieldOctets = try self.parseBodyFieldOctets(buffer: &buffer, tracker: tracker)
            return BodyStructure.Fields(
                parameter: fieldParam,
                id: fieldID,
                description: fieldDescription,
                encoding: Encoding,
                octets: fieldOctets
            )
        }
    }

    // body-fld-dsp    = "(" string SP body-fld-param ")" / nil
    static func parseBodyFieldDsp(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.FieldDSPData? {
        func parseBodyFieldDsp_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.FieldDSPData? {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return nil
        }

        func parseBodyFieldDsp_some(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.FieldDSPData? {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let string = try self.parseString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let param = try self.parseBodyFieldParam(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return BodyStructure.FieldDSPData(string: string, parameter: param)
        }

        return try ParserLibrary.parseOneOf([
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
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(option, buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
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

        return try ParserLibrary.parseOneOf([
            parseBodyEncoding_7bit,
            parseBodyEncoding_8bit,
            parseBodyEncoding_binary,
            parseBodyEncoding_base64,
            parseBodyEncoding_quotePrintable,
            parseBodyEncoding_string,
        ], buffer: &buffer, tracker: tracker)
    }

    // body-fld-lang   = nstring / "(" string *(SP string) ")"
    static func parseBodyFieldLanguage(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.FieldLanguage {
        func parseBodyFieldLanguage_single(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.FieldLanguage {
            .single(try self.parseNString(buffer: &buffer, tracker: tracker))
        }

        func parseBodyFieldLanguage_multiple(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.FieldLanguage {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseString(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ByteBuffer in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseString(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .multiple(array)
        }

        return try ParserLibrary.parseOneOf([
            parseBodyFieldLanguage_multiple,
            parseBodyFieldLanguage_single,
        ], buffer: &buffer, tracker: tracker)
    }

    // body-fld-lines  = number
    static func parseBodyFieldLines(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        try self.parseNumber(buffer: &buffer, tracker: tracker)
    }

    // body-fld-octets = number
    static func parseBodyFieldOctets(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        try self.parseNumber(buffer: &buffer, tracker: tracker)
    }

    // body-fld-param  = "(" string SP string *(SP string SP string) ")" / nil
    static func parseBodyFieldParam(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [FieldParameterPair] {
        func parseBodyFieldParam_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [FieldParameterPair] {
            try parseNil(buffer: &buffer, tracker: tracker)
            return []
        }

        func parseBodyFieldParam_singlePair(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FieldParameterPair {
            let field = String(buffer: try parseString(buffer: &buffer, tracker: tracker))
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let value = String(buffer: try parseString(buffer: &buffer, tracker: tracker))
            return .init(field: field, value: value)
        }

        func parseBodyFieldParam_pairs(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [FieldParameterPair] {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try parseBodyFieldParam_singlePair(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> FieldParameterPair in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try parseBodyFieldParam_singlePair(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }

        return try ParserLibrary.parseOneOf([
            parseBodyFieldParam_pairs,
            parseBodyFieldParam_nil,
        ], buffer: &buffer, tracker: tracker)
    }

    // body-type-1part = (body-type-basic / body-type-msg / body-type-text)
    //                   [SP body-ext-1part]
    static func parseBodyTypeSinglePart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Singlepart {
        func parseBodyTypeSinglePart_extension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Singlepart.Extension? {
            try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseBodyExtSinglePart(buffer: &buffer, tracker: tracker)
            }
        }

        func parseBodyTypeSinglePart_basic(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Singlepart {
            let media = try self.parseMediaBasic(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let fields = try self.parseBodyFields(buffer: &buffer, tracker: tracker)
            let basic = BodyStructure.Singlepart.Basic(media: media)
            let ext = try parseBodyTypeSinglePart_extension(buffer: &buffer, tracker: tracker)
            return BodyStructure.Singlepart(type: .basic(basic), fields: fields, extension: ext)
        }

        func parseBodyTypeSinglePart_message(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Singlepart {
            let mediaMessage = try self.parseMediaMessage(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let fields = try self.parseBodyFields(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let envelope = try self.parseEnvelope(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let body = try self.parseBody(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let fieldLines = try self.parseBodyFieldLines(buffer: &buffer, tracker: tracker)
            let message = BodyStructure.Singlepart.Message(message: mediaMessage, envelope: envelope, body: body, fieldLines: fieldLines)
            let ext = try parseBodyTypeSinglePart_extension(buffer: &buffer, tracker: tracker)
            return BodyStructure.Singlepart(type: .message(message), fields: fields, extension: ext)
        }

        func parseBodyTypeSinglePart_text(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Singlepart {
            let media = try self.parseMediaText(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let fields = try self.parseBodyFields(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let fieldLines = try self.parseBodyFieldLines(buffer: &buffer, tracker: tracker)
            let text = BodyStructure.Singlepart.Text(mediaText: media, lines: fieldLines)
            let ext = try parseBodyTypeSinglePart_extension(buffer: &buffer, tracker: tracker)
            return BodyStructure.Singlepart(type: .text(text), fields: fields, extension: ext)
        }

        return try ParserLibrary.parseOneOf([
            parseBodyTypeSinglePart_message,
            parseBodyTypeSinglePart_text,
            parseBodyTypeSinglePart_basic,
        ], buffer: &buffer, tracker: tracker)
    }

    // body-type-mpart = 1*body SP media-subtype
    //                   [SP body-ext-mpart]
    static func parseBodyTypeMultipart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.Multipart {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> BodyStructure.Multipart in
            let bodies = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try self.parseBody(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let media = try self.parseMediaSubtype(buffer: &buffer, tracker: tracker)
            let ext = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> BodyStructure.Multipart.Extension in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseBodyExtMpart(buffer: &buffer, tracker: tracker)
            }
            return BodyStructure.Multipart(bodies: bodies, mediaSubtype: media, multipartExtension: ext)
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
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [Capability] in
            try ParserLibrary.parseFixedString("CAPABILITY", buffer: &buffer, tracker: tracker)
            return try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
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

        return try ParserLibrary.parseOneOf([
            parseCharset_atom,
            parseCharset_quoted,
        ], buffer: &buffer, tracker: tracker)
    }

    // childinfo-extended-item =  "CHILDINFO" SP "("
    //             list-select-base-opt-quoted
    //             *(SP list-select-base-opt-quoted) ")"
    static func parseChildinfoExtendedItem(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [ListSelectBaseOption] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [ListSelectBaseOption] in
            try ParserLibrary.parseFixedString("CHILDINFO (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseListSelectBaseOptionQuoted(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ListSelectBaseOption in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseListSelectBaseOptionQuoted(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // child-mbox-flag =  "\HasChildren" / "\HasNoChildren"
    static func parseChildMailboxFlag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ChildMailboxFlag {
        func parseChildMailboxFlag_children(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ChildMailboxFlag {
            try ParserLibrary.parseFixedString(#"\HasChildren"#, buffer: &buffer, tracker: tracker)
            return .HasChildren
        }

        func parseChildMailboxFlag_noChildren(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ChildMailboxFlag {
            try ParserLibrary.parseFixedString(#"\HasNoChildren"#, buffer: &buffer, tracker: tracker)
            return .HasNoChildren
        }

        return try ParserLibrary.parseOneOf([
            parseChildMailboxFlag_children,
            parseChildMailboxFlag_noChildren,
        ], buffer: &buffer, tracker: tracker)
    }

    // command         = tag SP (command-any / command-auth / command-nonauth /
    //                   command-select) CRLF
    static func parseCommand(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedCommand {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let tag = try self.parseTag(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let type = try ParserLibrary.parseOneOf([
                self.parseCommandAny,
                self.parseCommandAuth,
                self.parseCommandNonauth,
                self.parseCommandSelect,
            ], buffer: &buffer, tracker: tracker)
            return TaggedCommand(type: type, tag: tag)
        }
    }

    static func parseCommandEnd(buffer: inout ByteBuffer, tracker: StackTracker) throws {
        try ParserLibrary.parseFixedString("\r\n", buffer: &buffer, tracker: tracker)
    }

    // command-any     = "CAPABILITY" / "LOGOUT" / "NOOP" / enable / x-command / id
    static func parseCommandAny(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        func parseCommandAny_capability(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.parseFixedString("CAPABILITY", buffer: &buffer, tracker: tracker)
            return .capability
        }

        func parseCommandAny_logout(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.parseFixedString("LOGOUT", buffer: &buffer, tracker: tracker)
            return .logout
        }

        func parseCommandAny_noop(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.parseFixedString("NOOP", buffer: &buffer, tracker: tracker)
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

        return try ParserLibrary.parseOneOf([
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
    static func parseCommandAuth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseOneOf([
            self.parseAppend,
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
        ], buffer: &buffer, tracker: tracker)
    }

    // command-nonauth = login / authenticate / "STARTTLS"
    static func parseCommandNonauth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        func parseCommandNonauth_starttls(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.parseFixedString("STARTTLS", buffer: &buffer, tracker: tracker)
            return .starttls
        }

        return try ParserLibrary.parseOneOf([
            self.parseLogin,
            self.parseAuthenticate,
            parseCommandNonauth_starttls,
        ], buffer: &buffer, tracker: tracker)
    }

    // command-select  = "CHECK" / "CLOSE" / "UNSELECT" / "EXPUNGE" / copy / fetch / store /
    //                   uid / search / move
    static func parseCommandSelect(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        func parseCommandSelect_check(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.parseFixedString("CHECK", buffer: &buffer, tracker: tracker)
            return .check
        }

        func parseCommandSelect_close(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.parseFixedString("CLOSE", buffer: &buffer, tracker: tracker)
            return .close
        }

        func parseCommandSelect_expunge(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.parseFixedString("EXPUNGE", buffer: &buffer, tracker: tracker)
            return .expunge
        }

        func parseCommandSelect_unselect(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.parseFixedString("UNSELECT", buffer: &buffer, tracker: tracker)
            return .unselect
        }

        return try ParserLibrary.parseOneOf([
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
        ], buffer: &buffer, tracker: tracker)
    }

    // condstore-param = "CONDSTORE"
    static func parseConditionalStoreParameter(buffer: inout ByteBuffer, tracker: StackTracker) throws {
        try ParserLibrary.parseFixedString("CONDSTORE", buffer: &buffer, tracker: tracker)
    }

    // continue-req    = "+" SP (resp-text / base64) CRLF
    static func parseContinueRequest(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ContinueRequest {
        func parseContinueReq_responseText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ContinueRequest {
            .responseText(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        func parseContinueReq_base64(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ContinueRequest {
            .base64(try self.parseBase64(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ContinueRequest in
            try ParserLibrary.parseFixedString("+ ", buffer: &buffer, tracker: tracker)
            let continueReq = try ParserLibrary.parseOneOf([
                parseContinueReq_base64,
                parseContinueReq_responseText,
            ], buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("\r\n", buffer: &buffer, tracker: tracker)
            return continueReq
        }
    }

    // copy            = "COPY" SP sequence-set SP mailbox
    static func parseCopy(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("COPY ", buffer: &buffer, tracker: tracker)
            let sequence = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .copy(sequence, mailbox)
        }
    }

    // create          = "CREATE" SP mailbox [create-params]
    static func parseCreate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("CREATE ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseCreateParameters) ?? []
            return .create(mailbox, params)
        }
    }

    // create-param = create-param-name [SP create-param-value]
    static func parseCreateParameter(buffer: inout ByteBuffer, tracker: StackTracker) throws -> CreateParameter {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let name = try self.parseCreateParameterName(buffer: &buffer, tracker: tracker)
            let value = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> TaggedExtensionValue in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseCreateParameterValue(buffer: &buffer, tracker: tracker)
            }
            return .init(name: name, value: value)
        }
    }

    // create-params = SP "(" create-param *(SP create-param-value) ")"
    static func parseCreateParameters(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [CreateParameter] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString(" (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseCreateParameter(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> CreateParameter in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseCreateParameter(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // create-param-name = tagged-ext-label
    static func parseCreateParameterName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try self.parseTaggedExtensionLabel(buffer: &buffer, tracker: tracker)
    }

    // create-param-value = tagged-ext-val
    static func parseCreateParameterValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedExtensionValue {
        try self.parseTaggedExtensionValue(buffer: &buffer, tracker: tracker)
    }

    // date            = date-text / DQUOTE date-text DQUOTE
    static func parseDate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Date {
        func parseDateText_quoted(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Date {
            try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
                let date = try self.parseDateText(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
                return date
            }
        }

        return try ParserLibrary.parseOneOf([
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
            try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
            return try self.parseNDigits(buffer: &buffer, tracker: tracker, bytes: 1)
        }

        return try ParserLibrary.parseOneOf([
            parseDateDayFixed_spaced,
            parse2Digit,
        ], buffer: &buffer, tracker: tracker)
    }

    // date-month      = "Jan" / "Feb" / "Mar" / "Apr" / "May" / "Jun" /
    //                   "Jul" / "Aug" / "Sep" / "Oct" / "Nov" / "Dec"
    static func parseDateMonth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Date.Month {
        let string = try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            isalnum(Int32(char)) != 0
        }
        guard let month = Date.Month(rawValue: string.lowercased()) else {
            throw ParserError(hint: "No date-month match for \(string)")
        }
        return month
    }

    // date-text       = date-day "-" date-month "-" date-year
    static func parseDateText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Date {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let day = try self.parseDateDay(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("-", buffer: &buffer, tracker: tracker)
            let month = try self.parseDateMonth(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("-", buffer: &buffer, tracker: tracker)
            let year = try self.parseDateYear(buffer: &buffer, tracker: tracker)
            return Date(day: day, month: month, year: year)
        }
    }

    // date-year       = 4DIGIT
    static func parseDateYear(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        try self.parse4Digit(buffer: &buffer, tracker: tracker)
    }

    // date-time       = DQUOTE date-day-fixed "-" date-month "-" date-year
    //                   SP time SP zone DQUOTE
    static func parseDateTime(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Date.DateTime {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            let day = try self.parseDateDayFixed(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("-", buffer: &buffer, tracker: tracker)
            let month = try self.parseDateMonth(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("-", buffer: &buffer, tracker: tracker)
            let year = try self.parseDateYear(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
            let time = try self.parseTime(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
            let zone = try self.parseZone(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            return Date.DateTime(date: Date(day: day, month: month, year: year), time: time, zone: zone)
        }
    }

    // delete          = "DELETE" SP mailbox
    static func parseDelete(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("DELETE ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .delete(mailbox)
        }
    }

    // eitem-standard-tag =  atom
    static func parseEitemStandardTag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try self.parseAtom(buffer: &buffer, tracker: tracker)
    }

    // eitem-vendor-tag =  vendor-token "-" atom
    static func parseEitemVendorTag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EItemVendorTag {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> EItemVendorTag in
            let token = try self.parseVendorToken(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("-", buffer: &buffer, tracker: tracker)
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return EItemVendorTag(token: token, atom: atom)
        }
    }

    // enable          = "ENABLE" 1*(SP capability)
    static func parseEnable(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("ENABLE", buffer: &buffer, tracker: tracker)
            let capabilities = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Capability in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseCapability(buffer: &buffer, tracker: tracker)
            }
            return .enable(capabilities)
        }
    }

    // enable-data     = "ENABLED" *(SP capability)
    static func parseEnableData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Capability] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [Capability] in
            try ParserLibrary.parseFixedString("ENABLED", buffer: &buffer, tracker: tracker)
            return try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Capability in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseCapability(buffer: &buffer, tracker: tracker)
            }
        }
    }

    // envelope        = "(" env-date SP env-subject SP env-from SP
    //                   env-sender SP env-reply-to SP env-to SP env-cc SP
    //                   env-bcc SP env-in-reply-to SP env-message-id ")"
    static func parseEnvelope(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Envelope {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Envelope in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let date = try self.parseNString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let subject = try self.parseNString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let from = try self.parseOptionalEnvelopeAddresses(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let sender = try self.parseOptionalEnvelopeAddresses(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let replyTo = try self.parseOptionalEnvelopeAddresses(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let to = try self.parseOptionalEnvelopeAddresses(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let cc = try self.parseOptionalEnvelopeAddresses(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let bcc = try self.parseOptionalEnvelopeAddresses(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let inReplyTo = try self.parseNString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let messageID = try self.parseNString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
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

    // entry-type-req = entry-type-resp / all
    static func parseEntryTypeRequest(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryTypeRequest {
        func parseEntryTypeRequest_all(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryTypeRequest {
            try ParserLibrary.parseFixedString("all", buffer: &buffer, tracker: tracker)
            return .all
        }

        func parseEntryTypeRequest_response(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryTypeRequest {
            .response(try self.parseEntryTypeResponse(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseEntryTypeRequest_all,
            parseEntryTypeRequest_response,
        ], buffer: &buffer, tracker: tracker)
    }

    // entry-type-resp = "priv" / "shared"
    static func parseEntryTypeResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryTypeResponse {
        func parseEntryTypeResponse_private(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryTypeResponse {
            try ParserLibrary.parseFixedString("priv", buffer: &buffer, tracker: tracker)
            return .private
        }

        func parseEntryTypeResponse_shared(buffer: inout ByteBuffer, tracker: StackTracker) throws -> EntryTypeResponse {
            try ParserLibrary.parseFixedString("shared", buffer: &buffer, tracker: tracker)
            return .shared
        }

        return try ParserLibrary.parseOneOf([
            parseEntryTypeResponse_private,
            parseEntryTypeResponse_shared,
        ], buffer: &buffer, tracker: tracker)
    }

    // esearch-response  = "ESEARCH" [search-correlator] [SP "UID"]
    //                     *(SP search-return-data)
    static func parseEsearchResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ESearchResponse {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString("ESEARCH", buffer: &buffer, tracker: tracker)
            let correlator = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseSearchCorrelator)
            let uid = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try ParserLibrary.parseFixedString(" UID", buffer: &buffer, tracker: tracker)
                return true
            } ?? false
            let searchReturnData = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> SearchReturnData in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseSearchReturnData(buffer: &buffer, tracker: tracker)
            }
            return ESearchResponse(correlator: correlator, uid: uid, returnData: searchReturnData)
        }
    }

    // examine         = "EXAMINE" SP mailbox [select-params
    static func parseExamine(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("EXAMINE ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseSelectParameters) ?? []
            return .examine(mailbox, params)
        }
    }

    // fetch           = "FETCH" SP sequence-set SP ("ALL" / "FULL" / "FAST" /
    //                   fetch-att / "(" fetch-att *(SP fetch-att) ")") [fetch-modifiers]
    static func parseFetch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        func parseFetch_type_all(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchType {
            try ParserLibrary.parseFixedString("ALL", buffer: &buffer, tracker: tracker)
            return .all
        }

        func parseFetch_type_full(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchType {
            try ParserLibrary.parseFixedString("FULL", buffer: &buffer, tracker: tracker)
            return .full
        }

        func parseFetch_type_fast(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchType {
            try ParserLibrary.parseFixedString("FAST", buffer: &buffer, tracker: tracker)
            return .fast
        }

        func parseFetch_type_singleAtt(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchType {
            .attributes([try self.parseFetchAttribute(buffer: &buffer, tracker: tracker)])
        }

        func parseFetch_type_multiAtt(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchType {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseFetchAttribute(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> FetchAttribute in
                try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
                return try self.parseFetchAttribute(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .attributes(array)
        }

        func parseFetch_type(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchType {
            try ParserLibrary.parseOneOf([
                parseFetch_type_all,
                parseFetch_type_full,
                parseFetch_type_fast,
                parseFetch_type_singleAtt,
                parseFetch_type_multiAtt,
            ], buffer: &buffer, tracker: tracker)
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("FETCH ", buffer: &buffer, tracker: tracker)
            let sequence = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let att = try parseFetch_type(buffer: &buffer, tracker: tracker)
            let modifiers = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseFetchModifiers) ?? []
            return .fetch(sequence, att, modifiers)
        }
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
            try ParserLibrary.parseFixedString("ENVELOPE", buffer: &buffer, tracker: tracker)
            return .envelope
        }

        func parseFetchAttribute_flags(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try ParserLibrary.parseFixedString("FLAGS", buffer: &buffer, tracker: tracker)
            return .flags
        }

        func parseFetchAttribute_internalDate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try ParserLibrary.parseFixedString("INTERNALDATE", buffer: &buffer, tracker: tracker)
            return .internaldate
        }

        func parseFetchAttribute_UID(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try ParserLibrary.parseFixedString("UID", buffer: &buffer, tracker: tracker)
            return .uid
        }

        func parseFetchAttribute_rfc822(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try ParserLibrary.parseFixedString("RFC822", buffer: &buffer, tracker: tracker)
            let rfc = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> RFC822 in
                try self.parseRFC822(buffer: &buffer, tracker: tracker)
            }
            return .rfc822(rfc)
        }

        func parseFetchAttribute_body(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try ParserLibrary.parseFixedString("BODY", buffer: &buffer, tracker: tracker)
            let structure: Bool = {
                do {
                    try ParserLibrary.parseFixedString("STRUCTURE", buffer: &buffer, tracker: tracker)
                    return true
                } catch {
                    return false
                }
            }()
            return .body(structure: structure)
        }

        func parseFetchAttribute_bodySection(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try ParserLibrary.parseFixedString("BODY", buffer: &buffer, tracker: tracker)
            let section = try self.parseSection(buffer: &buffer, tracker: tracker)
            let chevronNumber = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Partial in
                try self.parsePartial(buffer: &buffer, tracker: tracker)
            }
            return .bodySection(section, chevronNumber)
        }

        func parseFetchAttribute_bodyPeekSection(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try ParserLibrary.parseFixedString("BODY.PEEK", buffer: &buffer, tracker: tracker)
            let section = try self.parseSection(buffer: &buffer, tracker: tracker)
            let chevronNumber = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Partial in
                try self.parsePartial(buffer: &buffer, tracker: tracker)
            }
            return .bodyPeekSection(section, chevronNumber)
        }

        func parseFetchAttribute_modSequence(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            .modSequence(try self.parseModifierSequenceValue(buffer: &buffer, tracker: tracker))
        }

        func parseFetchAttribute_binary(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            func parsePeek(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Bool {
                let save = buffer
                do {
                    try ParserLibrary.parseFixedString(".PEEK", buffer: &buffer, tracker: tracker)
                    return true
                } catch {
                    buffer = save
                    return false
                }
            }

            try ParserLibrary.parseFixedString("BINARY", buffer: &buffer, tracker: tracker)
            let peek = try parsePeek(buffer: &buffer, tracker: tracker)
            let sectionBinary = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            let partial = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parsePartial)
            return .binary(peek: peek, section: sectionBinary, partial: partial)
        }

        func parseFetchAttribute_binarySize(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchAttribute {
            try ParserLibrary.parseFixedString("BINARY.SIZE", buffer: &buffer, tracker: tracker)
            let sectionBinary = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            return .binarySize(section: sectionBinary)
        }

        return try ParserLibrary.parseOneOf([
            parseFetchAttribute_envelope,
            parseFetchAttribute_flags,
            parseFetchAttribute_internalDate,
            parseFetchAttribute_UID,
            parseFetchAttribute_rfc822,
            parseFetchAttribute_bodySection,
            parseFetchAttribute_bodyPeekSection,
            parseFetchAttribute_body,
            parseFetchAttribute_modSequence,
            parseFetchAttribute_binary,
            parseFetchAttribute_binarySize,
        ], buffer: &buffer, tracker: tracker)
    }

    // fetch-modifier = fetch-modifier-name [SP fetch-modifier-params]
    static func parseFetchModifier(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchModifier {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let name = try self.parseFetchModifierName(buffer: &buffer, tracker: tracker)
            let value = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> TaggedExtensionValue in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseFetchModifierParameter(buffer: &buffer, tracker: tracker)
            }
            return .init(name: name, value: value)
        }
    }

    // fetch-modifiers = SP "(" fetch-modifier *(SP fetch-modifier) ")"
    static func parseFetchModifiers(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [FetchModifier] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString(" (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseFetchModifier(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> FetchModifier in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseFetchModifier(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // fetch-modifier-name = tagged-ext-label
    static func parseFetchModifierName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try self.parseTaggedExtensionLabel(buffer: &buffer, tracker: tracker)
    }

    // fetch-modifier-params = tagged-ext-val
    static func parseFetchModifierParameter(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedExtensionValue {
        try self.parseTaggedExtensionValue(buffer: &buffer, tracker: tracker)
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
            try ParserLibrary.parseFixedString("\\Answered", buffer: &buffer, tracker: tracker)
            return .answered
        }

        func parseFlag_flagged(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
            try ParserLibrary.parseFixedString("\\Flagged", buffer: &buffer, tracker: tracker)
            return .flagged
        }

        func parseFlag_deleted(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
            try ParserLibrary.parseFixedString("\\Deleted", buffer: &buffer, tracker: tracker)
            return .deleted
        }

        func parseFlag_seen(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
            try ParserLibrary.parseFixedString("\\Seen", buffer: &buffer, tracker: tracker)
            return .seen
        }

        func parseFlag_draft(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
            try ParserLibrary.parseFixedString("\\Draft", buffer: &buffer, tracker: tracker)
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

        return try ParserLibrary.parseOneOf([
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
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> String in
            try ParserLibrary.parseFixedString("\\", buffer: &buffer, tracker: tracker)
            let string = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return "\\\(string)"
        }
    }

    // flag-fetch      = flag
    static func parseFlagFetch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag {
        try self.parseFlag(buffer: &buffer, tracker: tracker)
    }

    // flag-keyword    = "$MDNSent" / "$Forwarded" / atom
    static func parseFlagKeyword(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Flag.Keyword {
        let string = try self.parseAtom(buffer: &buffer, tracker: tracker)
        return Flag.Keyword(string)
    }

    // flag-list       = "(" [flag *(SP flag)] ")"
    static func parseFlagList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Flag] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let flags = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, _) -> [Flag] in
                var output = [try self.parseFlag(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { buffer, tracker in
                    try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
                    return try self.parseFlag(buffer: &buffer, tracker: tracker)
                }
                return output
            } ?? []
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return flags
        }
    }

    // flag-perm       = flag / "\*"
    static func parseFlagPerm(buffer: inout ByteBuffer, tracker: StackTracker) throws -> PermanentFlag {
        func parseFlagPerm_wildcard(buffer: inout ByteBuffer, tracker: StackTracker) throws -> PermanentFlag {
            try ParserLibrary.parseFixedString("\\*", buffer: &buffer, tracker: tracker)
            return .wildcard
        }

        func parseFlagPerm_flag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> PermanentFlag {
            .flag(try self.parseFlag(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
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

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Greeting in
            try ParserLibrary.parseFixedString("* ", buffer: &buffer, tracker: tracker)
            let greeting = try ParserLibrary.parseOneOf([
                parseGreeting_auth,
                parseGreeting_bye,
            ], buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("\r\n", buffer: &buffer, tracker: tracker)
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
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [String] in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var output = [try self.parseHeaderFieldName(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { (buffer, tracker) -> String in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseHeaderFieldName(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return output
        }
    }

    // id = "ID" SP id-params-list
    static func parseID(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [IDParameter] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString("ID ", buffer: &buffer, tracker: tracker)
            return try parseIDParamsList(buffer: &buffer, tracker: tracker)
        }
    }

    // id-response = "ID" SP id-params-list
    static func parseIDResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [IDParameter] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString("ID ", buffer: &buffer, tracker: tracker)
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
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let value = try self.parseNString(buffer: &buffer, tracker: tracker)
            return .init(key: key, value: value)
        }

        func parseIDParamsList_some(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [IDParameter] {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try parseIDParamsList_element(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> IDParameter in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try parseIDParamsList_element(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }

        return try ParserLibrary.parseOneOf([
            parseIDParamsList_nil,
            parseIDParamsList_some,
        ], buffer: &buffer, tracker: tracker)
    }

    // idle            = "IDLE" CRLF "DONE"
    static func parseIdleStart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseFixedString("IDLE", buffer: &buffer, tracker: tracker)
        return .idleStart
    }

    static func parseIdleDone(buffer: inout ByteBuffer, tracker: StackTracker) throws {
        try ParserLibrary.parseFixedString("DONE\r\n", buffer: &buffer, tracker: tracker)
    }

    // initial-resp    =  (base64 / "=")
    static func parseInitialResp(buffer: inout ByteBuffer, tracker: StackTracker) throws -> InitialResponse {
        func parseInitialResp_equals(buffer: inout ByteBuffer, tracker: StackTracker) throws -> InitialResponse {
            try ParserLibrary.parseFixedString("=", buffer: &buffer, tracker: tracker)
            return .equals
        }

        func parseInitialResp_base64(buffer: inout ByteBuffer, tracker: StackTracker) throws -> InitialResponse {
            .base64(try self.parseBase64(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseInitialResp_equals,
            parseInitialResp_base64,
        ], buffer: &buffer, tracker: tracker)
    }

    // list            = "LIST" [SP list-select-opts] SP mailbox SP mbox-or-pat [SP list-return-opts]
    static func parseList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString("LIST", buffer: &buffer, tracker: tracker)
            let selectOptions = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ListSelectOptions in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseListSelectOptions(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let mailboxPatterns = try self.parseMailboxPatterns(buffer: &buffer, tracker: tracker)
            let returnOptions = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [ReturnOption] in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseListReturnOptions(buffer: &buffer, tracker: tracker)
            } ?? []
            return .list(selectOptions, mailbox, mailboxPatterns, returnOptions)
        }
    }

    // list-select-base-opt =  "SUBSCRIBED" / option-extension
    static func parseListSelectBaseOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectBaseOption {
        func parseListSelectBaseOption_subscribed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectBaseOption {
            try ParserLibrary.parseFixedString("SUBSCRIBED", buffer: &buffer, tracker: tracker)
            return .subscribed
        }

        func parseListSelectBaseOption_optionExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectBaseOption {
            .option(try self.parseOptionExtension(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseListSelectBaseOption_subscribed,
            parseListSelectBaseOption_optionExtension,
        ], buffer: &buffer, tracker: tracker)
    }

    // list-select-base-opt-quoted =  DQUOTE list-select-base-opt DQUOTE
    static func parseListSelectBaseOptionQuoted(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectBaseOption {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ListSelectBaseOption in
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            let option = try self.parseListSelectBaseOption(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            return option
        }
    }

    // list-select-independent-opt =  "REMOTE" / option-extension
    static func parseListSelectIndependentOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectIndependentOption {
        func parseListSelectIndependentOption_subscribed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectIndependentOption {
            try ParserLibrary.parseFixedString("REMOTE", buffer: &buffer, tracker: tracker)
            return .remote
        }

        func parseListSelectIndependentOption_optionExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectIndependentOption {
            .option(try self.parseOptionExtension(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseListSelectIndependentOption_subscribed,
            parseListSelectIndependentOption_optionExtension,
        ], buffer: &buffer, tracker: tracker)
    }

    // list-select-mod-opt =  "RECURSIVEMATCH" / option-extension
    static func parseListSelectModOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectModOption {
        func parseListSelectModOption_subscribed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectModOption {
            try ParserLibrary.parseFixedString("RECURSIVEMATCH", buffer: &buffer, tracker: tracker)
            return .recursiveMatch
        }

        func parseListSelectModOption_optionExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectModOption {
            .option(try self.parseOptionExtension(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseListSelectModOption_subscribed,
            parseListSelectModOption_optionExtension,
        ], buffer: &buffer, tracker: tracker)
    }

    // list-select-opt =  list-select-base-opt / list-select-independent-opt
    //                    / list-select-mod-opt
    static func parseListSelectOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectOption {
        func parseListSelectOption_base(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectOption {
            .base(try self.parseListSelectBaseOption(buffer: &buffer, tracker: tracker))
        }

        func parseListSelectOption_independent(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectOption {
            .independent(try self.parseListSelectIndependentOption(buffer: &buffer, tracker: tracker))
        }

        func parseListSelectOption_mod(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectOption {
            .mod(try self.parseListSelectModOption(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseListSelectOption_base,
            parseListSelectOption_independent,
            parseListSelectOption_mod,
        ], buffer: &buffer, tracker: tracker)
    }

    // list-select-opts =  "(" [
    //                    (*(list-select-opt SP) list-select-base-opt
    //                    *(SP list-select-opt))
    //                   / (list-select-independent-opt
    //                    *(SP list-select-independent-opt))
    //                      ] ")"
    static func parseListSelectOptions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectOptions {
        func parseListSelectOptions_mixed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectionOptionsData {
            var selectOptions = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ListSelectOption in
                let option = try self.parseListSelectOption(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return option
            }
            let baseOption = try self.parseListSelectBaseOption(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &selectOptions, tracker: tracker) { (buffer, tracker) -> ListSelectOption in
                let option = try self.parseListSelectOption(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return option
            }

            return .select(selectOptions, baseOption)
        }

        func parseListSelectOptions_independent(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ListSelectionOptionsData {
            var array = [try self.parseListSelectIndependentOption(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseListSelectIndependentOption(buffer: &buffer, tracker: tracker)
            }
            return .selectIndependent(array)
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let options = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try ParserLibrary.parseOneOf([
                    parseListSelectOptions_mixed,
                    parseListSelectOptions_independent,
                ], buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return options
        }
    }

    static func parseLiteralSize(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Int in
            try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try ParserLibrary.parseFixedString("~", buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString("{", buffer: &buffer, tracker: tracker)
            let length = try Self.parseNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("}\r\n", buffer: &buffer, tracker: tracker)
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

        return try ParserLibrary.parseOneOf([
            parseMailboxPatterns_list,
            parseMailboxPatterns_patterns,
        ], buffer: &buffer, tracker: tracker)
    }

    // list-return-opt = "RETURN" SP "(" [return-option *(SP return-option)] ")"
    static func parseListReturnOptions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [ReturnOption] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString("RETURN (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseReturnOption(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ReturnOption in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseReturnOption(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
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

        return try ParserLibrary.parseOneOf([
            parseListMailbox_string,
            parseListMailbox_chars,
        ], buffer: &buffer, tracker: tracker)
    }

    // list-wildcards  = "%" / "*"
    static func parseListWildcards(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        guard let char = buffer.readInteger(as: UInt8.self) else {
            throw ParsingError.incompleteMessage
        }
        guard char.isListWildcard else {
            throw ParserError()
        }
        return String(decoding: CollectionOfOne(char), as: Unicode.UTF8.self)
    }

    // literal         = "{" number ["+"] "}" CRLF *CHAR8
    static func parseLiteral(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
            try ParserLibrary.parseFixedString("{", buffer: &buffer, tracker: tracker)
            let length = try Self.parseNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try ParserLibrary.parseFixedString("+", buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString("}", buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseNewline(buffer: &buffer, tracker: tracker)
            if let bytes = buffer.readSlice(length: length) {
                if bytes.readableBytesView.contains(0) {
                    throw ParserError(hint: "Found NUL byte in literal")
                }
                return bytes
            } else {
                throw ParsingError.incompleteMessage
            }
        }
    }

    // login           = "LOGIN" SP userid SP password
    static func parseLogin(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("LOGIN ", buffer: &buffer, tracker: tracker)
            let userid = try Self.parseUserId(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
            let password = try Self.parsePassword(buffer: &buffer, tracker: tracker)
            return .login(username: userid, password: password)
        }
    }

    // lsub = "LSUB" SP mailbox SP list-mailbox
    static func parseLSUB(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Command in
            try ParserLibrary.parseFixedString("LSUB ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let listMailbox = try self.parseListMailbox(buffer: &buffer, tracker: tracker)
            return .lsub(mailbox, listMailbox)
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
            try ParserLibrary.parseFixedString("FLAGS ", buffer: &buffer, tracker: tracker)
            return .flags(try self.parseFlagList(buffer: &buffer, tracker: tracker))
        }

        func parseMailboxData_list(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
            try ParserLibrary.parseFixedString("LIST ", buffer: &buffer, tracker: tracker)
            return .list(try self.parseMailboxList(buffer: &buffer, tracker: tracker))
        }

        func parseMailboxData_lsub(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
            try ParserLibrary.parseFixedString("LSUB ", buffer: &buffer, tracker: tracker)
            return .lsub(try self.parseMailboxList(buffer: &buffer, tracker: tracker))
        }

        func parseMailboxData_esearch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
            let response = try self.parseEsearchResponse(buffer: &buffer, tracker: tracker)
            return .esearch(response)
        }

        func parseMailboxData_search(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
            try ParserLibrary.parseFixedString("SEARCH", buffer: &buffer, tracker: tracker)
            let nums = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Int in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            }
            return .search(nums)
        }

        func parseMailboxData_status(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
            try ParserLibrary.parseFixedString("STATUS ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let list = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try self.parseStatusAttributeList(buffer: &buffer, tracker: tracker)
            } ?? []
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .status(mailbox, list)
        }

        func parseMailboxData_exists(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
            let number = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" EXISTS", buffer: &buffer, tracker: tracker)
            return .exists(number)
        }

        func parseMailboxData_recent(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
            let number = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" RECENT", buffer: &buffer, tracker: tracker)
            return .recent(number)
        }

        func parseMailboxData_namespace(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.Data {
            .namespace(try self.parseNamespaceResponse(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseMailboxData_flags,
            parseMailboxData_list,
            parseMailboxData_lsub,
            parseMailboxData_esearch,
            parseMailboxData_status,
            parseMailboxData_exists,
            parseMailboxData_recent,
            parseMailboxData_search,
            parseMailboxData_namespace,
        ], buffer: &buffer, tracker: tracker)
    }

    // mailbox-list    = "(" [mbx-list-flags] ")" SP
    //                    (DQUOTE QUOTED-CHAR DQUOTE / nil) SP mailbox
    //                    [SP mbox-list-extended]
    static func parseMailboxList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.List {
        func parseMailboxList_quotedChar_some(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Character? {
            try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Character? in
                try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)

                guard let character = buffer.readSlice(length: 1)?.readableBytesView.first else {
                    throw ParsingError.incompleteMessage
                }
                guard character.isQuotedChar else {
                    throw ParserError(hint: "Expected quoted char found \(String(decoding: [character], as: Unicode.UTF8.self))")
                }

                try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
                return Character(UnicodeScalar(character))
            }
        }

        func parseMailboxList_quotedChar_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Character? {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return nil
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> MailboxName.List in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let flags = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> MailboxName.List.Flags in
                try self.parseMailboxListFlags(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let character = try ParserLibrary.parseOneOf([
                parseMailboxList_quotedChar_some,
                parseMailboxList_quotedChar_nil,
            ], buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let listExtended = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: { (buffer, tracker) -> [MailboxName.ListExtendedItem] in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseMailboxListExtended(buffer: &buffer, tracker: tracker)
            }) ?? []
            return MailboxName.List(flags: flags, char: character, mailbox: mailbox, listExtended: listExtended)
        }
    }

    // mbox-list-extended =  "(" [mbox-list-extended-item
    //                       *(SP mbox-list-extended-item)] ")"
    static func parseMailboxListExtended(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [MailboxName.ListExtendedItem] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [MailboxName.ListExtendedItem] in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let data = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [MailboxName.ListExtendedItem] in
                var array = [try self.parseMailboxListExtendedItem(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> MailboxName.ListExtendedItem in
                    try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                    return try self.parseMailboxListExtendedItem(buffer: &buffer, tracker: tracker)
                }
                return array
            } ?? []
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return data
        }
    }

    // mbox-list-extended-item =  mbox-list-extended-item-tag SP
    //                            tagged-ext-val
    static func parseMailboxListExtendedItem(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.ListExtendedItem {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> MailboxName.ListExtendedItem in
            let tag = try self.parseMailboxListExtendedItemTag(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let val = try self.parseTaggedExtensionValue(buffer: &buffer, tracker: tracker)
            return MailboxName.ListExtendedItem(tag: tag, extensionValue: val)
        }
    }

    // mbox-list-extended-item-tag =  astring
    static func parseMailboxListExtendedItemTag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try self.parseAString(buffer: &buffer, tracker: tracker)
    }

    // mbox-or-pat =  list-mailbox / patterns
    static func parseMailboxOrPat(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxPatterns {
        func parseMailboxOrPat_list(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxPatterns {
            .mailbox(try self.parseListMailbox(buffer: &buffer, tracker: tracker))
        }

        func parseMailboxOrPat_patterns(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxPatterns {
            .pattern(try self.parsePatterns(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseMailboxOrPat_list,
            parseMailboxOrPat_patterns,
        ], buffer: &buffer, tracker: tracker)
    }

    // mbx-list-flags  = *(mbx-list-oflag SP) mbx-list-sflag
    //                   *(SP mbx-list-oflag) /
    //                   mbx-list-oflag *(SP mbx-list-oflag)
    static func parseMailboxListFlags(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.List.Flags {
        func parseMailboxListFlags_mixedArray(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.List.Flags {
            var oFlags = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> MailboxName.List.OFlag in
                let flag = try self.parseMailboxListOflag(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return flag
            }
            let sFlag = try self.parseMailboxListSflag(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &oFlags, tracker: tracker) { (buffer, tracker) -> MailboxName.List.OFlag in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseMailboxListOflag(buffer: &buffer, tracker: tracker)
            }
            return MailboxName.List.Flags(oFlags: oFlags, sFlag: sFlag)
        }

        func parseMailboxListFlags_OFlags(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.List.Flags {
            var output = [try self.parseMailboxListOflag(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { (buffer, tracker) -> MailboxName.List.OFlag in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseMailboxListOflag(buffer: &buffer, tracker: tracker)
            }
            return MailboxName.List.Flags(oFlags: output, sFlag: nil)
        }

        return try ParserLibrary.parseOneOf([
            parseMailboxListFlags_mixedArray,
            parseMailboxListFlags_OFlags,
        ], buffer: &buffer, tracker: tracker)
    }

    // mbx-list-oflag  = "\Noinferiors" / child-mbox-flag /
    //                   "\Subscribed" / "\Remote" / flag-extension
    static func parseMailboxListOflag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.List.OFlag {
        // protect against parsing an sflag
        let saved = buffer
        if let sFlag = try? self.parseMailboxListSflag(buffer: &buffer, tracker: tracker) {
            throw ParserError(hint: "\(sFlag) is an sFlag, so can't treat as oFlag")
        }
        buffer = saved

        func parseMailboxListOflag_inferiors(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.List.OFlag {
            try ParserLibrary.parseFixedString("\\Noinferiors", buffer: &buffer, tracker: tracker)
            return .noInferiors
        }

        func parseMailboxListOflag_flagExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.List.OFlag {
            .other(try self.parseFlagExtension(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseMailboxListOflag_inferiors,
            parseMailboxListOflag_flagExtension,
        ], buffer: &buffer, tracker: tracker)
    }

    // mbx-list-sflag  = "\NonExistent" / "\Noselect" / "\Marked" / "\Unmarked"
    static func parseMailboxListSflag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxName.List.SFlag {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let string = try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { c -> Bool in
                isalpha(Int32(c)) != 0 || c == UInt8(ascii: "\\")
            }
            guard let flag = MailboxName.List.SFlag(rawValue: string) else {
                throw ParserError(hint: "Found \(string) which was not an sflag")
            }
            return flag
        }
    }

    // media-basic     = ((DQUOTE ("APPLICATION" / "AUDIO" / "IMAGE" /
    //                   "MESSAGE" / "VIDEO") DQUOTE) / string) SP
    //                   media-subtype
    static func parseMediaBasic(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.Basic {
        func parseMediaBasic_Type_defined(_ option: String, result: Media.BasicType, buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicType {
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(option, buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            return result
        }

        func parseMediaBasic_Type_application(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicType {
            try parseMediaBasic_Type_defined("APPLICATION", result: .application, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Type_audio(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicType {
            try parseMediaBasic_Type_defined("AUDIO", result: .audio, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Type_image(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicType {
            try parseMediaBasic_Type_defined("IMAGE", result: .image, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Type_message(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicType {
            try parseMediaBasic_Type_defined("MESSAGE", result: .message, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Type_video(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicType {
            try parseMediaBasic_Type_defined("VIDEO", result: .video, buffer: &buffer, tracker: tracker)
        }

        func parseMediaBasic_Type_other(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.BasicType {
            let buffer = try self.parseString(buffer: &buffer, tracker: tracker)
            return .other(String(buffer: buffer))
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Media.Basic in
            let basicType = try ParserLibrary.parseOneOf([
                parseMediaBasic_Type_application,
                parseMediaBasic_Type_audio,
                parseMediaBasic_Type_image,
                parseMediaBasic_Type_message,
                parseMediaBasic_Type_video,
                parseMediaBasic_Type_other,
            ], buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let subtype = try self.parseMediaSubtype(buffer: &buffer, tracker: tracker)
            return Media.Basic(type: basicType, subtype: subtype)
        }
    }

    // media-message   = DQUOTE "MESSAGE" DQUOTE SP
    //                   DQUOTE ("RFC822" / "GLOBAL") DQUOTE
    static func parseMediaMessage(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.Message {
        func parseMediaMessage_rfc(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.Message {
            try ParserLibrary.parseFixedString("RFC822", buffer: &buffer, tracker: tracker)
            return .rfc822
        }

        func parseMediaMessage_global(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Media.Message {
            try ParserLibrary.parseFixedString("GLOBAL", buffer: &buffer, tracker: tracker)
            return .global
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Media.Message in
            try ParserLibrary.parseFixedString("\"MESSAGE\" \"", buffer: &buffer, tracker: tracker)
            let message = try ParserLibrary.parseOneOf([
                parseMediaMessage_rfc,
                parseMediaMessage_global,
            ], buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            return message
        }
    }

    // media-subtype   = string
    static func parseMediaSubtype(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        var buffer = try self.parseString(buffer: &buffer, tracker: tracker)
        return buffer.readString(length: buffer.readableBytes)!
    }

    // media-text      = DQUOTE "TEXT" DQUOTE SP media-subtype
    static func parseMediaText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> String in
            try ParserLibrary.parseFixedString("\"TEXT\" ", buffer: &buffer, tracker: tracker)
            let subtype = try self.parseMediaSubtype(buffer: &buffer, tracker: tracker)
            return subtype
        }
    }

    // message-data    = nz-number SP ("EXPUNGE" / ("FETCH" SP msg-att))
    static func parseMessageData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageData {
        func parseMessageData_expunge(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageData {
            let number = try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" EXPUNGE", buffer: &buffer, tracker: tracker)
            return .expunge(number)
        }

        return try ParserLibrary.parseOneOf([
            parseMessageData_expunge,
        ], buffer: &buffer, tracker: tracker)
    }

    // mod-sequence-valzer = "0" / mod-sequence-value
    static func parseModifierSequenceValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ModifierSequenceValue {
        let number = try self.parseNumber(buffer: &buffer, tracker: tracker)
        guard let value = ModifierSequenceValue(number) else {
            throw ParserError(hint: "Unable to create ModifiersSequenceValueZero")
        }
        return value
    }

    // move            = "MOVE" SP sequence-set SP mailbox
    static func parseMove(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("MOVE ", buffer: &buffer, tracker: tracker)
            let set = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            return .move(set, mailbox)
        }
    }

    static func parseFetchStreamingResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> StreamingType {
        func parseFetchStreamingResponse_rfc822(buffer: inout ByteBuffer, tracker: StackTracker) throws -> StreamingType {
            try ParserLibrary.parseFixedString("RFC822.TEXT", buffer: &buffer, tracker: tracker)
            return .rfc822
        }

        func parseFetchStreamingResponse_bodySectionText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> StreamingType {
            try ParserLibrary.parseFixedString("BODY[TEXT]", buffer: &buffer, tracker: tracker)
            let number = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Int in
                try ParserLibrary.parseFixedString("<", buffer: &buffer, tracker: tracker)
                let num = try self.parseNumber(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseFixedString(">", buffer: &buffer, tracker: tracker)
                return num
            }
            return .body(partial: number)
        }

        func parseFetchStreamingResponse_binary(buffer: inout ByteBuffer, tracker: StackTracker) throws -> StreamingType {
            try ParserLibrary.parseFixedString("BINARY", buffer: &buffer, tracker: tracker)
            let section = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            return .binary(section: section)
        }

        return try ParserLibrary.parseOneOf([
            parseFetchStreamingResponse_rfc822,
            parseFetchStreamingResponse_bodySectionText,
            parseFetchStreamingResponse_binary,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseFetchResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchResponse {
        func parseFetchResponse_start(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchResponse {
            try ParserLibrary.parseFixedString("* ", buffer: &buffer, tracker: tracker)
            let number = try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" FETCH (", buffer: &buffer, tracker: tracker)
            return .start(number)
        }

        func parseFetchResponse_simpleAttribute(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchResponse {
            let attribute = try self.parseMessageAttribute(buffer: &buffer, tracker: tracker)
            return .simpleAttribute(attribute)
        }

        func parseFetchResponse_streamingBegin(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchResponse {
            let type = try self.parseFetchStreamingResponse(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let literalSize = try self.parseLiteralSize(buffer: &buffer, tracker: tracker)
            return .streamingBegin(type: type, byteCount: literalSize)
        }

        func parseFetchResponse_finish(buffer: inout ByteBuffer, tracker: StackTracker) throws -> FetchResponse {
            try ParserLibrary.parseFixedString(")\r\n", buffer: &buffer, tracker: tracker)
            return .finish
        }

        return try ParserLibrary.parseOneOf([
            parseFetchResponse_start,
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
            try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> MessageAttribute in
                try ParserLibrary.parseFixedString("FLAGS (", buffer: &buffer, tracker: tracker)
                var array = [try self.parseFlagFetch(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> Flag in
                    try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                    return try self.parseFlagFetch(buffer: &buffer, tracker: tracker)
                }
                try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
                return .flags(array)
            }
        }

        func parseMessageAttribute_envelope(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.parseFixedString("ENVELOPE ", buffer: &buffer, tracker: tracker)
            return .envelope(try self.parseEnvelope(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_internalDate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.parseFixedString("INTERNALDATE ", buffer: &buffer, tracker: tracker)
            return .internalDate(try self.parseDateTime(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_rfc822(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.parseFixedString("RFC822 ", buffer: &buffer, tracker: tracker)
            let string = try self.parseNString(buffer: &buffer, tracker: tracker)
            return .rfc822(string)
        }

        func parseMessageAttribute_rfc822Header(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.parseFixedString("RFC822.HEADER ", buffer: &buffer, tracker: tracker)
            let string = try self.parseNString(buffer: &buffer, tracker: tracker)
            return .rfc822Header(string)
        }

        func parseMessageAttribute_rfc822Text(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.parseFixedString("RFC822.TEXT ", buffer: &buffer, tracker: tracker)
            let string = try self.parseNString(buffer: &buffer, tracker: tracker)
            return .rfc822Text(string)
        }

        func parseMessageAttribute_rfc822Size(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.parseFixedString("RFC822.SIZE ", buffer: &buffer, tracker: tracker)
            return .rfc822Size(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_body(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.parseFixedString("BODY", buffer: &buffer, tracker: tracker)
            let structure: Bool = {
                do {
                    try ParserLibrary.parseFixedString("STRUCTURE", buffer: &buffer, tracker: tracker)
                    return true
                } catch {
                    return false
                }
            }()
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let body = try self.parseBody(buffer: &buffer, tracker: tracker)
            return .body(body, structure: structure)
        }

        func parseMessageAttribute_bodySection(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.parseFixedString("BODY", buffer: &buffer, tracker: tracker)
            let section = try self.parseSection(buffer: &buffer, tracker: tracker)
            let number = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Int in
                try ParserLibrary.parseFixedString("<", buffer: &buffer, tracker: tracker)
                let num = try self.parseNumber(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseFixedString(">", buffer: &buffer, tracker: tracker)
                return num
            }
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let string = try self.parseNString(buffer: &buffer, tracker: tracker)
            return .bodySection(section, partial: number, data: string)
        }

        func parseMessageAttribute_uid(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.parseFixedString("UID ", buffer: &buffer, tracker: tracker)
            return .uid(try self.parseUniqueID(buffer: &buffer, tracker: tracker))
        }

        func parseMessageAttribute_binarySize(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.parseFixedString("BINARY.SIZE", buffer: &buffer, tracker: tracker)
            let section = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let number = try self.parseNumber(buffer: &buffer, tracker: tracker)
            return .binarySize(section: section, size: number)
        }

        func parseMessageAttribute_binary(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MessageAttribute {
            try ParserLibrary.parseFixedString("BINARY", buffer: &buffer, tracker: tracker)
            let section = try self.parseSectionBinary(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let string = try self.parseNString(buffer: &buffer, tracker: tracker)
            return .binary(section: section, data: string)
        }

        return try ParserLibrary.parseOneOf([
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
        ], buffer: &buffer, tracker: tracker)
    }

    // Namespace         = nil / "(" 1*Namespace-Descr ")"
    static func parseNamespace(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NamespaceDescription] {
        func parseNamespace_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NamespaceDescription] {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return []
        }

        func parseNamespace_some(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [NamespaceDescription] {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let descriptions = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker, parser: self.parseNamespaceDescription)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return descriptions
        }

        return try ParserLibrary.parseOneOf([
            parseNamespace_nil,
            parseNamespace_some,
        ], buffer: &buffer, tracker: tracker)
    }

    // Namespace-Command = "NAMESPACE"
    static func parseNamespaceCommand(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseFixedString("NAMESPACE", buffer: &buffer, tracker: tracker)
        return .namespace
    }

    // Namespace-Descr   = "(" string SP
    //                        (DQUOTE QUOTED-CHAR DQUOTE / nil)
    //                         [Namespace-Response-Extensions] ")"
    static func parseNamespaceDescription(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NamespaceDescription {
        func parseNamespaceDescr_quotedChar(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Character? {
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            guard let char = buffer.readBytes(length: 1)?.first else {
                throw ParsingError.incompleteMessage
            }
            guard char.isQuotedChar else {
                throw ParserError(hint: "Invalid character")
            }
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            return Character(.init(char))
        }

        func parseNamespaceDescr_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Character? {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return nil
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NamespaceDescription in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let string = try self.parseString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let char = try ParserLibrary.parseOneOf([
                parseNamespaceDescr_quotedChar,
                parseNamespaceDescr_nil,
            ], buffer: &buffer, tracker: tracker)
            let extensions = try self.parseNamespaceResponseExtensions(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
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
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NamespaceResponseExtension in
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let s1 = try self.parseString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseString(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ByteBuffer in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseString(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return NamespaceResponseExtension(string: s1, array: array)
        }
    }

    // Namespace-Response = "*" SP "NAMESPACE" SP Namespace
    //                       SP Namespace SP Namespace
    static func parseNamespaceResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NamespaceResponse {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> NamespaceResponse in
            try ParserLibrary.parseFixedString("NAMESPACE ", buffer: &buffer, tracker: tracker)
            let n1 = try self.parseNamespace(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let n2 = try self.parseNamespace(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let n3 = try self.parseNamespace(buffer: &buffer, tracker: tracker)
            return NamespaceResponse(userNamespace: n1, otherUserNamespace: n2, sharedNamespace: n3)
        }
    }

    // nil             = "NIL"
    static func parseNil(buffer: inout ByteBuffer, tracker: StackTracker) throws {
        try ParserLibrary.parseFixedString("nil", buffer: &buffer, tracker: tracker)
    }

    // nstring         = string / nil
    static func parseNString(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NString {
        func parseNString_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NString {
            try ParserLibrary.parseFixedString("NIL", buffer: &buffer, tracker: tracker)
            return nil
        }

        func parseNString_some(buffer: inout ByteBuffer, tracker: StackTracker) throws -> NString {
            try self.parseString(buffer: &buffer, tracker: tracker)
        }

        return try ParserLibrary.parseOneOf([
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
        func parseOptionExtensionType_standard(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionExtensionType {
            .standard(try self.parseOptionStandardTag(buffer: &buffer, tracker: tracker))
        }

        func parseOptionExtensionType_vendor(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionExtensionType {
            .vendor(try self.parseOptionVendorTag(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> OptionExtension in
            let type = try ParserLibrary.parseOneOf([
                parseOptionExtensionType_standard,
                parseOptionExtensionType_vendor,
            ], buffer: &buffer, tracker: tracker)
            let value = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> OptionValueComp in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseOptionValue(buffer: &buffer, tracker: tracker)
            }
            return OptionExtension(type: type, value: value)
        }
    }

    // option-standard-tag =  atom
    static func parseOptionStandardTag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try self.parseAtom(buffer: &buffer, tracker: tracker)
    }

    // option-val-comp =  astring /
    //                    option-val-comp *(SP option-val-comp) /
    //                    "(" option-val-comp ")"
    static func parseOptionValueComp(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionValueComp {
        func parseOptionValueComp_string(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionValueComp {
            .string(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseOptionValueComp_single(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionValueComp {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let comp = try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .array([comp])
        }

        func parseOptionValueComp_array(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionValueComp {
            var array = [try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> OptionValueComp in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)
            }
            return .array(array)
        }

        return try ParserLibrary.parseOneOf([
            parseOptionValueComp_string,
            parseOptionValueComp_single,
            parseOptionValueComp_array,
        ], buffer: &buffer, tracker: tracker)
    }

    // option-value =  "(" option-val-comp ")"
    static func parseOptionValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionValueComp {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> OptionValueComp in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let comp = try self.parseOptionValueComp(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return comp
        }
    }

    // option-vendor-tag =  vendor-token "-" atom
    static func parseOptionVendorTag(buffer: inout ByteBuffer, tracker: StackTracker) throws -> OptionVendorTag {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> OptionVendorTag in
            let token = try self.parseVendorToken(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("-", buffer: &buffer, tracker: tracker)
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            return OptionVendorTag(token: token, atom: atom)
        }
    }

    // partial-range    = number ["." nz-number]
    static func parsePartialRange(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Partial.Range {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Partial.Range in
            let num1 = try self.parseNumber(buffer: &buffer, tracker: tracker)
            let num2 = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Int in
                try ParserLibrary.parseFixedString(".", buffer: &buffer, tracker: tracker)
                return try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            }
            return Partial.Range(from: num1, to: num2)
        }
    }

    // partial         = "<" number "." nz-number ">"
    static func parsePartial(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Partial {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Partial in
            try ParserLibrary.parseFixedString("<", buffer: &buffer, tracker: tracker)
            let num1 = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(".", buffer: &buffer, tracker: tracker)
            let num2 = try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(">", buffer: &buffer, tracker: tracker)
            return Partial(left: num1, right: num2)
        }
    }

    // password        = astring
    static func parsePassword(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        var buffer = try Self.parseAString(buffer: &buffer, tracker: tracker)
        return buffer.readString(length: buffer.readableBytes)!
    }

    // patterns        = "(" list-mailbox *(SP list-mailbox) ")"
    static func parsePatterns(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [ByteBuffer] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [ByteBuffer] in
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseListMailbox(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> ByteBuffer in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseListMailbox(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // quoted          = DQUOTE *QUOTED-CHAR DQUOTE
    static func parseQuoted(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ByteBuffer in
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            let data = try ParserLibrary.parseZeroOrMoreCharactersByteBuffer(buffer: &buffer, tracker: tracker) { char in
                char.isQuotedChar
            }
            try ParserLibrary.parseFixedString("\"", buffer: &buffer, tracker: tracker)
            return data
        }
    }

    // rename          = "RENAME" SP mailbox SP mailbox [rename-params]
    static func parseRename(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("RENAME ", buffer: &buffer, tracker: tracker)
            let from = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" ", caseSensitive: false, buffer: &buffer, tracker: tracker)
            let to = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseRenameParameters) ?? []
            return .rename(from: from, to: to, params: params)
        }
    }

    // rename-param = rename-param-name [SP rename-param-value]
    static func parseRenameParameter(buffer: inout ByteBuffer, tracker: StackTracker) throws -> RenameParameter {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let name = try self.parseRenameParameterName(buffer: &buffer, tracker: tracker)
            let value = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> TaggedExtensionValue in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseCreateParameterValue(buffer: &buffer, tracker: tracker)
            }
            return .init(name: name, value: value)
        }
    }

    // rename-params = SP "(" rename-param *(SP rename-param-value) ")"
    static func parseRenameParameters(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [RenameParameter] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString(" (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseRenameParameter(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> RenameParameter in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseRenameParameter(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // rename-param-name = tagged-ext-label
    static func parseRenameParameterName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try self.parseTaggedExtensionLabel(buffer: &buffer, tracker: tracker)
    }

    // rename-param-value = tagged-ext-val
    static func parseRenameParameterValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedExtensionValue {
        try self.parseTaggedExtensionValue(buffer: &buffer, tracker: tracker)
    }

    // response-data   = "*" SP response-payload CRLF
    static func parseResponseData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponsePayload {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString("* ", buffer: &buffer, tracker: tracker)
            let payload = try self.parseResponsePayload(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("\r\n", buffer: &buffer, tracker: tracker)
            return payload
        }
    }

    // response-fatal  = "*" SP resp-cond-bye CRLF
    static func parseResponseFatal(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseText {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ResponseText in
            try ParserLibrary.parseFixedString("* ", buffer: &buffer, tracker: tracker)
            let bye = try self.parseResponseConditionalBye(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("\r\n", buffer: &buffer, tracker: tracker)
            return bye
        }
    }

    // response-tagged = tag SP resp-cond-state CRLF
    static func parseTaggedResponse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedResponse {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> TaggedResponse in
            let tag = try self.parseTag(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
            let state = try self.parseResponseConditionalState(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseNewline(buffer: &buffer, tracker: tracker)
            return TaggedResponse(tag: tag, state: state)
        }
    }

    // resp-code-apnd  = "APPENDUID" SP nz-number SP append-uid
    static func parseResponseCodeAppend(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseCodeAppend {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ResponseCodeAppend in
            try ParserLibrary.parseFixedString("APPENDUID ", buffer: &buffer, tracker: tracker)
            let number = try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let uid = try self.parseAppendUid(buffer: &buffer, tracker: tracker)
            return ResponseCodeAppend(num: number, uid: uid)
        }
    }

    // resp-code-copy  = "COPYUID" SP nz-number SP uid-set SP uid-set
    static func parseResponseCodeCopy(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseCodeCopy {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ResponseCodeCopy in
            try ParserLibrary.parseFixedString("COPYUID ", buffer: &buffer, tracker: tracker)
            let num = try self.parseNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let set1 = try self.parseUidSet(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let set2 = try self.parseUidSet(buffer: &buffer, tracker: tracker)
            return ResponseCodeCopy(num: num, set1: set1, set2: set2)
        }
    }

    // resp-cond-auth  = ("OK" / "PREAUTH") SP resp-text
    static func parseResponseConditionalAuth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseConditionalAuth {
        func parseResponseConditionalAuth_ok(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseConditionalAuth {
            try ParserLibrary.parseFixedString("OK ", buffer: &buffer, tracker: tracker)
            return .ok(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        func parseResponseConditionalAuth_preauth(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseConditionalAuth {
            try ParserLibrary.parseFixedString("PREAUTH ", buffer: &buffer, tracker: tracker)
            return .preauth(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseResponseConditionalAuth_ok,
            parseResponseConditionalAuth_preauth,
        ], buffer: &buffer, tracker: tracker)
    }

    // resp-cond-bye   = "BYE" SP resp-text
    static func parseResponseConditionalBye(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseText {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ResponseText in
            try ParserLibrary.parseFixedString("BYE ", buffer: &buffer, tracker: tracker)
            return try self.parseResponseText(buffer: &buffer, tracker: tracker)
        }
    }

    // resp-cond-state = ("OK" / "NO" / "BAD") SP resp-text
    static func parseResponseConditionalState(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseConditionalState {
        func parseResponseConditionalState_ok(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseConditionalState {
            try ParserLibrary.parseFixedString("OK ", buffer: &buffer, tracker: tracker)
            return .ok(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        func parseResponseConditionalState_no(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseConditionalState {
            try ParserLibrary.parseFixedString("NO ", buffer: &buffer, tracker: tracker)
            return .no(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        func parseResponseConditionalState_bad(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseConditionalState {
            try ParserLibrary.parseFixedString("BAD ", buffer: &buffer, tracker: tracker)
            return .bad(try self.parseResponseText(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
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

        return try ParserLibrary.parseOneOf([
            parseResponsePayload_conditionalState,
            parseResponsePayload_conditionalBye,
            parseResponsePayload_mailboxData,
            parseResponsePayload_messageData,
            parseResponsePayload_capabilityData,
            parseResponsePayload_idResponse,
            parseResponsePayload_enableData,
        ], buffer: &buffer, tracker: tracker)
    }

    // resp-text       = ["[" resp-text-code "]" SP] text
    static func parseResponseText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseText {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> ResponseText in
            let code = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> ResponseTextCode in
                try ParserLibrary.parseFixedString("[", buffer: &buffer, tracker: tracker)
                let code = try self.parseResponseTextCode(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseFixedString("] ", buffer: &buffer, tracker: tracker)
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
    //                   atom [SP 1*<any TEXT-CHAR except "]">]
    static func parseResponseTextCode(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
        func parseResponseTextCode_alert(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try ParserLibrary.parseFixedString("ALERT", buffer: &buffer, tracker: tracker)
            return .alert
        }

        func parseResponseTextCode_badCharset(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try ParserLibrary.parseFixedString("BADCHARSET", buffer: &buffer, tracker: tracker)
            let charsets = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [String] in
                try ParserLibrary.parseFixedString(" (", buffer: &buffer, tracker: tracker)
                var array = [try self.parseCharset(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> String in
                    try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                    return try self.parseCharset(buffer: &buffer, tracker: tracker)
                }
                try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
                return array
            } ?? []
            return .badCharset(charsets)
        }

        func parseResponseTextCode_capabilityData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            .capability(try self.parseCapabilityData(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_parse(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try ParserLibrary.parseFixedString("PARSE", buffer: &buffer, tracker: tracker)
            return .parse
        }

        func parseResponseTextCode_permanentFlags(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try ParserLibrary.parseFixedString("PERMANENTFLAGS (", buffer: &buffer, tracker: tracker)
            let array = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [PermanentFlag] in
                var array = [try self.parseFlagPerm(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) in
                    try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                    return try self.parseFlagPerm(buffer: &buffer, tracker: tracker)
                }
                return array
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .permanentFlags(array ?? [])
        }

        func parseResponseTextCode_readOnly(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try ParserLibrary.parseFixedString("READ-ONLY", buffer: &buffer, tracker: tracker)
            return .readOnly
        }

        func parseResponseTextCode_readWrite(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try ParserLibrary.parseFixedString("READ-WRITE", buffer: &buffer, tracker: tracker)
            return .readWrite
        }

        func parseResponseTextCode_tryCreate(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try ParserLibrary.parseFixedString("TRYCREATE", buffer: &buffer, tracker: tracker)
            return .tryCreate
        }

        func parseResponseTextCode_uidNext(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try ParserLibrary.parseFixedString("UIDNEXT ", buffer: &buffer, tracker: tracker)
            return .uidNext(try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_uidValidity(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try ParserLibrary.parseFixedString("UIDVALIDITY ", buffer: &buffer, tracker: tracker)
            return .uidValidity(try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_unseen(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            try ParserLibrary.parseFixedString("UNSEEN ", buffer: &buffer, tracker: tracker)
            return .unseen(try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_namespace(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            .namespace(try self.parseNamespaceResponse(buffer: &buffer, tracker: tracker))
        }

        func parseResponseTextCode_atom(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ResponseTextCode {
            let atom = try self.parseAtom(buffer: &buffer, tracker: tracker)
            let string = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> String in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { (char) -> Bool in
                    char.isTextChar && char != UInt8(ascii: "]")
                }
            }
            return .other(atom, string)
        }

        return try ParserLibrary.parseOneOf([
            parseResponseTextCode_alert,
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
            parseResponseTextCode_atom,
        ], buffer: &buffer, tracker: tracker)
    }

    // return-option   =  "SUBSCRIBED" / "CHILDREN" / status-option /
    //                    option-extension
    static func parseReturnOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ReturnOption {
        func parseReturnOption_subscribed(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ReturnOption {
            try ParserLibrary.parseFixedString("SUBSCRIBED", buffer: &buffer, tracker: tracker)
            return .subscribed
        }

        func parseReturnOption_children(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ReturnOption {
            try ParserLibrary.parseFixedString("CHILDREN", buffer: &buffer, tracker: tracker)
            return .children
        }

        func parseReturnOption_statusOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ReturnOption {
            .statusOption(try self.parseStatusOption(buffer: &buffer, tracker: tracker))
        }

        func parseReturnOption_optionExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ReturnOption {
            .optionExtension(try self.parseOptionExtension(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseReturnOption_subscribed,
            parseReturnOption_children,
            parseReturnOption_statusOption,
            parseReturnOption_optionExtension,
        ], buffer: &buffer, tracker: tracker)
    }

    // search          = "SEARCH" [search-return-opts] SP search-program
    static func parseSearch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString("SEARCH", buffer: &buffer, tracker: tracker)
            let returnOpts = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseSearchReturnOptions) ?? []
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let program = try self.parseSearchProgram(buffer: &buffer, tracker: tracker)
            return .search(returnOptions: returnOpts, program: program)
        }
    }

    // search-correlator    = SP "(" "TAG" SP tag-string ")"
    static func parseSearchCorrelator(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString(" (TAG ", buffer: &buffer, tracker: tracker)
            let tag = try self.parseTagString(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return tag
        }
    }

    // search-critera = search-key *(search-key)
    static func parseSearchCriteria(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [SearchKey] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            var array = [try self.parseSearchKey(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
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
            try ParserLibrary.parseFixedString(string, buffer: &buffer, tracker: tracker)
            return result
        }

        func parseSearchKey_all(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try parseSearchKey_fixed(string: "ALL", result: .all, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_answered(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try parseSearchKey_fixed(string: "ANSWERED", result: .answered, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_bcc(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("BCC ", buffer: &buffer, tracker: tracker)
            return .bcc(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_before(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("BEFORE ", buffer: &buffer, tracker: tracker)
            return .before(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_body(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("BODY ", buffer: &buffer, tracker: tracker)
            return .body(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_cc(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("CC ", buffer: &buffer, tracker: tracker)
            return .cc(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_deleted(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try parseSearchKey_fixed(string: "DELETED", result: .deleted, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_flagged(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try parseSearchKey_fixed(string: "FLAGGED", result: .flagged, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_from(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("FROM ", buffer: &buffer, tracker: tracker)
            return .from(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_keyword(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("KEYWORD ", buffer: &buffer, tracker: tracker)
            return .keyword(try self.parseFlagKeyword(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_new(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try parseSearchKey_fixed(string: "NEW", result: .new, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_old(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try parseSearchKey_fixed(string: "OLD", result: .old, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_recent(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try parseSearchKey_fixed(string: "RECENT", result: .recent, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_seen(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try parseSearchKey_fixed(string: "SEEN", result: .seen, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_unseen(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try parseSearchKey_fixed(string: "UNSEEN", result: .unseen, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_unanswered(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try parseSearchKey_fixed(string: "UNANSWERED", result: .unanswered, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_undeleted(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try parseSearchKey_fixed(string: "UNDELETED", result: .undeleted, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_unflagged(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try parseSearchKey_fixed(string: "UNFLAGGED", result: .unflagged, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_draft(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try parseSearchKey_fixed(string: "DRAFT", result: .draft, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_undraft(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try parseSearchKey_fixed(string: "UNDRAFT", result: .undraft, buffer: &buffer, tracker: tracker)
        }

        func parseSearchKey_on(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("ON ", buffer: &buffer, tracker: tracker)
            return .on(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_since(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("SINCE ", buffer: &buffer, tracker: tracker)
            return .since(try self.parseDate(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_subject(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("SUBJECT ", buffer: &buffer, tracker: tracker)
            return .subject(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_text(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("TEXT ", buffer: &buffer, tracker: tracker)
            return .text(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_to(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("TO ", buffer: &buffer, tracker: tracker)
            return .to(try self.parseAString(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_unkeyword(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("UNKEYWORD ", buffer: &buffer, tracker: tracker)
            return .unkeyword(try self.parseFlagKeyword(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_filter(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("FILTER ", buffer: &buffer, tracker: tracker)
            return .filter(try self.parseFilterName(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_header(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("HEADER ", buffer: &buffer, tracker: tracker)
            let header = try self.parseHeaderFieldName(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let string = try self.parseAString(buffer: &buffer, tracker: tracker)
            return .header(header, string)
        }

        func parseSearchKey_larger(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("LARGER ", buffer: &buffer, tracker: tracker)
            return .larger(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_smaller(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("SMALLER ", buffer: &buffer, tracker: tracker)
            return .smaller(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_not(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("NOT ", buffer: &buffer, tracker: tracker)
            return .not(try self.parseSearchKey(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_or(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("OR ", buffer: &buffer, tracker: tracker)
            let key1 = try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let key2 = try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            return .or(key1, key2)
        }

        func parseSearchKey_sentBefore(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("SENTBEFORE ", buffer: &buffer, tracker: tracker)
            return .sent(.before(try self.parseDate(buffer: &buffer, tracker: tracker)))
        }

        func parseSearchKey_sentOn(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("SENTON ", buffer: &buffer, tracker: tracker)
            return .sent(.on(try self.parseDate(buffer: &buffer, tracker: tracker)))
        }

        func parseSearchKey_sentSince(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("SENTSINCE ", buffer: &buffer, tracker: tracker)
            return .sent(.since(try self.parseDate(buffer: &buffer, tracker: tracker)))
        }

        func parseSearchKey_uid(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("UID ", buffer: &buffer, tracker: tracker)
            return .uid(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_sequenceSet(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            .sequenceSet(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_array(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            var array = [try self.parseSearchKey(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> SearchKey in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .array(array)
        }

        func parseSearchKey_older(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("OLDER ", buffer: &buffer, tracker: tracker)
            return .older(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchKey_younger(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchKey {
            try ParserLibrary.parseFixedString("YOUNGER ", buffer: &buffer, tracker: tracker)
            return .younger(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseSearchKey_older,
            parseSearchKey_younger,
            parseSearchKey_all,
            parseSearchKey_answered,
            parseSearchKey_bcc,
            parseSearchKey_before,
            parseSearchKey_body,
            parseSearchKey_cc,
            parseSearchKey_deleted,
            parseSearchKey_flagged,
            parseSearchKey_from,
            parseSearchKey_keyword,
            parseSearchKey_new,
            parseSearchKey_old,
            parseSearchKey_recent,
            parseSearchKey_seen,
            parseSearchKey_unseen,
            parseSearchKey_unanswered,
            parseSearchKey_undeleted,
            parseSearchKey_unflagged,
            parseSearchKey_draft,
            parseSearchKey_undraft,
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
        ], buffer: &buffer, tracker: tracker)
    }

    // search-modifier-name = tagged-ext-label
    static func parseSearchModifierName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try self.parseTaggedExtensionLabel(buffer: &buffer, tracker: tracker)
    }

    // search-mod-params = tagged-ext-val
    static func parseSearchModifierParams(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedExtensionValue {
        try self.parseTaggedExtensionValue(buffer: &buffer, tracker: tracker)
    }

    // search-program       = ["CHARSET" SP charset SP] search-key *(SP search-key)
    static func parseSearchProgram(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchProgram {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let charset = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> String in
                try ParserLibrary.parseFixedString("CHARSET ", buffer: &buffer, tracker: tracker)
                let charset = try self.parseCharset(buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return charset
            }
            var array = [try self.parseSearchKey(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> SearchKey in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseSearchKey(buffer: &buffer, tracker: tracker)
            }
            return SearchProgram(charset: charset, keys: array)
        }
    }

    // search-ret-data-ext = search-modifier-name SP search-return-value
    static func parseSearchReturnDataExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnDataExtension {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> SearchReturnDataExtension in
            let modifier = try self.parseSearchModifierName(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let value = try self.parseSearchReturnValue(buffer: &buffer, tracker: tracker)
            return SearchReturnDataExtension(modifier: modifier, returnValue: value)
        }
    }

    // search-return-data = "MIN" SP nz-number /
    //                     "MAX" SP nz-number /
    //                     "ALL" SP sequence-set /
    //                     "COUNT" SP number /
    //                     search-ret-data-ext
    static func parseSearchReturnData(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnData {
        func parseSearchReturnData_min(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnData {
            try ParserLibrary.parseFixedString("MIN ", buffer: &buffer, tracker: tracker)
            return .min(try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_max(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnData {
            try ParserLibrary.parseFixedString("MAX ", buffer: &buffer, tracker: tracker)
            return .max(try self.parseNZNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_all(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnData {
            try ParserLibrary.parseFixedString("ALL ", buffer: &buffer, tracker: tracker)
            return .all(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_count(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnData {
            try ParserLibrary.parseFixedString("COUNT ", buffer: &buffer, tracker: tracker)
            return .count(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseSearchReturnData_dataExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnData {
            .dataExtension(try self.parseSearchReturnDataExtension(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseSearchReturnData_min,
            parseSearchReturnData_max,
            parseSearchReturnData_all,
            parseSearchReturnData_count,
            parseSearchReturnData_dataExtension,
        ], buffer: &buffer, tracker: tracker)
    }

    // search-return-opts   = SP "RETURN" SP "(" [search-return-opt *(SP search-return-opt)] ")"
    static func parseSearchReturnOptions(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [SearchReturnOption] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString(" RETURN (", buffer: &buffer, tracker: tracker)
            let array = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [SearchReturnOption] in
                var array = [try self.parseSearchReturnOption(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> SearchReturnOption in
                    try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                    return try self.parseSearchReturnOption(buffer: &buffer, tracker: tracker)
                }
                return array
            } ?? []
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // search-return-opt  = "MIN" / "MAX" / "ALL" / "COUNT" /
    //                      "SAVE" /
    //                      search-ret-opt-ext
    static func parseSearchReturnOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
        func parseSearchReturnOption_min(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            try ParserLibrary.parseFixedString("MIN", buffer: &buffer, tracker: tracker)
            return .min
        }

        func parseSearchReturnOption_max(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            try ParserLibrary.parseFixedString("MAX", buffer: &buffer, tracker: tracker)
            return .max
        }

        func parseSearchReturnOption_all(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            try ParserLibrary.parseFixedString("ALL", buffer: &buffer, tracker: tracker)
            return .all
        }

        func parseSearchReturnOption_count(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            try ParserLibrary.parseFixedString("COUNT", buffer: &buffer, tracker: tracker)
            return .count
        }

        func parseSearchReturnOption_save(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            try ParserLibrary.parseFixedString("SAVE", buffer: &buffer, tracker: tracker)
            return .save
        }

        func parseSearchReturnOption_extension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SearchReturnOption {
            let optionExtension = try self.parseSearchReturnOptionExtension(buffer: &buffer, tracker: tracker)
            return .optionExtension(optionExtension)
        }

        return try ParserLibrary.parseOneOf([
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
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> SearchReturnOptionExtension in
            let name = try self.parseSearchModifierName(buffer: &buffer, tracker: tracker)
            let params = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> TaggedExtensionValue in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseSearchModifierParams(buffer: &buffer, tracker: tracker)
            }
            return SearchReturnOptionExtension(modifierName: name, params: params)
        }
    }

    // search-return-value = tagged-ext-val
    static func parseSearchReturnValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedExtensionValue {
        try self.parseTaggedExtensionValue(buffer: &buffer, tracker: tracker)
    }

    // section         = "[" [section-spec] "]"
    static func parseSection(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpec? {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> SectionSpec? in
            try ParserLibrary.parseFixedString("[", buffer: &buffer, tracker: tracker)
            let spec = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> SectionSpec in
                try self.parseSectionSpec(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString("]", buffer: &buffer, tracker: tracker)
            return spec
        }
    }

    // section-binary  = "[" [section-part] "]"
    static func parseSectionBinary(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Int] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [Int] in
            try ParserLibrary.parseFixedString("[", buffer: &buffer, tracker: tracker)
            let part = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try self.parseSectionPart(buffer: &buffer, tracker: tracker)
            } ?? []
            try ParserLibrary.parseFixedString("]", buffer: &buffer, tracker: tracker)
            return part
        }
    }

    // section-msgtext = "HEADER" / "HEADER.FIELDS" [".NOT"] SP header-list /
    //                   "TEXT"
    static func parseSectionMessageText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionMessageText {
        func parseSectionMessageText_header(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionMessageText {
            try ParserLibrary.parseFixedString("HEADER", buffer: &buffer, tracker: tracker)
            return .header
        }

        func parseSectionMessageText_headerFields(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionMessageText {
            try ParserLibrary.parseFixedString("HEADER.FIELDS ", buffer: &buffer, tracker: tracker)
            return .headerFields(try self.parseHeaderList(buffer: &buffer, tracker: tracker))
        }

        func parseSectionMessageText_notHeaderFields(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionMessageText {
            try ParserLibrary.parseFixedString("HEADER.FIELDS.NOT ", buffer: &buffer, tracker: tracker)
            return .notHeaderFields(try self.parseHeaderList(buffer: &buffer, tracker: tracker))
        }

        func parseSectionMessageText_text(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionMessageText {
            try ParserLibrary.parseFixedString("TEXT", buffer: &buffer, tracker: tracker)
            return .text
        }

        return try ParserLibrary.parseOneOf([
            parseSectionMessageText_headerFields,
            parseSectionMessageText_notHeaderFields,
            parseSectionMessageText_header,
            parseSectionMessageText_text,
        ], buffer: &buffer, tracker: tracker)
    }

    // section-part    = nz-number *("." nz-number)
    static func parseSectionPart(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Int] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [Int] in
            var output = [try self.parseNZNumber(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { (buffer, tracker) -> Int in
                try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> Int in
                    try ParserLibrary.parseFixedString(".", buffer: &buffer, tracker: tracker)
                    return try self.parseNZNumber(buffer: &buffer, tracker: tracker)
                }
            }
            return output
        }
    }

    // section-spec    = section-msgtext / (section-part ["." section-text])
    static func parseSectionSpec(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpec {
        func parseSectionSpec_messageText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpec {
            .text(try self.parseSectionMessageText(buffer: &buffer, tracker: tracker))
        }

        func parseSectionSpec_part(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionSpec {
            let part = try self.parseSectionPart(buffer: &buffer, tracker: tracker)
            let text = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> SectionText in
                try ParserLibrary.parseFixedString(".", buffer: &buffer, tracker: tracker)
                return .message(try self.parseSectionMessageText(buffer: &buffer, tracker: tracker))
            }
            return .part(part, text: text)
        }

        return try ParserLibrary.parseOneOf([
            parseSectionSpec_messageText,
            parseSectionSpec_part,
        ], buffer: &buffer, tracker: tracker)
    }

    // section-text    = section-msgtext / "MIME"
    static func parseSectionText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionText {
        func parseSectionText_mime(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionText {
            try ParserLibrary.parseFixedString("MIME", buffer: &buffer, tracker: tracker)
            return .mime
        }

        func parseSectionText_messageText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SectionText {
            .message(try self.parseSectionMessageText(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseSectionText_mime,
            parseSectionText_messageText,
        ], buffer: &buffer, tracker: tracker)
    }

    // select          = "SELECT" SP mailbox [select-params]
    static func parseSelect(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("SELECT ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            let params = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseSelectParameters) ?? []
            return .select(mailbox, params)
        }
    }

    // select-params = SP "(" select-param *(SP select-param ")"
    static func parseSelectParameters(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [SelectParameter] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [SelectParameter] in
            try ParserLibrary.parseFixedString(" (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseSelectParameter(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> SelectParameter in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseSelectParameter(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // select-param = select-param-name [SP select-param-value]
    static func parseSelectParameter(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SelectParameter {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> SelectParameter in
            let name = try self.parseSelectParameterName(buffer: &buffer, tracker: tracker)
            let value = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> TaggedExtensionValue in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseSelectParameterValue(buffer: &buffer, tracker: tracker)
            }
            return .init(name: name, value: value)
        }
    }

    // select-param-name = tagged-ext-name
    static func parseSelectParameterName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try self.parseTaggedExtensionLabel(buffer: &buffer, tracker: tracker)
    }

    // select-param-value = tagged-ext-value
    static func parseSelectParameterValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedExtensionValue {
        try self.parseTaggedExtensionValue(buffer: &buffer, tracker: tracker)
    }

    // seq-number      = nz-number / "*"
    static func parseSequenceNumber(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SequenceNumber {
        func parseSequenceNumber_wildcard(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SequenceNumber {
            try ParserLibrary.parseFixedString("*", buffer: &buffer, tracker: tracker)
            return .last
        }

        func parseSequenceNumber_number(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SequenceNumber {
            let num = try self.parseNZNumber(buffer: &buffer, tracker: tracker)
            return .number(num)
        }

        return try ParserLibrary.parseOneOf([
            parseSequenceNumber_wildcard,
            parseSequenceNumber_number,
        ], buffer: &buffer, tracker: tracker)
    }

    // seq-range       = seq-number ":" seq-number
    static func parseSequenceRange(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SequenceRange {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> SequenceRange in
            let num1 = try self.parseSequenceNumber(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(":", buffer: &buffer, tracker: tracker)
            let num2 = try self.parseSequenceNumber(buffer: &buffer, tracker: tracker)
            return SequenceRange(num1 ... num2)
        }
    }

    // sequence-set    = (seq-number / seq-range) ["," sequence-set]
    static func parseSequenceSet(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [SequenceRange] {
        func parseSequenceSet_number(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SequenceRange {
            let num = try self.parseSequenceNumber(buffer: &buffer, tracker: tracker)
            return SequenceRange(from: num, to: num)
        }

        func parseSequenceSet_element(buffer: inout ByteBuffer, tracker: StackTracker) throws -> SequenceRange {
            try ParserLibrary.parseOneOf([
                self.parseSequenceRange,
                parseSequenceSet_number,
            ], buffer: &buffer, tracker: tracker)
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            var output = [try parseSequenceSet_element(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { buffer, tracker in
                try ParserLibrary.parseFixedString(",", buffer: &buffer, tracker: tracker)
                return try parseSequenceSet_element(buffer: &buffer, tracker: tracker)
            }
            return output
        }
    }

    // status          = "STATUS" SP mailbox SP
    //                   "(" status-att *(SP status-att) ")"
    static func parseStatus(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("STATUS ", buffer: &buffer, tracker: tracker)
            let mailbox = try self.parseMailbox(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(" (", buffer: &buffer, tracker: tracker)
            var atts = [try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &atts, tracker: tracker) { buffer, tracker -> MailboxAttribute in
                try ParserLibrary.parseFixedString(" ", buffer: &buffer, tracker: tracker)
                return try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
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

    // status-att-val   = ("MESSAGES" SP number) /
    //                    ("UIDNEXT" SP nz-number) /
    //                    ("UIDVALIDITY" SP nz-number) /
    //                    ("UNSEEN" SP number) /
    //                    ("DELETED" SP number) /
    //                    ("SIZE" SP number64)
    //
    static func parseStatusAttributeValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
        func parseStatusAttributeValue_messages(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try ParserLibrary.parseFixedString("MESSAGES ", buffer: &buffer, tracker: tracker)
            return .messages(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_uidnext(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try ParserLibrary.parseFixedString("UIDNEXT ", buffer: &buffer, tracker: tracker)
            return .uidNext(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_uidvalidity(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try ParserLibrary.parseFixedString("UIDVALIDITY ", buffer: &buffer, tracker: tracker)
            return .uidValidity(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_unseen(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try ParserLibrary.parseFixedString("UNSEEN ", buffer: &buffer, tracker: tracker)
            return .unseen(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_deleted(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try ParserLibrary.parseFixedString("DELETED ", buffer: &buffer, tracker: tracker)
            return .deleted(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_size(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try ParserLibrary.parseFixedString("SIZE ", buffer: &buffer, tracker: tracker)
            return .size(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseStatusAttributeValue_modSequence(buffer: inout ByteBuffer, tracker: StackTracker) throws -> MailboxValue {
            try ParserLibrary.parseFixedString("HIGHESTMODSEQ ", buffer: &buffer, tracker: tracker)
            return .modSequence(try self.parseModifierSequenceValue(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseStatusAttributeValue_messages,
            parseStatusAttributeValue_uidnext,
            parseStatusAttributeValue_uidvalidity,
            parseStatusAttributeValue_unseen,
            parseStatusAttributeValue_deleted,
            parseStatusAttributeValue_size,
            parseStatusAttributeValue_modSequence,
        ], buffer: &buffer, tracker: tracker)
    }

    // status-att-list  = status-att-val *(SP status-att-val)
    static func parseStatusAttributeList(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [MailboxValue] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [MailboxValue] in
            var array = [try parseStatusAttributeValue(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> MailboxValue in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try parseStatusAttributeValue(buffer: &buffer, tracker: tracker)
            }
            return array
        }
    }

    // status-option = "STATUS" SP "(" status-att *(SP status-att) ")"
    static func parseStatusOption(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [MailboxAttribute] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [MailboxAttribute] in
            try ParserLibrary.parseFixedString("STATUS (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> MailboxAttribute in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseStatusAttribute(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // store           = "STORE" SP sequence-set SP store-att-flags
    static func parseStore(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("STORE ", buffer: &buffer, tracker: tracker)
            let sequence = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            let modifiers = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseStoreModifiers) ?? []
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let flags = try self.parseStoreAttributeFlags(buffer: &buffer, tracker: tracker)
            return .store(sequence, modifiers, flags)
        }
    }

    // store-att-flags = (["+" / "-"] "FLAGS" [".SILENT"]) SP
    //                   (flag-list / (flag *(SP flag)))
    static func parseStoreAttributeFlags(buffer: inout ByteBuffer, tracker: StackTracker) throws -> StoreAttributeFlags {
        func parseStoreAttributeFlags_silent(buffer: inout ByteBuffer, tracker: StackTracker) -> Bool {
            do {
                try ParserLibrary.parseFixedString(".SILENT", buffer: &buffer, tracker: tracker)
                return true
            } catch {
                return false
            }
        }

        func parseStoreAttributeFlags_array(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Flag] {
            try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [Flag] in
                var output = [try self.parseFlag(buffer: &buffer, tracker: tracker)]
                try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &output, tracker: tracker) { (buffer, tracker) -> Flag in
                    try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                    return try self.parseFlag(buffer: &buffer, tracker: tracker)
                }
                return output
            }
        }

        func parseStoreAttributeFlags_type(buffer: inout ByteBuffer, tracker: StackTracker) throws -> StoreAttributeFlagsType {
            try ParserLibrary.parseOneOf([
                { (buffer: inout ByteBuffer, tracker: StackTracker) -> StoreAttributeFlagsType in
                    try ParserLibrary.parseFixedString("+FLAGS", buffer: &buffer, tracker: tracker)
                    return .add
                },
                { (buffer: inout ByteBuffer, tracker: StackTracker) -> StoreAttributeFlagsType in
                    try ParserLibrary.parseFixedString("-FLAGS", buffer: &buffer, tracker: tracker)
                    return .remove
                },
                { (buffer: inout ByteBuffer, tracker: StackTracker) -> StoreAttributeFlagsType in
                    try ParserLibrary.parseFixedString("FLAGS", buffer: &buffer, tracker: tracker)
                    return .other
                },
            ], buffer: &buffer, tracker: tracker)
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> StoreAttributeFlags in
            let type = try parseStoreAttributeFlags_type(buffer: &buffer, tracker: tracker)
            let silent = parseStoreAttributeFlags_silent(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let flags = try ParserLibrary.parseOneOf([
                parseStoreAttributeFlags_array,
                parseFlagList,
            ], buffer: &buffer, tracker: tracker)
            return StoreAttributeFlags(type: type, silent: silent, flags: flags)
        }
    }

    // store-modifier = store-modifier-name [SP store-modif-params]
    static func parseStoreModifier(buffer: inout ByteBuffer, tracker: StackTracker) throws -> StoreModifier {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let name = try self.parseStoreModifierName(buffer: &buffer, tracker: tracker)
            let params = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> TaggedExtensionValue in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseStoreModifierParameters(buffer: &buffer, tracker: tracker)
            }
            return .init(name: name, parameters: params)
        }
    }

    // store-modifiers = SP "(" store-modifier *(SP store-modifier ")"
    static func parseStoreModifiers(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [StoreModifier] {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try ParserLibrary.parseFixedString(" (", buffer: &buffer, tracker: tracker)
            var array = [try self.parseStoreModifier(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> StoreModifier in
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
                return try self.parseStoreModifier(buffer: &buffer, tracker: tracker)
            }
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return array
        }
    }

    // store-modifier-name = tagged-ext-label
    static func parseStoreModifierName(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try self.parseTaggedExtensionLabel(buffer: &buffer, tracker: tracker)
    }

    // store-modifier-params = tagged-ext-val
    static func parseStoreModifierParameters(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedExtensionValue {
        try self.parseTaggedExtensionValue(buffer: &buffer, tracker: tracker)
    }

    // string          = quoted / literal
    static func parseString(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try ParserLibrary.parseOneOf([
            Self.parseQuoted,
            Self.parseLiteral,
        ], buffer: &buffer, tracker: tracker)
    }

    // subscribe       = "SUBSCRIBE" SP mailbox
    static func parseSubscribe(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("SUBSCRIBE ", buffer: &buffer, tracker: tracker)
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

    // tag-string       = string
    static func parseTagString(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try self.parseString(buffer: &buffer, tracker: tracker)
    }

    // tagged-ext = tagged-ext-label SP tagged-ext-val
    static func parseTaggedExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedExtension {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            let label = try self.parseTaggedExtensionLabel(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            let value = try self.parseTaggedExtensionValue(buffer: &buffer, tracker: tracker)
            return .init(label: label, value: value)
        }
    }

    // tagged-ext-label    = tagged-label-fchar *tagged-label-char
    static func parseTaggedExtensionLabel(buffer: inout ByteBuffer, tracker: StackTracker) throws -> String {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> String in

            guard let fchar = buffer.readBytes(length: 1)?.first else {
                throw ParsingError.incompleteMessage
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
                try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
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
            try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
                try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
                try self.parseTaggedExtensionComplex_helper(into: &into, buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
                try self.parseTaggedExtensionComplex_continuation(into: &into, buffer: &buffer, tracker: tracker)
            }
        }

        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
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

    // tagged-ext-simple   = sequence-set / number / number64
    static func parseTaggedExtensionSimple(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedExtensionSimple {
        func parseTaggedExtensionSimple_set(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedExtensionSimple {
            .sequence(try self.parseSequenceSet(buffer: &buffer, tracker: tracker))
        }

        func parseTaggedExtensionSimple_number(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedExtensionSimple {
            .number(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        func parseTaggedExtensionSimple_number64(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedExtensionSimple {
            .number64(try self.parseNumber(buffer: &buffer, tracker: tracker))
        }

        return try ParserLibrary.parseOneOf([
            parseTaggedExtensionSimple_set,
            parseTaggedExtensionSimple_number,
            parseTaggedExtensionSimple_number64,
        ], buffer: &buffer, tracker: tracker)
    }

    // tagged-ext-val      = tagged-ext-simple /
    //                       "(" [tagged-ext-comp] ")"
    static func parseTaggedExtensionValue(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedExtensionValue {
        func parseTaggedExtensionVal_simple(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedExtensionValue {
            .simple(try self.parseTaggedExtensionSimple(buffer: &buffer, tracker: tracker))
        }

        func parseTaggedExtensionVal_comp(buffer: inout ByteBuffer, tracker: StackTracker) throws -> TaggedExtensionValue {
            try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
            let comp = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker, parser: self.parseTaggedExtensionComplex) ?? []
            try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
            return .comp(comp)
        }

        return try ParserLibrary.parseOneOf([
            parseTaggedExtensionVal_simple,
            parseTaggedExtensionVal_comp,
        ], buffer: &buffer, tracker: tracker)
    }

    // text            = 1*TEXT-CHAR
    static func parseText(buffer: inout ByteBuffer, tracker: StackTracker) throws -> ByteBuffer {
        try ParserLibrary.parseOneOrMoreCharactersByteBuffer(buffer: &buffer, tracker: tracker) { char -> Bool in
            char.isTextChar
        }
    }

    // time            = 2DIGIT ":" 2DIGIT ":" 2DIGIT
    static func parseTime(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Date.Time {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Date.Time in
            let hour = try self.parse2Digit(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(":", buffer: &buffer, tracker: tracker)
            let minute = try self.parse2Digit(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(":", buffer: &buffer, tracker: tracker)
            let second = try self.parse2Digit(buffer: &buffer, tracker: tracker)
            return Date.Time(hour: hour, minute: minute, second: second)
        }
    }

    // uid             = "UID" SP
    //                   (copy / move / fetch / search / store / uid-expunge)
    static func parseUid(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        func parseUid_copy(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            guard case .copy(let set, let mailbox) = try self.parseCopy(buffer: &buffer, tracker: tracker) else {
                fatalError("This should never happen")
            }
            return .uidCopy(set, mailbox)
        }

        func parseUid_move(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            guard case .move(let set, let mailbox) = try self.parseMove(buffer: &buffer, tracker: tracker) else {
                fatalError("This should never happen")
            }
            return .uidMove(set, mailbox)
        }

        func parseUid_fetch(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            guard case .fetch(let set, let type, let modifiers) = try self.parseFetch(buffer: &buffer, tracker: tracker) else {
                fatalError("This should never happen")
            }
            return .uidFetch(set, type, modifiers)
        }

        func parseUid_search(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            guard case .search(let options, let program) = try self.parseSearch(buffer: &buffer, tracker: tracker) else {
                fatalError("This should never happen")
            }
            return .uidSearch(returnOptions: options, program: program)
        }

        func parseUid_store(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            guard case .store(let set, let modifiers, let flags) = try self.parseStore(buffer: &buffer, tracker: tracker) else {
                fatalError("This should never happen")
            }
            return .uidStore(set, modifiers, flags)
        }

        func parseUid_expunge(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
            try ParserLibrary.parseFixedString("EXPUNGE ", buffer: &buffer, tracker: tracker)
            let set = try self.parseSequenceSet(buffer: &buffer, tracker: tracker)
            return .uidExpunge(set)
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("UID ", buffer: &buffer, tracker: tracker)
            return try ParserLibrary.parseOneOf([
                parseUid_copy,
                parseUid_move,
                parseUid_fetch,
                parseUid_search,
                parseUid_store,
                parseUid_expunge,
            ], buffer: &buffer, tracker: tracker)
        }
    }

    // uid-set         = (uniqueid / uid-range) *("," uid-set)
    static func parseUidSet(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [UIDSetType] {
        func parseUidSetType_id(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UIDSetType {
            .uniqueID(try self.parseUniqueID(buffer: &buffer, tracker: tracker))
        }

        func parseUidSetType_range(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UIDSetType {
            .range(try self.parseUidRange(buffer: &buffer, tracker: tracker))
        }

        func parseUidSetType(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UIDSetType {
            try ParserLibrary.parseOneOf([
                parseUidSetType_range,
                parseUidSetType_id,
            ], buffer: &buffer, tracker: tracker)
        }

        return try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> [UIDSetType] in
            var array = [try parseUidSetType(buffer: &buffer, tracker: tracker)]
            try ParserLibrary.parseZeroOrMore(buffer: &buffer, into: &array, tracker: tracker) { (buffer, tracker) -> UIDSetType in
                try ParserLibrary.parseFixedString(",", buffer: &buffer, tracker: tracker)
                return try parseUidSetType(buffer: &buffer, tracker: tracker)
            }
            return array
        }
    }

    // uid-range       = (uniqueid ":" uniqueid)
    static func parseUidRange(buffer: inout ByteBuffer, tracker: StackTracker) throws -> UIDRange {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> UIDRange in
            let id1 = try self.parseUniqueID(buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString(":", buffer: &buffer, tracker: tracker)
            let id2 = try self.parseUniqueID(buffer: &buffer, tracker: tracker)
            return UIDRange(left: id1, right: id2)
        }
    }

    // uniqueid        = nz-number
    static func parseUniqueID(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        try self.parseNZNumber(buffer: &buffer, tracker: tracker)
    }

    // unsubscribe     = "UNSUBSCRIBE" SP mailbox
    static func parseUnsubscribe(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Command {
        try ParserLibrary.parseComposite(buffer: &buffer, tracker: tracker) { buffer, tracker -> Command in
            try ParserLibrary.parseFixedString("UNSUBSCRIBE ", buffer: &buffer, tracker: tracker)
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

    // zone            = ("+" / "-") 4DIGIT
    static func parseZone(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Date.TimeZone {
        func parseZonePositive(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Date.TimeZone {
            try ParserLibrary.parseFixedString("+", buffer: &buffer, tracker: tracker)
            let num = try self.parse4Digit(buffer: &buffer, tracker: tracker)
            guard let zone = Date.TimeZone(num) else {
                throw ParserError(hint: "Building TimeZone from \(num) failed")
            }
            return zone
        }

        func parseZoneNegative(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Date.TimeZone {
            try ParserLibrary.parseFixedString("-", buffer: &buffer, tracker: tracker)
            let num = try self.parse4Digit(buffer: &buffer, tracker: tracker)
            guard let zone = Date.TimeZone(-num) else {
                throw ParserError(hint: "Building TimeZone from \(num) failed")
            }
            return zone
        }

        return try ParserLibrary.parseOneOf([
            parseZonePositive,
            parseZoneNegative,
        ], buffer: &buffer, tracker: tracker)
    }
}

// MARK: - Helper Parsers

extension GrammarParser {
    static func parseBodyLocationExtension(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.FieldLocationExtension {
        let fieldLocation = try self.parseNString(buffer: &buffer, tracker: tracker)
        let extensions = try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> [BodyExtensionType] in
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            return try self.parseBodyExtension(buffer: &buffer, tracker: tracker)
        }
        return BodyStructure.FieldLocationExtension(location: fieldLocation, extensions: extensions)
    }

    static func parseBodyLanguageLocation(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.FieldLanguageLocation {
        let fieldLanguage = try self.parseBodyFieldLanguage(buffer: &buffer, tracker: tracker)
        try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
        let locationExtension = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) in
            try parseBodyLocationExtension(buffer: &buffer, tracker: tracker)
        }
        return BodyStructure.FieldLanguageLocation(language: fieldLanguage, location: locationExtension)
    }

    static func parseBodyDescriptionLanguage(buffer: inout ByteBuffer, tracker: StackTracker) throws -> BodyStructure.FieldDSPLanguage {
        let description = try self.parseBodyFieldDsp(buffer: &buffer, tracker: tracker)
        let language = try ParserLibrary.parseOptional(buffer: &buffer, tracker: tracker) { (buffer, tracker) -> BodyStructure.FieldLanguageLocation in
            try ParserLibrary.parseSpace(buffer: &buffer, tracker: tracker)
            return try parseBodyLanguageLocation(buffer: &buffer, tracker: tracker)
        }
        return BodyStructure.FieldDSPLanguage(fieldDSP: description, fieldLanguage: language)
    }

    static func parse2Digit(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        try self.parseNDigits(buffer: &buffer, tracker: tracker, bytes: 2)
    }

    static func parse4Digit(buffer: inout ByteBuffer, tracker: StackTracker) throws -> Int {
        try self.parseNDigits(buffer: &buffer, tracker: tracker, bytes: 4)
    }

    static func parseNDigits(buffer: inout ByteBuffer, tracker: StackTracker, bytes: Int) throws -> Int {
        let (num, size) = try ParserLibrary.parseUnsignedInteger(buffer: &buffer, tracker: tracker)
        guard size == bytes else {
            throw ParserError(hint: "Expected \(bytes) digits, got \(size)")
        }
        return num
    }

    // reusable for a lot of the env-* types
    static func parseEnvelopeAddresses(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Address] {
        try ParserLibrary.parseFixedString("(", buffer: &buffer, tracker: tracker)
        let addresses = try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try self.parseAddress(buffer: &buffer, tracker: tracker)
        }
        try ParserLibrary.parseFixedString(")", buffer: &buffer, tracker: tracker)
        return addresses
    }

    static func parseOptionalEnvelopeAddresses(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Address] {
        func parseOptionalEnvelopeAddresses_nil(buffer: inout ByteBuffer, tracker: StackTracker) throws -> [Address] {
            try self.parseNil(buffer: &buffer, tracker: tracker)
            return []
        }
        return try ParserLibrary.parseOneOf([
            parseEnvelopeAddresses,
            parseOptionalEnvelopeAddresses_nil,
        ], buffer: &buffer, tracker: tracker)
    }

    static func parseRFC822(buffer: inout ByteBuffer, tracker: StackTracker) throws -> RFC822 {
        func parseRFC822_header(buffer: inout ByteBuffer, tracker: StackTracker) throws -> RFC822 {
            try ParserLibrary.parseFixedString(".HEADER", buffer: &buffer, tracker: tracker)
            return .header
        }

        func parseRFC822_size(buffer: inout ByteBuffer, tracker: StackTracker) throws -> RFC822 {
            try ParserLibrary.parseFixedString(".SIZE", buffer: &buffer, tracker: tracker)
            return .size
        }

        func parseRFC822_text(buffer: inout ByteBuffer, tracker: StackTracker) throws -> RFC822 {
            try ParserLibrary.parseFixedString(".TEXT", buffer: &buffer, tracker: tracker)
            return .text
        }

        return try ParserLibrary.parseOneOf([
            parseRFC822_header,
            parseRFC822_size,
            parseRFC822_text,
        ], buffer: &buffer, tracker: tracker)
    }
}
