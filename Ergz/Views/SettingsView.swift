//
//  SettingsView.swift
//  Ergz
//
//  Created by Duncan Wilkie on 11/6/21.
//

import SwiftUI
import Foundation
import Combine
import UniformTypeIdentifiers
import ZIPFoundation

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var detector: Detector
    @EnvironmentObject var config: Config
    
    @State var archive_name: String = ""
    @State var importing: Bool = false
    @State var exporting: Bool = false
    @State var exportRaw: Bool = false
    @State var exportAg: Bool = false
    @State var selectedStart: Date = Date()
    @State var selectedEnd: Date = Date()
    @State var alertingBadConfig: Bool = false
    @State var alertingConfirmClear: Bool = false
    
    
    
    var body: some View { // TODO: Might be nice to break this out into smaller, encapsulated views so @Published updates don't cause so much havoc. It's made difficult by the fact almost all the complexity here is outside of views.
        let archive_url = store.ourURL.appendingPathComponent("archive_staging")
        NavigationView {
            Form {
                Section(header: Text("Display")) {
                    Picker("Graph Type", selection: $config.plot) {
                        Text("Line").tag("line")
                        Text("Box-and-Whisker").tag("bw")
                    }.pickerStyle(.segmented)
                    Picker("Units", selection: $config.units) {
                        Text("eV").tag("eV")
                        Text("Gy").tag("Gy")
                        Text("Sv").tag("Sv")
                    }.pickerStyle(.segmented)
                    HStack{
                        Text("Equivalent Dose Conversion")
                        TextField(text: $config.conversion_str, prompt: Text("Equivalent Dose Conversion")) {
                            Text("Equivalent Dose Conversion")
                        }.multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .onReceive(Just(config.conversion_str)) { newValue in
                            let filtered = newValue.filter { "0123456789.".contains($0) }
                            if filtered != newValue {
                                config.conversion_str = filtered
                            }
                        }
                        .disabled(config.units != "Sv")
                        .foregroundColor(config.units != "Sv" ? Color.gray : Color.white )
                    }
                    
                }
                
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
                .alert("Failed to parse calibration file.", isPresented: $alertingBadConfig) { // TODO: check this works (after reworking this view)
                    Button("Ok", role: .cancel) { }
                }
                
                Section(header: Text("Export")) {
                    Button(action: { exportRaw.toggle() }, label: {
                        Text("Raw Frames")
                    }).sheet(isPresented: $exportRaw, onDismiss: {
                        if archive_name == "" {
                            archive_name = "export.zip"
                        }
                        
                        do {
                            let result: [FrameRecord] = try store.queue.read { db in
                                try FrameRecord.fetchAll(db, sql:"SELECT * FROM FRAMERECORD WHERE JULIANDAY('\(toSQL(selectedStart, store.fm))') - JULIANDAY(DATE) <= 0 AND JULIANDAY('\(toSQL(selectedEnd, store.fm))') - JULIANDAY(DATE) >= 0")
                            }
                            
                            if !FileManager.default.fileExists(atPath: archive_url.path) {
                                try FileManager.default.createDirectory(at: archive_url, withIntermediateDirectories: false, attributes: nil)
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
                            
                            if !FileManager.default.fileExists(atPath: archive_url.path) {
                                try FileManager.default.createDirectory(at: archive_url, withIntermediateDirectories: false, attributes: nil)
                            }
                            
                            let result: [Measurement] = try store.queue.read { db in
                                try Measurement.fetchAll(db, sql:"SELECT DATE, EXPOSURE, DEPOSITION, DOSE FROM MEASUREMENT WHERE JULIANDAY('\(toSQL(selectedStart, store.fm))') - JULIANDAY(DATE) <= 0 AND JULIANDAY('\(toSQL(selectedEnd, store.fm))') - JULIANDAY(DATE) >= 0")
                            }
                            
                            if FileManager.default.fileExists(atPath: archive_url.appendingPathComponent(archive_name).path) {
                                try FileManager.default.removeItem(at: archive_url.appendingPathComponent(archive_name))
                            }
                            
                            guard let archive = Archive(url: archive_url.appendingPathComponent(archive_name), accessMode: .create) else {
                                print("archive creation failed at \(#line) in \(#file)")
                                return
                            }
                            
                            var content = ",Date,Exposure (s), Deposition (eV), Absorbed Dose (Gy, in water)\n"
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
                
                
                Section(header: Text("Clear")) {
                    Button(action: { alertingConfirmClear = true }, label: {
                        Text("Clear Local Data")
                    })
                }.alert("Permanently delete all measurements stored on this device?", isPresented: $alertingConfirmClear) {
                    Button("Delete", role: .destructive) {
                        store.clear()
                    }
                    
                    Button("Cancel", role: .cancel) { }
                }
                
            }
            .navigationTitle("Settings")
            .padding()
            .fileImporter(
                isPresented: $importing,
                allowedContentTypes: [.plainText],
                allowsMultipleSelection: true
            ) { result in
                let names = ["calib_a", "calib_b", "calib_c", "calib_t"]
                let selectedFilesopt: [URL]? = try? result.get()
                var selectedFiles: [URL]
                if selectedFilesopt == nil { // linter doesn't like the guard-let syntax for this
                    print("returned early at \(#line) in \(#file)")
                    return
                } else {
                    selectedFiles = selectedFilesopt!
                }
                
                let filenames = selectedFiles.map{ $0.lastPathComponent }
                if filenames.allSatisfy({ names.contains(where: $0.contains) }) && selectedFiles.count == 4 {
                    // all selected files have names containing one of the elements of "names"
                    let id = String(selectedFiles[0].lastPathComponent.prefix(3))
                    let afile = selectedFiles.first { $0.lastPathComponent.contains("calib_a") }! // doesn't throw because of ^if
                    let bfile = selectedFiles.first { $0.lastPathComponent.contains("calib_b") }!
                    let cfile = selectedFiles.first { $0.lastPathComponent.contains("calib_c") }!
                    let tfile = selectedFiles.first { $0.lastPathComponent.contains("calib_t") }!
                    
                    do {
                        guard afile.startAccessingSecurityScopedResource() else { throw NSError() }
                        guard bfile.startAccessingSecurityScopedResource() else { throw NSError() }
                        guard cfile.startAccessingSecurityScopedResource() else { throw NSError() }
                        guard tfile.startAccessingSecurityScopedResource() else { throw NSError() }
                        
                        try config.saveDetector(id: id, afile: afile, bfile: bfile, cfile: cfile, tfile: tfile)
                        
                        afile.stopAccessingSecurityScopedResource()
                        bfile.stopAccessingSecurityScopedResource()
                        cfile.stopAccessingSecurityScopedResource()
                        tfile.stopAccessingSecurityScopedResource()
                    } catch {
                        alertingBadConfig = true
                        return
                    }
                } else {
                    print("returned early at \(#line) in \(#file)")
                    return
                }
            }
            .fileMover(isPresented: $exporting, file: archive_url.appendingPathComponent(archive_name)) { result in
                if FileManager.default.fileExists(atPath: archive_url.appendingPathComponent(archive_name).path) {
                    try? FileManager.default.removeItem(at: archive_url.appendingPathComponent(archive_name))
                }
                exporting = false
                archive_name = ""
            }
        }.navigationViewStyle(StackNavigationViewStyle())
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
