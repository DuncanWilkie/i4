//
//  Config.swift
//  Ergz
//
//  Created by Duncan Wilkie on 11/9/21.
//

import Foundation


struct PixelCalibration: Hashable {
    var a: Double
    var b: Double
    var c: Double
    var t: Double
}

typealias FrameCalibration = [PixelCoords : PixelCalibration]

struct DetectorData: Identifiable, Hashable {
    var id: String
    var cal: FrameCalibration
}

class Config: ObservableObject { // Environment object for managing global user configuration 
    var base_url: URL
    @Published var detectors: [DetectorData] = []
    @Published var selected: String = ""
    init() {
        // read contents of directories that store detector metadata, and build a list of corresponding structs
        let appSupportDir = try! FileManager.default.url(for: .applicationSupportDirectory,
                                                         in: .userDomainMask, appropriateFor: nil, create: true)
        base_url = appSupportDir.appendingPathComponent("/detectors/")

        updateDetectors()
        
    }
    
    
    func updateDetectors() {
        do {
            if !FileManager.default.fileExists(atPath: base_url.path) {
                try FileManager.default.createDirectory(at: base_url, withIntermediateDirectories: false, attributes: nil)
            }
            
            let directoryContents = try FileManager.default.contentsOfDirectory(at: base_url,
                                                                                includingPropertiesForKeys: nil)
            
            for url in directoryContents {
                let id = url.lastPathComponent
                
                let paths = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil).map{$0.path}
                
                let apath = paths.filter{$0.contains("calib_a")}
                let bpath = paths.filter{$0.contains("calib_b")}
                let cpath = paths.filter{$0.contains("calib_c")}
                let tpath = paths.filter{$0.contains("calib_t")}
                
                assert(apath.count == 1 && bpath.count == 1 && cpath.count == 1 && tpath.count == 1)
                
                let afile = try String(contentsOfFile: apath[0]).components(separatedBy: CharacterSet(charactersIn: " \n"))
                let bfile = try String(contentsOfFile: bpath[0]).components(separatedBy: CharacterSet(charactersIn: " \n"))
                let cfile = try String(contentsOfFile: cpath[0]).components(separatedBy: CharacterSet(charactersIn: " \n"))
                let tfile = try String(contentsOfFile: tpath[0]).components(separatedBy: CharacterSet(charactersIn: " \n"))
                
                var calibration: FrameCalibration = [:]
                for iy in 1...256 { // TODO: check the axes on the calibration file match what I've assumed
                    for ix in 1...256 {
                        let pixcal = PixelCalibration(a: Double(afile[256*(iy - 1) + ix - 1])!,
                                                      b: Double(bfile[256*(iy - 1) + ix - 1])!,
                                                      c: Double(cfile[256*(iy - 1) + ix - 1])!,
                                                      t: Double(tfile[256*(iy - 1) + ix - 1])!)
                        
                        calibration[PixelCoords(x: ix, y: iy)] = pixcal
                    }
                }
                
                detectors.removeAll { $0.id == id }
                detectors.append(DetectorData(id: id, cal: calibration))

            }
        } catch {
            print(error.localizedDescription)
        }
    }

    
    func saveDetector(id: String, afile: URL, bfile: URL, cfile: URL, tfile: URL) {
        do {
            let pwd = base_url.appendingPathComponent(id)
            if FileManager.default.fileExists(atPath: pwd.path) {
                try FileManager.default.removeItem(at: pwd)
            }
            
            try FileManager.default.createDirectory(at: pwd,
                                                    withIntermediateDirectories: false,
                                                    attributes: nil)
            
            try FileManager.default.copyItem(at: afile, to: pwd.appendingPathComponent(afile.lastPathComponent))
            try FileManager.default.copyItem(at: bfile, to: pwd.appendingPathComponent(bfile.lastPathComponent))
            try FileManager.default.copyItem(at: cfile, to: pwd.appendingPathComponent(cfile.lastPathComponent))
            try FileManager.default.copyItem(at: tfile, to: pwd.appendingPathComponent(tfile.lastPathComponent))
            
            updateDetectors()
            print(detectors.count)
            print(detectors[0].id)
        } catch {
            print(error.localizedDescription)
        }
    }
}

