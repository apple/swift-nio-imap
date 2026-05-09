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

import Foundation
import NIOIMAP
#if canImport(Darwin)
import locale_h
import time_h
import xlocale
#endif

extension InternetMessageDate {
    /// Parses the date string.
    ///
    /// Performs a lenient parse as needed. It is better to return a slightly wrong date than no date at all.
    func parse() -> Foundation.Date? {
        return parseWithoutFoundation() ?? parseWithFoundation()
    }

    /// Creates an RFC 822 formatted `DateString` from the given `Date` and `Calendar`.
    ///
    /// Uses the calendar’s `timeZone` to format the time zone output.
    init(from date: Foundation.Date, calendar: Calendar) {
        self.init(date.formatAsRFC822(calendar: calendar))
    }
}

// MARK: - Internal Formatting

#if canImport(Darwin)
extension Foundation.Date {
    private func makeDarwinTM(calendar: Calendar) -> tm {
        let components = calendar.dateComponents(
            [.second, .minute, .hour, .day, .month, .year, .weekday, .timeZone],
            from: self
        )
        var t = tm()
        t.tm_sec = Int32(components.second ?? 0)  // seconds after the minute [0-60]
        t.tm_min = Int32(components.minute ?? 0)  // minutes after the hour [0-59]
        t.tm_hour = Int32(components.hour ?? 0)  // hours since midnight [0-23]
        t.tm_mday = Int32(components.day ?? 1)  // day of the month [1-31]
        t.tm_mon = Int32(components.month ?? 1) - 1  // months since January [0-11]
        t.tm_year = Int32(components.year ?? 100) - 1900  // years since 1900
        t.tm_wday = Int32(components.weekday ?? 1) - 1  // days since Sunday [0-6]
        t.tm_isdst = -1  // Disables `%z` output -- because we can’t use it.
        if let zone = components.timeZone {
            t.tm_gmtoff = zone.secondsFromGMT(for: self)  // offset from UTC in seconds
        }
        return t
    }

    func formatAsRFC822(calendar: Calendar) -> String {
        var output = [UInt8](repeating: 0, count: 80)
        let byteCount = output.withUnsafeMutableBufferPointer { outputBuffer -> Int in
            var t = makeDarwinTM(calendar: calendar)
            return outputBuffer.withMemoryRebound(to: Int8.self) { outputBuffer -> Int in
                let byteCount = strftime_l(
                    outputBuffer.baseAddress!,
                    outputBuffer.count,
                    "%a, %d %b %Y %H:%M:%S %z",
                    &t,
                    posixLocale
                )
                guard byteCount != 0 else { return 0 }
                // Print the GMT offset:
                let offsetInMinutes = t.tm_gmtoff / 60
                let offsetValue = (offsetInMinutes / 60) * 100 + (offsetInMinutes % 60)
                let byteCount2 = snprintf(
                    ptr: outputBuffer.baseAddress! + byteCount,
                    outputBuffer.count - byteCount,
                    "%+05d",
                    CInt(offsetValue)
                )
                return byteCount + Int(byteCount2)
            }
        }
        guard byteCount != 0, byteCount <= output.count else { fatalError() }
        return output.withUnsafeBufferPointer { outputBuffer -> String in
            String(cString: outputBuffer.baseAddress!)
        }
    }
}

nonisolated(unsafe) let posixLocale: locale_t = newlocale(0x3f, nil, nil)
#else
extension Foundation.Date {
    /// Formats the date as an RFC 822 date-time using `Foundation.DateFormatter`.
    ///
    /// This mirrors the Darwin `strftime`-based implementation. `DateFormatter`
    /// is backed by ICU on non-Darwin platforms, and its `en_US_POSIX` locale is
    /// independent of the process's C locale, so the output is stable regardless
    /// of the environment's `LANG`/`LC_*` settings. The single `Z` produces the
    /// numeric `±HHMM` offset RFC 822 requires.
    func formatAsRFC822(calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.string(from: self)
    }
}
#endif

// MARK: - Internal Parsing

