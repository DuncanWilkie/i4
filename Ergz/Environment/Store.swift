//
//  Environment.swift
//  Ergz
//
//  Created by Duncan Wilkie on 3/17/22.
//

import Foundation
import GRDB

struct PointReport {
    var stats: [(Date, Double, Double, Double, Double, Double)]
    var max: Double
    var min: Double
    var height: Double
    var width: Double
    var greatestMedian: Double
}

class TestStore: Store { // Overwrites the MEASUREMENT database with one generated from a csv of actual measurements so we can test the UI
    override init(fm: DateFormatter) {
        super.init(fm: fm)
        do {
            super.dataCount = 1
            try super.queue.write {  db in
                try db.drop(table: "MEASUREMENT")
                try db.create(table: "MEASUREMENT") { t in
                    t.autoIncrementedPrimaryKey("ID")
                    t.column("DATE", .text).notNull()
                    t.column("EXPOSURE", .double).notNull()
                    t.column("DEPOSITION", .double).notNull()
                    t.column("DOSE", .double).notNull()
                }
            }
            
            let content = try String(contentsOfFile: Bundle.main.bundlePath + "/aggregated.csv")
            let parsedCSV: [String] = content.components(separatedBy: "\r\n")
            
            for i in parsedCSV.dropFirst().dropLast() {
                var row: [String] = i.components(separatedBy: ",")
                
                let volume = 2 * 0.005 // cm^3
                let density = 2.3212 // g/cm^3
                let mass = volume * density // g
                
                let dose: String = String(Double(row.last!)! / (mass * 6.24e12))
                row.append(dose)
                
                
                try super.queue.write { db in
                    try Measurement(date: Date(timeIntervalSince1970: Double(row[1]) ?? 0),
                                    exposure: Double(row[2]) ?? 0,
                                    deposition: (Double(row[3]) ?? 0) * 1000,
                                    dose: Double(row[4]) ?? 0).insert(db)
                }
                
            }
            
            try super.queue.read { db in
                let min = Measurement.select(min(Column("date")), as: String.self)
                let max = Measurement.select(max(Column("date")), as: String.self)
                try super.timeBounds = (fromSQL(min.fetchOne(db)!, fm), fromSQL(max.fetchOne(db)!, fm))
            }
        } catch {
            print("Test MEASUREMENT not generated")
            print(error)
        }
    }
}


class Store: ObservableObject { // Environment object for managing databases and remote syncing information
    var fm: DateFormatter
    var queue: DatabaseQueue
    @Published var timeBounds: (Date, Date) = (Date(), Date(timeIntervalSinceReferenceDate: 0))
    var ourURL: URL
    var logfile: URL {
        ourURL.appendingPathComponent("log.txt")
    }
    
    @Published var dataCount: Int = 0
    init(fm: DateFormatter) {
        self.fm = fm
        var dbQueue: DatabaseQueue
        do {
            let appSupportDir = try FileManager.default.url(for: .applicationSupportDirectory,
                                                            in: .userDomainMask, appropriateFor: nil, create: true)
            let filePath = appSupportDir.path + "/database.sqlite"
            self.ourURL = appSupportDir
            dbQueue = try DatabaseQueue(path: filePath)
        } catch {
            print(error)
            dbQueue = DatabaseQueue()
            self.ourURL = URL(fileURLWithPath: "")
        }
        
        self.queue = dbQueue
        
        do {
            try queue.write {  db in
                try db.create(table: "MEASUREMENT", ifNotExists: true) { t in
                    t.autoIncrementedPrimaryKey("ID")
                    t.column("DATE", .text).notNull()
                    t.column("EXPOSURE", .double).notNull()
                    t.column("DEPOSITION", .double).notNull()
                    t.column("DOSE", .double).notNull()
                }
            }
            
            try queue.write {  db in
                try db.create(table: "FRAMERECORD", ifNotExists: true) { t in
                    t.autoIncrementedPrimaryKey("ID")
                    t.column("DATE", .text).notNull()
                    t.column("DETECTOR", .double).notNull()
                    t.column("EXPOSURE", .double).notNull()
                    t.column("FRAME", .blob).notNull()
                }
            }
            try queue.read { db in
                dataCount = try Measurement.fetchCount(db)
                
            }
        } catch {
            print(error)
        }
    }
    
    func write(_ row: Measurement) throws {
        var earliest: Date = timeBounds.0
        var latest: Date = timeBounds.1
        
        if row.date < earliest {
            earliest = row.date
        }
        else if row.date > latest {
            latest = row.date
        }
        
        
        try queue.write { db in
            try row.insert(db)
        }
        
        self.timeBounds = (earliest, latest)
        
        dataCount += 1
        print(dataCount)
    }
    
    func write(_ row: FrameRecord) throws {
        try queue.write { db in
            try row.insert(db)
        }
    }
    
    func clear() {
        do {
            try queue.write { db in
                try Measurement.deleteAll(db)
                try FrameRecord.deleteAll(db)
            }
            
            timeBounds = (Date(), Date(timeIntervalSinceReferenceDate: 0))
        } catch {
            print(error)
        }
        
        dataCount = 0
    }
    
