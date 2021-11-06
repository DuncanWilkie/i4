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
func toSQL(_ date : Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
    formatter.timeZone = TimeZone(secondsFromGMT: 0) //SQLite does ISO-8601
    
    return formatter.string(from: date)
}

//inverse of ^
func fromSQL(_ string : String) -> Date {
    let formatter = DateFormatter()
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


//Extracts data points to be graphed from the database and computes the necessary autoranging parameters.
//Also very messily avoids rerunning the intensive initializer during ObservedObject updates via a
//boolean init parameter. Should refactor, probably won't--no control flow in view bodies complicates things.
class CollectionWindow {
    var startDate: Date
    var endDate: Date
    var density: Int //how many points to sample over
    var data: [(Date, Double)] = []
    var height: Double = 0
    var width: Double = 0
    var min: Double = 0
    var max: Double = 0
    
    init(startDate: Date, endDate: Date, density: Int, toUpdate: Bool) {
        self.startDate = startDate
        self.endDate = endDate
        self.density = density
        if toUpdate {
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
            var query: String = "SELECT AVG(DEPOSITION / EXPOSURE) AS AVG,  CASE "
            for (date, range) in partitions {
                query += "WHEN JULIANDAY(DATE) - JULIANDAY('\(toSQL(range.0))') >= 0 AND JULIANDAY('\(toSQL(range.1))') - JULIANDAY(DATE) >= 0 THEN '\(toSQL(date))' "
            }
            query += "END AS DATE_MID "
            
            query += """
                FROM MEASURMENT WHERE
                    JULIANDAY(DATE) - JULIANDAY('\(toSQL(startDate))') >= 0
                    AND JULIANDAY('\(toSQL(endDate))') - JULIANDAY(DATE) >= 0
                    AND DATE_MID IS NOT NULL
                GROUP BY
                    DATE_MID;
                """
            
            //executing query
            let dbQ = Scope.db.queue
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
            for i in result {
                let c: Double = i["AVG"] //did it this way to avoid typecast hell
                if c > max {
                    max = c
                }
                if c < min {
                    min = c
                }
            }
            self.max = max
            self.min = min
            self.height = Double(max - min)
            self.width = endDate.timeIntervalSince(startDate)
            
            //building data array of the correct format
            for i in result {
                self.data.append((i["DATE_MID"], i["AVG"]))
            }
        }
    }
}

//identical to above but draws from TEST instead. Should delete at some point; if we need this parallelism we ought to
//just make a db parameter in CollectionWindow
class TestWindow {
    var startDate: Date
    var endDate: Date
    var density: Int //how many points to sample over
    var data: [(Date, Double)] = []
    var height: Double = 0
    var width: Double = 0
    var min: Double = 0
    var max: Double = 0
    var avg: Double = 0
    
    init(startDate: Date, endDate: Date, density: Int, toUpdate: Bool) {
        self.startDate = startDate
        self.endDate = endDate
        self.density = density
        if toUpdate {
            
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
            var query: String = "SELECT AVG(DEPOSITION / EXPOSURE) AS AVG,  CASE "
            for (date, range) in partitions {
                query += "WHEN JULIANDAY(DATE) - JULIANDAY('\(toSQL(range.0))') >= 0 AND JULIANDAY('\(toSQL(range.1))') - JULIANDAY(DATE) >= 0 THEN '\(toSQL(date))' "
            }
            query += "END AS DATE_MID "
            
            query += """
                FROM TESTRECORD WHERE
                    JULIANDAY(DATE) - JULIANDAY('\(toSQL(startDate))') >= 0
                    AND JULIANDAY('\(toSQL(endDate))') - JULIANDAY(DATE) >= 0
                    AND DATE_MID IS NOT NULL
                GROUP BY
                    DATE_MID;
                """
            
            //executing query
            let dbQ = Scope.db.queue
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
            self.avg = sum / Double(density)
            self.max = max
            self.min = min
            self.height = Double(max - min)
            self.width = endDate.timeIntervalSince(startDate)
            
            //building data array of the correct format
            for i in result {
                self.data.append((i["DATE_MID"], i["AVG"]))
            }
        }
    }
}
