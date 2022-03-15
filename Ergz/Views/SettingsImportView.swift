//
//  SettingsView.swift
//  Ergz
//
//  Created by Duncan Wilkie on 11/6/21.
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers


struct SettingsImportView: View {
    @State var importing: Bool = false
    @State var selected: String = "" {
        willSet {
            Saved.ins.selected = newValue
        }
    }
    var body: some View {
        Form {
            
            Section(header: Text("Detectors")){
                Picker("Active Detector", selection: $selected) {
                    List(Saved.ins.detectors) {detector in
                        Text(detector.id)
                    }
                }
                
                Button(action: { importing.toggle() }, label: {
                    Text("Import Calibration")
                })
            }
        }
        .padding()
        .fileImporter(
            isPresented: $importing,
            allowedContentTypes: [.plainText],
            allowsMultipleSelection: true
        ) { result in
                let names = ["a_calib", "b_calib", "c_calib", "t_calib"]
                let selectedFilesopt: [URL]? = try? result.get()
                var selectedFiles: [URL]
                print(selectedFilesopt!)
                if selectedFilesopt == nil { // linter doesn't like the guard-let syntax for this
                    return
                } else {
                    selectedFiles = selectedFilesopt!
                }
                
                if selectedFiles.allSatisfy({ names.contains(where: $0.lastPathComponent.contains) }) && selectedFiles.count == 4 {
                    // all selected files have names containing one of the elements of "names"
                    let id = String(selectedFiles[0].lastPathComponent.prefix(3))
                    let afile = selectedFiles.first { $0.lastPathComponent.contains("a_calib") }! // doesn't throw because of ^if
                    let bfile = selectedFiles.first { $0.lastPathComponent.contains("b_calib") }!
                    let cfile = selectedFiles.first { $0.lastPathComponent.contains("c_calib") }!
                    let tfile = selectedFiles.first { $0.lastPathComponent.contains("t_calib") }!
                    Saved.ins.saveDetector(id: id, afile: afile, bfile: bfile, cfile: cfile, tfile: tfile)
                } else {
                    return
                }
            }
        
    }
}

struct SettingsImportView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsImportView()
    }
}
