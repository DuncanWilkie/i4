//
//  ContentView.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 5/14/21.
//
import SwiftUI
import Combine

// TODO: Search and destroy all hard-coded UI positioning values, testing on different-dimensioned platforms
// TODO: Break out views into minimum possible units to avoid unnecessary updates when environment objects change
struct ContentView: View {
    var body: some View {
        TabView {
            VStack {
                DoseView()
                UsingSlider()
                StatisticArray()
            }
            .tabItem {
                Label("Data", systemImage: "waveform.path.ecg")
            }
            
            VStack {
                StatusView()
                FrameView().border(Color(white: 0.47), width: 2)
                MeasurementSettingsView()
            }
            
            .preferredColorScheme(.dark)
            .tabItem {
                Label("Device", systemImage: "info.circle.fill")
            }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        
        .preferredColorScheme(/*@START_MENU_TOKEN@*/.dark/*@END_MENU_TOKEN@*/)
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

