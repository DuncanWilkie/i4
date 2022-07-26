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
    @EnvironmentObject var config: Config
    var body: some View {
        HStack {
            Form {
                Toggle("Record", isOn: $detector.measuring)
                    .toggleStyle(SwitchToggleStyle())
                    .disabled(config.selected == "" || !detector.isConnected)
                    .foregroundColor(config.selected == "" || !detector.isConnected ? Color.gray : Color.white)
                    
                
                HStack{
                    // TODO: Implement framerate message sending in Detector
                    Text("Exposure Time (s)")
                    TextField(text: $detector.exposure_str) {
                        Text("Exposure Time (s)")
                    }.multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .onReceive(Just(detector.exposure_str)) { newValue in
                            let filtered = newValue.filter { "0123456789.".contains($0) }
                            if filtered != newValue {
                                detector.exposure_str = filtered 
                            }
                        }
                }
            }
            .frame(width: 500, height: 200, alignment: .leading)
            .padding()
        }
    }
}

struct MeasurementSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        MeasurementSettingsView()
    }
}
