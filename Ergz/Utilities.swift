//
//  Utilities.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 6/15/21.
//

import Foundation
import GRDB
import Combine


// for converting Swift date to SQLite time-value
func toSQL(_ date : Date, _ formatter: DateFormatter) -> String {
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
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
func autoFormatter(_ toConvert: Date, _ startDate: Date, _ endDate: Date, _ dateFormatter: DateFormatter) -> String {
    dateFormatter.locale = Locale(identifier: "en_US")
    switch endDate.timeIntervalSince(startDate) {
    case 0..<3600:
        dateFormatter.setLocalizedDateFormatFromTemplate("hh:mm:ss")
    case 3600..<86400://hh:mm AM/PM
        dateFormatter.setLocalizedDateFormatFromTemplate("hh:mm")
    default:
        dateFormatter.setLocalizedDateFormatFromTemplate("hh:mm MMM dd")
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

struct PointReport {
    var points: [(Date, Double)]
    var max: Double
    var min: Double
    var height: Double
    var width: Double
}

func getPoints(store: Store, startDate: Date, endDate: Date, density: Int) -> PointReport {    
    //some useful constants
    let length = endDate.timeIntervalSince(startDate) //in seconds
    let delta = length / Double(density)
    
    //creating list of partition information to be iterated over in query preparation
    var partitions: [(Date, (Date, Date))] = [] //(center, (start, end))
    for i in 1...density {
        let center = startDate + (Double(i) + 0.5) * delta
        let begin = startDate + Double(i) * delta
        let end = startDate + Double(i + 1) * delta
        
        partitions.append((center, (begin, end)))
    }
    
    
    
    //query preparation
    var query: String = "SELECT AVG(DOSE / EXPOSURE) AS AVG,  CASE "
    for (date, range) in partitions {
        query += "WHEN JULIANDAY(DATE) - JULIANDAY('\(toSQL(range.0, store.fm))') >= 0 AND JULIANDAY('\(toSQL(range.1, store.fm))') - JULIANDAY(DATE) >= 0 THEN '\(toSQL(date, store.fm))' "
    }
    query += "END AS DATE_MID "
    
    query += """
            FROM MEASUREMENT WHERE
                JULIANDAY(DATE) - JULIANDAY('\(toSQL(startDate, store.fm))') >= 0
                AND JULIANDAY('\(toSQL(endDate, store.fm))') - JULIANDAY(DATE) >= 0
                AND DATE_MID IS NOT NULL
            GROUP BY
                DATE_MID;
            """
    
    //executing query
    let dbQ = store.queue
    var result: [Row] = []
    do {
        result = try dbQ.read { db in
            try Row.fetchAll(db, sql:query) //can't be Measurement
        }
        
    } catch {
        print(error)
    }
    //setting parameters needed for autoranging
    var max: Double = 0
    var min: Double = 1e40
    var sum: Double = 0
    for i in result {
        let c: Double = i["AVG"] //did it this way to avoid typecast hell
        
        sum += c
        if c > max {
            max = c
        }
        if c < min {
            min = c
        }
    }
    
    
    var points: [(Date, Double)] = []
    //building data array of the correct format
    for i in result {
        points.append((i["DATE_MID"], i["AVG"]))
    }
    
    return PointReport(points: points, max: max, min: min, height: max - min, width: length)
}
