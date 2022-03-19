//
//  MeasurementSettingsView.swift
//  Ergz
//
//  Created by Duncan Wilkie on 3/17/22.
//

import SwiftUI
import Combine

struct MeasurementSettingsView: View {
    @EnvironmentObject var detector: Detector
    var body: some View {
        HStack {
            Form {
                Toggle("Record", isOn: $detector.measuring)
                    .toggleStyle(SwitchToggleStyle())
                
                HStack{
                    // TODO: Implement framerate message sending in Detector
                    TextField(text: $detector.framerate, prompt: Text("Framerate (Hz)")) {
                        Text("Framerate (Hz)")
                    }
                    .keyboardType(.numberPad)
                    .onReceive(Just(detector.framerate)) { newValue in
                        let filtered = newValue.filter { "0123456789.".contains($0) }
                        if filtered != newValue {
                            detector.framerate = filtered
                        }
                    }
                }
            }
            
            .frame(width: 500, height: 200, alignment: .leading)
        }
    }
}

struct MeasurementSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        MeasurementSettingsView()
    }
}
