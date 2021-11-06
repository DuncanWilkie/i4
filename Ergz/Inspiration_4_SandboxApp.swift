//
//  Inspiration_4_SandboxApp.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 5/14/21.
//

import SwiftUI
import GRDB

@main
struct Ergz: App {
    var body: some Scene {
        WindowGroup {
            ContentView().preferredColorScheme(/*@START_MENU_TOKEN@*/.dark/*@END_MENU_TOKEN@*/)
            
        }
    }
}

//Raw data is stored in the SQLite database FRAME of these records, which are used to periodically update the MEAS table with equivalent dose


struct Measurement: Codable, FetchableRecord, PersistableRecord { //used to write to DB in elegant way: try Measurment(...params...).insert(db)
    var date: Date
    var exposure: Double
    var deposition: Double
}

struct Testrecord: Codable, FetchableRecord, PersistableRecord {
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
        
        do {
            try dbQueue.write {  db in
                try db.create(table: "MEASUREMENT", ifNotExists: true) { t in
                    t.autoIncrementedPrimaryKey("ID")
                    t.column("DATE", .text).notNull()
                    t.column("EXPOSURE", .double).notNull()
                    t.column("DEPOSITION", .double).notNull()
                }
            }
            
            try dbQueue.write {  db in
                try db.drop(table: "TESTRECORD")
                try db.create(table: "TESTRECORD", ifNotExists: true) { t in
                    t.autoIncrementedPrimaryKey("ID")
                    t.column("DATE", .text).notNull()
                    t.column("EXPOSURE", .double).notNull()
                    t.column("DEPOSITION", .double).notNull()
                }
            }
            
        
                do {
                    let content = try String(contentsOfFile: Bundle.main.bundlePath + "/aggregated.csv")
                    let parsedCSV: [String] = content.components(
                        separatedBy: "\r\n"
                    )
                    
                    for i in parsedCSV.dropFirst().dropLast() {
                        let row: [String] = i.components(separatedBy: ",")
                        
                        try dbQueue.write { db in
                            try Testrecord(date: Date(timeIntervalSince1970: Double(row[1]) ?? 0),
                                       exposure: Double(row[2]) ?? 0,
                                       deposition: Double(row[3]) ?? 0).insert(db)
                        }
                        
                    }
                    
                    try dbQueue.read { db in
                        let min = Testrecord.select(min(Column("date")), as: String.self)
                        let max = Testrecord.select(max(Column("date")), as: String.self)
                        try testTimeBounds = (fromSQL(min.fetchOne(db)!), fromSQL(max.fetchOne(db)!))
                    }
                } catch {
                    print("TESTRECORD not generated")
                    print(error)
                }
            
        } catch {
            print(error)
        }
    }
    
    func write(_ row: Measurement) throws {
        var earliest: Date = timeBounds.0
        var latest: Date = timeBounds.1
        
        if row.date < timeBounds.0 {
            earliest = row.date
        }
        else if row.date > timeBounds.1 {
            latest = row.date
            
        }
        self.timeBounds = (earliest, latest)
        
        
            try queue.write {db in
                try row.insert(db)
            }
       
            
        
        
        
        self.timeBounds = (earliest, latest)
        
    }
    
}
