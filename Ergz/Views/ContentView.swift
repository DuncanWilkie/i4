//
//  ContentView.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 5/14/21.
//
import SwiftUI
import Combine


struct ContentView: View {
    @ObservedObject var slider = DoubleSlider(Store.db.testTimeBounds)
    @ObservedObject var detector = Detector.ins
    @State var framerate = ""
    var body: some View {
        TabView {
            VStack {
                Text(String(format: "%.2f Gy/hr", detector.lastValue))
                    .font(.system(.title))
                GraphView(slider: slider)
                Spacer().frame(height: 40)
                SliderView(slider: slider)
                StatisticArray()
            }
            .tabItem {
                Label("Data", systemImage: "waveform.path.ecg")
            }
            
            VStack {
                //Image()
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .foregroundColor(Color(white: 0.13))
                        .frame(height: 24)
                    HStack {
                        Text(detector.stateDesc)
                            .font(.system(.body, design: .monospaced))
                            .padding(.leading, 10)
                        Spacer()
                    }
                }
                
                FrameView()
                    .border(Color(white: 0.47), width: 2)
                
                HStack {
                    Form {
                        Toggle("Record", isOn: $detector.measuring)
                            .toggleStyle(SwitchToggleStyle())
                        
                        HStack{
                            // TODO: Implement framerate message sending in Detector.ins
                            TextField(text: $framerate, prompt: Text("Framerate (Hz)")) {
                                Text("Framerate (Hz)")
                            }
                            .keyboardType(.numberPad)
                            .onReceive(Just(framerate)) { newValue in
                                let filtered = newValue.filter { "0123456789.".contains($0) }
                                if filtered != newValue {
                                    self.framerate = filtered
                                }
                            }
                        }
                    }
                    
                    .frame(width: 500, height: 200, alignment: .leading)
                }
            }
            
            .preferredColorScheme(.dark)
            .tabItem {
                Label("Device", systemImage: "info.circle.fill")
            }
            
            
            SettingsView(saved: Saved.ins)
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