extension InternetMessageDate {
    /// Parsing without bridging into Foundation is much more performant because:
    ///  1. we avoid bridging the bytes into a String and then NSString.
    ///  2. we can parse almost entirely without doing allocations.
    func parseWithoutFoundation() -> Foundation.Date? {
        #if canImport(Darwin)
        String(self).withCString { input -> Foundation.Date? in
            for format in strptimeDateFormats {
                if let date = scan(zeroTerminated: input, format: format) {
                    // Don’t return for dates before 1972. Those happen when
                    // a year without century is parsed as a 72 BC instead of 1972 BC.
                    if -900_000_000 < date.timeIntervalSinceReferenceDate {
                        return date
                    }
                }
            }
            return nil
        }
        #else
        // The `strptime_l`-based fast path is Darwin-only (glibc doesn't provide
        // `strptime_l`). On other platforms the Foundation path handles parsing.
        return nil
        #endif
    }

    func parseWithFoundation() -> Foundation.Date? {
        let string = String(self)
        // Strict:
        for formatter in FoundationFormatters() {
            formatter.isLenient = false
            if let date = formatter.date(from: string) {
                return date
            }
        }
        // Lenient:
        for formatter in FoundationFormatters() {
            formatter.isLenient = true
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }
}

/// Create all our formatters / scanners.
///
/// - Note: See https://developer.apple.com/library/archive/qa/qa1480/_index.html
#if canImport(Darwin)
private func scan(zeroTerminated inputBuffer: UnsafePointer<Int8>, format: String) -> Foundation.Date? {
    return format.withCString { formatBuffer -> Foundation.Date? in
        var t = tm()
        guard let r = strptime_l(inputBuffer, formatBuffer, &t, nil) else { return nil }
        let time = mktime(&t)
        let date = Date(timeIntervalSince1970: TimeInterval(time))
        if r.pointee == 0 {
            return date
        }
        // We still have more that we can parse.
        // If we have already parsed a “time zone offset from UTC”, skip
        // any remaining “time zone name”:
        guard format.contains("%z") && zeroTerminatedRemainderIsTimeZoneName(remainder: r) else {
            return nil
        }
        return date
    }
}

private func zeroTerminatedRemainderIsTimeZoneName(remainder: UnsafeMutablePointer<CChar>) -> Bool {
    let s = Scanner(string: String(cString: remainder))
    _ = s.scanUpToString("(")
    guard
        s.scanString("(") != nil,
        s.scanCharacters(from: .uppercaseLetters) != nil,
        s.scanString(")") != nil
    else { return false }
    _ = s.scanCharacters(from: .whitespacesAndNewlines)
    guard s.isAtEnd else { return false }
    return true
}
#endif

/// Returns the same formatter repeatedly, each time configured with a different format.
private struct FoundationFormatters: Sequence {
    func makeIterator() -> Iterator {
        return Iterator()
    }

    struct Iterator: IteratorProtocol {
        var formats = foundationDateFormats.makeIterator()

        mutating func next() -> DateFormatter? {
            guard let format = formats.next() else { return nil }
            let formatter = makeFormatter()
            formatter.dateFormat = format
            return formatter
        }

