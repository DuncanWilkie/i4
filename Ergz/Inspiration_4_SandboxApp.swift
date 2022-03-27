//
//  Inspiration_4_SandboxApp.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 5/14/21.
//

import SwiftUI
import GRDB

// The way I have to manage global state in order to get proper performance out of SwiftUI illustrates the failures of OOP.
// In any sufficiently complex project, in order to get proper encapsulation and elegant dependency injection it becomes
// necessary to entirely divorce one's objects from the natural, object-like divisions between code, e.g the UsingSlider view.
// If I were to totally divorce the code in Detector from dependency on Store and Config, so it could be initialized as a @StateObject
// here, it would be wholly unrecognizable as a detector; there would either be an intolerable amount of duplicated code or one big object
// that does the job of all three current environment objects. It's a catch-22 between dependency injection, boilerplate, and separation
// of concerns.

// The OOPer will always argue this difficulty merely reflects insufficient cranial capacity occupied by their favorite buzzwords.
// It doesn't /have/ to be this hard; pure functional programming is perfectly natural once one grasps two or three inviolable concepts
// and provides far better guarantees and maintainability. You can just /start writing/ a functional program without any planning
// and you won't need to undo half a dozen major design decisions once your project has a slightly unanticipated inter-module dependencies.

// I attribute this to object-oriented code being /non-commutative;/ one can't simply use the functionaliy one wrote in one place
// arbitrarily in any other part of the code, and so when the same problem pops up in a couple unforseen places it requires a lot
// of work and boilerplate to solve it without M-w, C-y.

// That being said, SwiftUI is by far the best object framework I've had the pleasure of using.
// Writing views is a joy. Getting the data to them is a nightmare.

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
