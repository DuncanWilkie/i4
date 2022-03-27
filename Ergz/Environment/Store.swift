//
//  Environment.swift
//  Ergz
//
//  Created by Duncan Wilkie on 3/17/22.
//

import Foundation
import GRDB

class Store: ObservableObject { // Environment object for managing databases and remote syncing information
    var queue: DatabaseQueue
    @Published var timeBounds: (Date, Date) = (Date(), Date(timeIntervalSinceReferenceDate: 0))
    // var testTimeBounds: (Date, Date) = (Date(), Date(timeIntervalSinceReferenceDate: 0))
    var url: URL
    // var nextRaw: Int = 0
    var icloudURL: URL?
    var fm = DateFormatter()
    var hasData: Bool = false
    init() {
        
        fm.locale = Locale(identifier: "en_US_POSIX")
        fm.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        fm.timeZone = TimeZone(secondsFromGMT: 0)
        
        
        if let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            let tryURL = containerURL.appendingPathComponent("Documents")
            do {
                if (!FileManager.default.fileExists(atPath: tryURL.path, isDirectory: nil)) {
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
            self.url = appSupportDir
            dbQueue = try DatabaseQueue(path: filePath)
        } catch {
            print(error)
            dbQueue = DatabaseQueue()
            self.url = URL(fileURLWithPath: "")
        }
        
        self.queue = dbQueue
        
        do {
            try dbQueue.write {  db in
                try db.create(table: "MEASUREMENT", ifNotExists: true) { t in
                    t.autoIncrementedPrimaryKey("ID")
                    t.column("DATE", .text).notNull()
                    t.column("EXPOSURE", .double).notNull()
                    t.column("DEPOSITION", .double).notNull()
                    t.column("DOSE", .double).notNull()
                }
            }
            
            try dbQueue.write {  db in
                try db.create(table: "FRAMERECORD", ifNotExists: true) { t in
                    t.autoIncrementedPrimaryKey("ID")
                    t.column("DATE", .text).notNull()
                    t.column("DETECTOR", .double).notNull()
                    t.column("FRAME", .blob).notNull()
                }
            }
            
           
            do {
                try dbQueue.read { db in
                    hasData = try Measurement.fetchCount(db) > 0
                }
            } catch {
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
        
        
        try queue.write { db in
            try row.insert(db)
        }
        
        self.timeBounds = (earliest, latest)
        
        hasData = true
    }
    
    func write(_ row: FrameRecord) throws {
        try queue.write { db in
            try row.insert(db)
        }
        hasData = true
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
        
        hasData = false
    }
}

