//
//  iCloud.swift
//  Ergz
//
//  Created by Duncan Wilkie on 7/20/22.
//

import Foundation

class CloudStore: ObservableObject {
    var obtained: Bool {
        return icloudURL != nil
    }
    var icloudURL: URL?
    
    init() {
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
    }
    
}
