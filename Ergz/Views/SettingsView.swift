//
//  SettingsView.swift
//  Ergz
//
//  Created by Duncan Wilkie on 11/6/21.
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers
import ZIPFoundation

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var detector: Detector
    @EnvironmentObject var config: Config
    
    //    var archive_url = URL(fileURLWithPath: Store.db.path)
    @State var archive_name: String = ""
    @State var importing: Bool = false
    @State var exporting: Bool = false
    @State var exportRaw: Bool = false
    @State var exportAg: Bool = false
    @State var selectedStart: Date = Date()
    @State var selectedEnd: Date = Date()
    /*  @State var selected: String = "" { mark as published in config
     willSet {
     config.selected = newValue
     }
     } */
    var body: some View {
        let archive_url = store.url.appendingPathComponent("archive_staging")
        NavigationView {
            Form {
                Section(header: Text("Detectors")) {
                    Picker("Active Detector", selection: $config.selected) {
                        ForEach(config.detectors, id: \.self.id) { detector in
                            Text(detector.id)
                        }
                    }
                    
                    Button(action: { importing.toggle() }, label: {
                        Text("Import Calibration")
                    })
                }
                
                Section(header: Text("Export")) {
                    Button(action: { exportRaw.toggle() }, label: {
                        Text("Raw Frames")
                    }).sheet(isPresented: $exportRaw, onDismiss: {
                        // SQL select statement of FrameRecord database from $selectedStart and $selectedEnd; create .zip, use fileExporter so user can save it wherever
                        if archive_name == "" {
                            archive_name = "export.zip"
                        }
                        do {
                            let result: [FrameRecord] = try store.queue.read { db in
                                try FrameRecord.fetchAll(db, sql:"SELECT * FROM FRAMERECORD WHERE DATE >= JULIANDAY('\(toSQL(selectedStart))') AND DATE <= JULIANDAY('\(toSQL(selectedEnd))')")
                            }
                            
                            if FileManager.default.fileExists(atPath: archive_url.appendingPathComponent(archive_name).path) {
                                try FileManager.default.removeItem(at: archive_url.appendingPathComponent(archive_name))
                            }
                            
                            guard let archive = Archive(url: archive_url.appendingPathComponent(archive_name), accessMode: .create) else {
                                print("archive creation failed at \(#line) in \(#file)")
                                return
                            }
                            
                            for frame in result {
                                let text = frame.csv()
                                let data = text.1.data(using: .utf8)!
                                
                                try? archive.addEntry(with: text.0, type: .file, uncompressedSize: Int64(data.count),
                                                      provider: { (position, size) -> Data in
                                    return data
                                })
                            }
                        } catch {
                            print(error)
                        }
                        
                        exporting = true
                        
                    }) {
                        Form {
                            DatePicker("Start of Exported Interval", selection: $selectedStart, displayedComponents: [.date, .hourAndMinute])
                            DatePicker("End of Exported Interval", selection: $selectedEnd, displayedComponents: [.date, .hourAndMinute])
                            TextField("File Name", text: $archive_name)
                            Button(action: { exportRaw.toggle() }, label: {
                                Text("Done")
                            })
                        }
                    }
                    Button(action: { exportAg.toggle() }, label: {
                        Text("Aggregated Statistics")
                    }).sheet(isPresented: $exportAg, onDismiss: {
                        do {
                            if archive_name == "" {
                                archive_name = "export.zip"
                            }
                            
                            let result: [Measurement] = try store.queue.read { db in
                                try Measurement.fetchAll(db, sql:"SELECT * FROM MEASUREMENT WHERE DATE >= JULIANDAY('\(toSQL(selectedStart))') AND DATE <= JULIANDAY('\(toSQL(selectedEnd))')")
                            }
                            
                            if FileManager.default.fileExists(atPath: archive_url.appendingPathComponent(archive_name).path) {
                                try FileManager.default.removeItem(at: archive_url.appendingPathComponent(archive_name))
                            }
                            
                            guard let archive = Archive(url: archive_url.appendingPathComponent(archive_name), accessMode: .create) else {
                                print("archive creation failed at \(#line) in \(#file)")
                                return
                            }
                            
                            var content = ",Date,Exposure (s), Deposition (keV), Absorbed Dose (Gy, in water)\n"
                            for meas in result {
                                content += "\(meas.date),\(meas.exposure),\(meas.deposition),\(meas.dose)\n"
                                
                            }
                            
                            let data = content.data(using: .utf8)!
                            
                            try? archive.addEntry(with: "\(selectedStart);\(selectedEnd)", type: .file, uncompressedSize: Int64(data.count),
                                                  provider: { (position, size) -> Data in
                                return data
                            })
                        } catch {
                            print(error)
                        }
                        
                        exporting = true
                    }) {
                        Form {
                            DatePicker("Start of Exported Interval", selection: $selectedStart, displayedComponents: [.date, .hourAndMinute])
                            DatePicker("End of Exported Interval", selection: $selectedEnd, displayedComponents: [.date, .hourAndMinute])
                            TextField("File Name", text: $archive_name)
                            Button(action: { exportAg.toggle() }, label: {
                                Text("Done")
                            })
                        }
                    }
                }
                
                Section(header: Text("Sync")) {
                    Text("iCloud Toggle")
                    Text("Rsync?")
                    Text("git?")
                }
                
            }.navigationTitle("Settings")
            .padding()
            .fileMover(isPresented: $exporting, file: archive_url.appendingPathComponent(archive_name)) { result in
                if FileManager.default.fileExists(atPath: archive_url.appendingPathComponent(archive_name).path) {
                    try? FileManager.default.removeItem(at: archive_url.appendingPathComponent(archive_name))
                }
                exporting = false
                archive_name = ""
                //try? print(FileManager.default.contentsOfDirectory(atPath: archive_url.path))
            }
            .fileImporter(
                isPresented: $importing,
                allowedContentTypes: [.plainText],
                allowsMultipleSelection: true
            ) { result in
                let names = ["calib_a", "calib_b", "calib_c", "calib_t"]
                let selectedFilesopt: [URL]? = try? result.get()
                var selectedFiles: [URL]
                // print(selectedFilesopt!)
                if selectedFilesopt == nil { // linter doesn't like the guard-let syntax for this
                    print("returned early at \(#line) in \(#file)")
                    return
                } else {
                    selectedFiles = selectedFilesopt!
                }
                
                //  selectedFiles.map{ print($0.lastPathComponent) }
                let filenames = selectedFiles.map{ $0.lastPathComponent }
                // print(filenames)
                //print(filenames.allSatisfy({ names.contains(where: $0.contains) }))
                if filenames.allSatisfy({ names.contains(where: $0.contains) }) && selectedFiles.count == 4 {
                    // all selected files have names containing one of the elements of "names"
                    let id = String(selectedFiles[0].lastPathComponent.prefix(3))
                    let afile = selectedFiles.first { $0.lastPathComponent.contains("calib_a") }! // doesn't throw because of ^if
                    let bfile = selectedFiles.first { $0.lastPathComponent.contains("calib_b") }!
                    let cfile = selectedFiles.first { $0.lastPathComponent.contains("calib_c") }!
                    let tfile = selectedFiles.first { $0.lastPathComponent.contains("calib_t") }!
                    
                    config.saveDetector(id: id, afile: afile, bfile: bfile, cfile: cfile, tfile: tfile)
                } else {
                    print("returned early at \(#line) in \(#file)")
                    return
                }
            }
        }.navigationViewStyle(StackNavigationViewStyle())
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
