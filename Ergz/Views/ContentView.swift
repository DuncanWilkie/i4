//
//  ContentView.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 5/14/21.
//
import SwiftUI
import Combine


struct ContentView: View {
    @EnvironmentObject var detector: Detector
    var body: some View {
        TabView {
            VStack {
                Text(String(format: "%.2f Gy/hr", detector.lastValue))
                    .font(.system(.title))
                GraphView()
                Spacer().frame(height: 40)
                SliderView()
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

