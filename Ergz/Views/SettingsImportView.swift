//
//  SettingsView.swift
//  Ergz
//
//  Created by Duncan Wilkie on 11/6/21.
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers

func parseCalibrationCSV(_ file: String) throws -> [[String : Double]] { // may need to stop using dictionaries since order of keys isn't preserved
    var calibration: [[String : Double]] = []
    
    let newline = (file.contains("\r")) ? "\r\n" : "\n" // support windows or UNIX newlines; no carriage returns allowed otherwise!
    let rows = file.components(separatedBy: newline)
    let labels = rows[0].components(separatedBy: ",")
    
    for i in rows[1...] {
        let values = i.components(separatedBy: ",")
        for (n, j) in labels.enumerated() {
            guard let point = Double(values[n]) else {
                print("Some CSV entry not convertible to Double")
                throw CocoaError(.fileReadCorruptFile)
            }
            calibration.append([j : point])
        }
    }
    
    return calibration
}

struct CalibrationFile: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    
    var calibration: [[String : Double]]
    
    init(_ calibration: [[String : Double]]) {
        self.calibration = calibration
    }
    
    init(configuration: FileDocumentReadConfiguration) throws { // parse CSV from file
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        do {
            try self.calibration = parseCalibrationCSV(string)
        } catch {
            throw error
        }
        
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let labels = calibration[0].keys
        var stringified = labels.joined(separator: ",") + "\n"
        for row in calibration {
            for key in labels {
                stringified += String(row[key] ?? 0.0) + ","
            }
            stringified += "\n"
        }
        
        return FileWrapper(regularFileWithContents: stringified.data(using: .utf8)!)
    }
}


struct SettingsImportView: View {
    @State var importing: Bool = false
    var body: some View {
        HStack {
            Button(action: { importing = true}, label: {
                Text("Import Calibration")
            })
        }
        .padding()
        .fileImporter(
            isPresented: $importing,
            allowedContentTypes: [.plainText],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let selectedFile: URL = try result.get().first else { return }
                if selectedFile.startAccessingSecurityScopedResource() {
                    guard let input = String(data: try Data(contentsOf: selectedFile), encoding: .utf8) else { return }
                    defer { selectedFile.stopAccessingSecurityScopedResource() }
                    let result = try parseCalibrationCSV(input)
                }
            } catch {
                // Handle failure.
                print("Unable to read file contents")
                print(error.localizedDescription)
            }
        }

    }
}

struct SettingsImportView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsImportView()
    }
}
