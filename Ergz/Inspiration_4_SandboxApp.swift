//
//  Inspiration_4_SandboxApp.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 5/14/21.
//

import SwiftUI
import GRDB

@main
struct Inspiration_4_SandboxApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().preferredColorScheme(/*@START_MENU_TOKEN@*/.dark/*@END_MENU_TOKEN@*/)
            
        }
    }
}

//Raw data is stored in the SQLite database FRAME of these records, which are used to periodically update the MEAS table with equivalent dose

struct Frame: Codable, FetchableRecord, PersistableRecord {
    var date: Date
    var exposure: Double
    var image: [[Double]] //256x256 array of pixels with deposition values
}

struct Measurement: Codable, FetchableRecord, PersistableRecord { //used to write to DB in elegant way: try Measurment(...params...).insert(db)
    var date: Date
    var exposure: Double
    var deposition: Double
}

struct TestRecord: Codable, FetchableRecord, PersistableRecord {
    var date: Date
    var exposure: Double
    var deposition: Double
}

class Scope: ObservableObject { //dumping ground for global state because Apple is EVIL and HATES PROGRAMMERS
    static var db = Scope()
    var queue: DatabaseQueue
    @Published var timeBounds: (Date, Date) = (Date(), Date(timeIntervalSinceReferenceDate: 0))
    var testTimeBounds: (Date, Date) = (Date(), Date(timeIntervalSinceReferenceDate: 0))
    var path: String
    var nextRaw: Int = 0
    var icloudURL: URL?
    private init() {
        
       
        if let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            let tryURL = containerURL.appendingPathComponent("Documents")
            do {
                if (FileManager.default.fileExists(atPath: tryURL.path, isDirectory: nil) == false) {
                    try FileManager.default.createDirectory(at: tryURL, withIntermediateDirectories: true, attributes: nil)
                }
                icloudURL = tryURL
            } catch {
                print("ERROR: Cannot create /Documents on iCloud")
            }
        } else {
            print("ERROR: Cannot get ubiquity container")
        }
        
        var dbQueue: DatabaseQueue
        do {
            let appSupportDir = try FileManager.default.url(for: .applicationSupportDirectory,
                                                             in: .userDomainMask, appropriateFor: nil, create: true)
            let filePath = appSupportDir.path + "/database.sqlite"
            self.path = appSupportDir.path
            dbQueue = try DatabaseQueue(path: filePath)
        } catch {
            print(error)
            dbQueue = DatabaseQueue()
            self.path = ""
        }
        
        self.queue = dbQueue
        
        do { //remove in production
            try dbQueue.write {  db in
                try db.create(table: "TESTRECORD", ifNotExists: true) { t in
                    t.autoIncrementedPrimaryKey("ID")
                    t.column("DATE", .text).notNull()
                    t.column("EXPOSURE", .double).notNull()
                    t.column("DEPOSITION", .double).notNull()
                }
            }
        } catch {
            print(error)
        }
        
        do {
            try dbQueue.write {  db in
                try db.create(table: "FRAME", ifNotExists: true) { t in
                    t.autoIncrementedPrimaryKey("ID")
                    t.column("DATE", .text).notNull()
                    t.column("FRAME", .blob).notNull()
                }
            }
        } catch {
            print(error)
        }
        
        //Reading in test data from CSV in project; remove in production
        var testData: [TestRecord] = []
        
        let filepath = Bundle.main.path(forResource: "aggregated", ofType: "csv")!
        var data = ""
        do {
            data = try String(contentsOfFile: filepath)
        } catch {
            print(error)
        }
        
        var rows = data.components(separatedBy: "\r\n")
        
        rows.removeFirst()
        
        for row in rows {
            let columns = row.components(separatedBy: ",")
            if columns[0] != "" {
                testData.append(TestRecord(date: Date(timeIntervalSince1970: Double(columns[1]) ?? 0.0),
                                           exposure: Double(columns[2]) ?? 0.0,
                                           deposition: Double(columns[3]) ?? 0.0))
            }
        }
        
        for row in testData {
            do {
                try dbQueue.write { db in
                    try row.insert(db)
                }
            } catch {
                print(error)
            }
        }
        
        var result: [Row] = []
        do {
            result = try dbQueue.read { db in
               try Row.fetchAll(db, sql: "SELECT MIN(JULIANDAY(DATE)) AS MIN, MAX(JULIANDAY(DATE)) AS MAX FROM TESTRECORD")
            }
        } catch {
            print(error)
        }
        let min = Date(julianDay: result[0]["MIN"])!
        let max = Date(julianDay: result[0]["MAX"])!
        self.testTimeBounds = (min, max)
    }
    
    func write(_ row: Measurement) {
        var earliest: Date = timeBounds.0
        var latest: Date = timeBounds.1
        
        if row.date < timeBounds.0 {
            earliest = row.date
        }
        else if row.date > timeBounds.1 {
            latest = row.date
            
        }
        self.timeBounds = (earliest, latest)

        
        try! queue.write {db in
            try row.insert(db)
        }
        
        
        self.timeBounds = (earliest, latest)
        
    }
    
    func write(_ row: Frame) {
        try! queue.write {db in
            try row.insert(db)
        }
    }
}