    func stats(units: String, conversion: String, startDate: Date, endDate: Date) -> (Double, Double, Double, Double) {

        
        var query: String
        if units == "eV" {
            query = "WITH R AS (SELECT DEPOSITION AS DEPOSITION, DEPOSITION / EXPOSURE AS RATE FROM MEASUREMENT WHERE JULIANDAY(DATE) - JULIANDAY('\(toSQL(startDate, fm))') >= 0 AND JULIANDAY(DATE) - JULIANDAY('\(toSQL(endDate, fm))') <= 0), A AS (SELECT AVG(RATE) AS AVG FROM R) SELECT AVG AS AVG, SUM(RATE) AS TOTAL, MAX(RATE) AS MAX, SUM((RATE-AVG) * (RATE-AVG)) / (COUNT(DEPOSITION) - 1) AS VARIANCE FROM R, A"

        } else if units == "Gy" {
            query = "WITH R AS (SELECT DOSE AS DOSE, DOSE / EXPOSURE AS RATE FROM MEASUREMENT WHERE JULIANDAY(DATE) - JULIANDAY('\(toSQL(startDate, fm))') >= 0 AND JULIANDAY(DATE) - JULIANDAY('\(toSQL(endDate, fm))') <= 0), A AS (SELECT AVG(RATE) AS AVG FROM R) SELECT AVG AS AVG, SUM(RATE) AS TOTAL, MAX(RATE) AS MAX, SUM((RATE-AVG) * (RATE-AVG)) / (COUNT(DOSE) - 1) AS VARIANCE FROM R, A"
        } else {
            query = "WITH R AS (SELECT \(conversion) * DOSE AS EQV, \(conversion) * DOSE / EXPOSURE AS RATE FROM MEASUREMENT WHERE JULIANDAY(DATE) - JULIANDAY('\(toSQL(startDate, fm))') >= 0 AND JULIANDAY(DATE) - JULIANDAY('\(toSQL(endDate, fm))') <= 0), A AS (SELECT AVG(RATE) AS AVG FROM R) SELECT AVG AS AVG, SUM(RATE) AS TOTAL, MAX(RATE) AS MAX, SUM((RATE-AVG) * (RATE-AVG)) / (COUNT(EQV) - 1) AS VARIANCE FROM R, A"
        }
        var res: Row?
        do {
            res = try queue.read {db in
                try Row.fetchOne(db, sql: query)
            }
        } catch {
            print(error)
        }
        
        if let i = res {
            let avdeprt: Double = i["AVG"] ?? 0.0
            let totdep: Double = i["TOTAL"] ?? 0.0
            let totdose: Double = i["MAX"] ?? 0.0
            let pkdose: Double = i["VARIANCE"] ?? 0.0
            return (avdeprt, totdep, totdose, pkdose)
            
        } else {
            print("Error in stats: query returned nil")
            return (0, 0, 0, 0)
        }
    }
    
    func points(units: String, conversion: String, startDate: Date, endDate: Date, count: Int) -> PointReport {
        //some useful constants
        let length = endDate.timeIntervalSince(startDate) //in seconds
        let delta = length / Double(count)
        
        //creating list of partition information to be iterated over in query preparation
        var partitions: [(Date, (Date, Date))] = [] //(center, (start, end))
        for i in 0..<count {
            let center = startDate + (Double(i) + 0.5) * delta
            let begin = startDate + Double(i) * delta
            let end = startDate + Double(i + 1) * delta
            
            partitions.append((center, (begin, end)))
        }
        
        
        
        //query preparation
        let col = (units == "eV" ? "DEPOSITION" : (units == "Gy" ? "DOSE" : "\(conversion)*DOSE"))
        var query: String = "WITH GRP AS (SELECT \(col) / EXPOSURE AS RATE, CASE "
        for (mid, range) in partitions {
            query += "WHEN JULIANDAY(DATE) - JULIANDAY('\(toSQL(range.0, fm))') >= 0 AND JULIANDAY('\(toSQL(range.1, fm))') - JULIANDAY(DATE) >= 0 THEN '\(toSQL(mid, fm))' "
        }
        query += """
                END AS DATE_MID
                FROM MEASUREMENT WHERE
                    JULIANDAY(DATE) - JULIANDAY('\(toSQL(startDate, fm))') >= 0
                    AND JULIANDAY('\(toSQL(endDate, fm))') - JULIANDAY(DATE) >= 0),
                PT AS (SELECT DATE_MID, RATE, NTILE(4) OVER (PARTITION BY DATE_MID ORDER BY RATE) AS Q FROM GRP)
                SELECT
                    DATE_MID,
                    MIN(RATE) as MIN,
                    MAX(RATE) AS MAX,
                    MAX(CASE WHEN Q = 1 THEN RATE END) AS Q1,
                    COALESCE(MAX(CASE WHEN Q = 2 THEN RATE END), MAX(RATE)) AS MEDIAN,
                    COALESCE(MAX(CASE WHEN Q = 3 THEN RATE END), MAX(RATE)) AS Q3
                FROM PT
                GROUP BY DATE_MID
                ORDER BY DATE_MID
                """
        
        
        
        
        //executing query
        var result: [Row] = []
        do {
            result = try queue.read { db in
                try Row.fetchAll(db, sql:query) //can't be Measurement
            }
        } catch {
            print(error)
        }
        //setting parameters needed for autoranging
        
        
        var stats: [(Date, Double, Double, Double, Double, Double)] = []
        //building data array of the correct format
        for pt in partitions {
            var matched = false
            for i in result {
                let new: String = i["DATE_MID"]
                if toSQL(pt.0, fm) == new {
                    stats.append((fromSQL(new, fm), i["MIN"], i["Q1"], i["MEDIAN"], i["Q3"], i["MAX"]))
                    matched = true
                    break
                }
            }
            
            if !matched {
                stats.append((pt.0, 0, 0, 0, 0, 0))
            }
        }
        
        var max: Double = 0
        var min: Double = 1e40
        var max_med: Double = 0
        for i in stats {
            let e: Double = i.3
            let a: Double = i.5 
            let i: Double = i.1
            if a > max {
                max = a
            }
            if i < min {
                min = i
            }
            if e > max_med {
                max_med = e
            }
        }
        
        return PointReport(stats: stats, max: max, min: min, height: max - min, width: length, greatestMedian: max_med)
    }
    
}

