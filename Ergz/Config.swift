//
//  Config.swift
//  Ergz
//
//  Created by Duncan Wilkie on 11/9/21.
//

import Foundation

struct DetectorMetadata: Identifiable { // used for customizing detector parameters
    var id: String
    var calibration: [[String : Double]]
    init (_ id: String, _ calibration: [[String : Double]]) {
        self.id = id
        self.calibration = calibration
    }
}

struct Saved { // Config singleton. Makes me sad, like always.
    static var ins = Saved()
    var manifest: String
    var detectDir: String
    var detectors: [DetectorMetadata] = []
    private init() {
        // read contents of directories that store detector metadata, and build a list of corresponding structs
        do {
            let appSupportDir = try FileManager.default.url(for: .applicationSupportDirectory,
                                                               in: .userDomainMask, appropriateFor: nil, create: true).path
            detectDir = appSupportDir + "/detectors/"
            manifest = detectDir + "manifest.txt"
            let contents = try String(contentsOfFile: manifest).components(separatedBy: "\n")
            for id in contents {
                let cal = try parseCalibrationCSV(detectDir + id + ".csv")
                detectors.append(DetectorMetadata(id, cal))
            }
        } catch {
            print(error.localizedDescription)
            manifest = ""
            detectDir = ""
        }
    }
    
    func saveDetector(_ id: String, _ cal: [[String : Double]]) {
        do {
            // save ID to manifest
            if FileManager.default.fileExists(atPath: manifest) {
                if let fileHandle = FileHandle(forWritingAtPath: manifest) {
                    fileHandle.seekToEndOfFile()
                    try fileHandle.write(contentsOf: (id + "\n").data(using: .utf8)!)
                    fileHandle.closeFile()
                }
            } else {
                try (id + "\n").data(using: .utf8)!.write(to: URL(fileURLWithPath: manifest), options: .atomicWrite)
            }
            
            // save calibration to file \(id).csv
            let keys = cal[0].keys
            for i in cal {
                
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    
}
