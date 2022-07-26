//
//  Environment.swift
//  Ergz
//
//  Created by Duncan Wilkie on 7/20/22.
//

import Foundation

// This is gross...it is solved by lazy initialization of view properties, so that I can initialize Detector() from the Store() and Config() initialized in the same object.
class Environment: ObservableObject {
    var config: Config
    var store: Store
    var detector: Detector
    var formatters: Formatters
    var iCloud: CloudStore
    init() {
        formatters =  Formatters()
        store = test ? TestStore(fm: formatters.fm) : Store(fm: formatters.fm)
        config = Config()
        detector = Detector(store: store, config: config)
        iCloud = CloudStore()
        
    }
}
