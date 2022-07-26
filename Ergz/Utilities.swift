//
//  Utilities.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 6/15/21.
//

import Foundation
import GRDB
import Combine
import SwiftUI


// for converting Swift date to SQLite time-value
func toSQL(_ date : Date, _ formatter: DateFormatter) -> String {
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    formatter.timeZone = TimeZone(secondsFromGMT: 0) //SQLite does ISO-8601
    
    return formatter.string(from: date)
}

//inverse of ^
func fromSQL(_ string : String, _ formatter: DateFormatter) -> Date {
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    formatter.timeZone = TimeZone(secondsFromGMT: 0) //SQLite does ISO-8601
    
    return formatter.date(from: string)!
}

//returns string representing date, but formatted in order to display only useful info for interpreting
//the date in the context of a date window, e.g. you don't need to see the year to interpret date values
//ranging over a few hours
func compressDate(_ toConvert: Date, _ startDate: Date, _ endDate: Date, _ dateFormatter: DateFormatter) -> String {
    dateFormatter.locale = Locale(identifier: "en_US")
    switch endDate.timeIntervalSince(startDate) {
    case 0..<3600:
        dateFormatter.setLocalizedDateFormatFromTemplate("hh:mm:ss")
    case 3600..<86400://hh:mm AM/PM
        dateFormatter.setLocalizedDateFormatFromTemplate("hh:mm")
    case 86400..<31536000:
        dateFormatter.setLocalizedDateFormatFromTemplate("hh:mm MMM dd")
    default:
        dateFormatter.setLocalizedDateFormatFromTemplate("hh:mm MMM dd YYYY")
    }
    return dateFormatter.string(from: toConvert)
}

// returns an SI-prefixed, units-included string representation of a floating-point value to a given precision.
func autoDoubleFormatter(value: Double, unit: String, width: Int) -> String {
    if String(value).count < width {
        return "\(value) \(unit)"
    }
    
    let prefixes = [-24: "y", -21: "z", -18: "a", -15: "f", -12: "p", -9: "n", -6: "µ", -3: "m", 0: "", 3: "k", 6: "M", 9: "G", 12: "T", 15: "P", 18: "E", 21: "Z", 24: "Y"]
    
    do {
        let powten = Int(log10(value))
        
        let pref_pow = powten - powten % 3
        guard let lett = prefixes[pref_pow] else { throw NSError() }
        return "\(String(value / pow(10, Double(pref_pow))).prefix(width)) \(lett)\(unit)"
    } catch {
        print("No satisfactory SI Double format found; returning raw double")
        return "\(String(value)) \(unit)"
    }
    
}

extension Data { //append data object to file; found on SO
    func append(url: URL) throws {
        if let fileHandle = FileHandle(forWritingAtPath: url.path) {
            defer {
                fileHandle.closeFile()
            }
            fileHandle.seekToEndOfFile()
            fileHandle.write(self)
        }
        else {
            try write(to: url, options: .atomic)
        }
    }
}

extension Data {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to:count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to:count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}


