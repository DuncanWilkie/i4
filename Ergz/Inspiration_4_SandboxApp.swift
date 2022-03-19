//
//  Inspiration_4_SandboxApp.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 5/14/21.
//

import SwiftUI
import GRDB

// TODO: Wholescale app restructure; requires major rethinking of how all global state is managed, as passing data between global objects is impossible if the benefits of the new structure are to be realized. 
@main
struct Ergz: App {
    @StateObject var config: Config = Config()
    @StateObject var store: Store = Store()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(config)
                .environmentObject(store)
                .environmentObject(Detector(store: store, config: config))
                .environmentObject(DoubleSlider(store.testTimeBounds))
                .preferredColorScheme(/*@START_MENU_TOKEN@*/.dark/*@END_MENU_TOKEN@*/)
            
        }
    }
}


struct FrameRecord: Codable, FetchableRecord, PersistableRecord {
    var date: Date
    var detector: String
    var frame: Frame
    
    func csv() -> (String, String) {
        let metadata = "\(self.date);\(self.detector)\n"
        var contents = ",x,y,tot,toa,ftoa\n"
        for (coords, value) in frame {
            contents += "\(coords.x),\(coords.y),\(value.tot),\(value.toa),\(value.ftoa)\n"
        }
        
        return (metadata, contents)
    }
}

struct Measurement: Codable, FetchableRecord, PersistableRecord { //used to write to DB in elegant way: try Measurment(...params...).insert(db)
    var date: Date
    var exposure: Double
    var deposition: Double
    var dose: Double
}

struct Testrecord: Codable, FetchableRecord, PersistableRecord {
    var date: Date
    var exposure: Double
    var deposition: Double
}