        /// Creates a `DateFormatter` and caches it in the current thread’s thread dictionary.
        func makeFormatter() -> DateFormatter {
            let key = "IMAP.protocol.dateFormatter" as NSString
            if let f = Thread.current.threadDictionary[key] as? DateFormatter {
                return f
            }
            // See also:
            // https://developer.apple.com/library/archive/qa/qa1480/_index.html
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(secondsFromGMT: 0)
            Thread.current.threadDictionary[key] = f
            return f
        }
    }
}

// From RFC 2822, section 3.3
// https://tools.ietf.org/html/rfc2822#section-3.3
//
// 3.3. Date and Time Specification
//
//    Date and time occur in several header fields.  This section specifies
//    the syntax for a full date and time specification.  Though folding
//    white space is permitted throughout the date-time specification, it
//    is RECOMMENDED that a single space be used in each place that FWS
//    appears (whether it is required or optional); some older
//    implementations may not interpret other occurrences of folding white
//    space correctly.
//
// date-time       =       [ day-of-week "," ] date FWS time [CFWS]
//
// day-of-week     =       ([FWS] day-name) / obs-day-of-week
//
// day-name        =       "Mon" / "Tue" / "Wed" / "Thu" /
//                         "Fri" / "Sat" / "Sun"
//
// date            =       day month year
//
// year            =       4*DIGIT / obs-year
//
// month           =       (FWS month-name FWS) / obs-month
//
// month-name      =       "Jan" / "Feb" / "Mar" / "Apr" /
//                         "May" / "Jun" / "Jul" / "Aug" /
//                         "Sep" / "Oct" / "Nov" / "Dec"
//
// day             =       ([FWS] 1*2DIGIT) / obs-day
//
// time            =       time-of-day FWS zone
//
// time-of-day     =       hour ":" minute [ ":" second ]
//
// hour            =       2DIGIT / obs-hour
//
// minute          =       2DIGIT / obs-minute
//
// second          =       2DIGIT / obs-second
//
// zone            =       (( "+" / "-" ) 4DIGIT) / obs-zone

private let foundationDateFormats: [String] = [
    // The order of these (as well as the uncommon ones) were determined empirically by
    // Julie Zelenski on 1999-11-29 by examining a 5000 message mailbox. She found about
    // 90% of the sample messages conforming to the three formats here. Her original comment
    // can be found in NSDateAdditions.m prior to July 2012. On 2012-7-27, Ian Anderson
    // retested with his 14,500 message Apple Inbox, code reviews mailbox, and iCloud
    // Inbox, and found 100% of his messages conformed to the IMAP or these formats.

    // date-time with the optional day-of-week and seconds
    // Note that in all the following format strings the year is specified with a single
    // y instead of 4. That's because yyyy will interpret "13" as 0013 instead of 2013.
    // While 2 digit dates are illegal, we're trying to be lenient here.
    "EEE',' d MMM y HH':'mm':'ss ZZZ",

    // date-time with the optional day-of-week and seconds, and obs-zone
    // This doesn't really work; obs-zone is the "specific non-location format" but only
    // for UTC and the United States. All other zones are covered by the military format,
    // but NSDateFormatter doesn't appear to support that.
    "EEE',' d MMM y HH':'mm':'ss zzz",

    // this one's just plain illegal, but Julie saw it in about 5% of her messages
    "EEE MMM d HH':'mm':'ss zzz y",

    // date-time without the optional day-of-week and with seconds
    "d MMM y HH':'mm':'ss ZZZ",

    // date-time without the optional day-of-week, and with seconds and obs-zone
    "d MMM y HH':'mm':'ss zzz",

    // date-time with the optional day-of-week and without seconds
    "EEE',' d MMM y HH':'mm ZZZ",

    // date-time with the optional day-of-week and obs-zone, and without seconds
    "EEE',' d MMM y HH':'mm zzz",

    // date-time without the optional day-of-week or seconds
    "d MMM y HH':'mm ZZZ",

    // date-time without the optional day-of-week or seconds, and with obs-zone
    "d MMM y HH':'mm zzz",

    // Illegal formats:

    "'\"'dd'-'MMM'-'y HH':'mm':'ss ZZZ'\"'",
    "EEE MMM d HH':'mm':'ss y",
    "y'-'MM'-'d HH':'mm':'ss ZZZ",
    "EEE',' d MMM y HH':'mm':'ss",
    "d MMM y HH':'mm':'ss",
    "MM'/'d HH':'mm a",
    "MM'/'d'/'y HH':'mm a",
    "MMM d',' y  HH':'mm':'ss a vvvv",
    "EEE',' MMM d y HH':'mm':'ss ZZZ",
    "EEE',' MMM d',' y HH':'mm zzz",
    "EEE MMM d',' y HH':'mm':'ss vvvv",
    "MMMM d',' y HH':'mm':'ss zzz",
    "EEE',' MMM d',' y 'at' HH':'mm a",
]

#if canImport(Darwin)
private let strptimeDateFormats: [String] = [
    // These are the same ones from above, with those using "zzz" removed.
    // "zzz" corresponds to time zone specifiers like "EST", but
    // these abbreviations are not unique, and as such strptime_l()
    // refuses to parse these. "EST" might be "Eastern Standard Time",
    // "Australian Eastern Standard Time", or "European Summer Time".

    " %a, %d %b %Y %H:%M:%S %z ",
    " %d %b %Y %H:%M:%S %z ",
    " %a, %d %b %Y %H:%M %z ",
    " %d %b %Y %H:%M %z ",
    " \"%d-%b-%Y %H:%M:%S %z\" ",
    " %a %b %d %H:%M:%S %Y ",
    " %Y-%m-%d %H:%M:%S %z ",
    " %a, %d %b %Y %H:%M:%S ",
    " %d %b %Y %H:%M:%S ",
    " %m/%d %H:%M %p ",
    " %m/%d/%Y %H:%M %p ",
    " %a, %b %d %Y %H:%M:%S %z ",
    " %a, %b %d, %Y at %H:%M %p ",
]
#endif
