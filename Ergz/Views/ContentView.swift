//
//  ContentView.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 5/14/21.
//
import SwiftUI



struct ContentView: View {
    @ObservedObject var slider = DoubleSlider(Scope.db.testTimeBounds)
    @ObservedObject var detector = Detector.ins
    
    var body: some View {
        //TabView {
            /*VStack {
                Text(String(format: "%.2f Gy/hr", detector.lastValue))
                    .font(.system(.title))
                GraphView(slider: slider)
                Spacer().frame(height: 40)
                SliderView(slider: slider)
                StatisticArray()
            }
            
            .tabItem {
                Label("Data", systemImage: "waveform.path.ecg")
            } */
            VStack {
                //Image()
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .foregroundColor(Color(white: 0.13))
                        .frame(width: 370, height: 22)
                    HStack {
                        Text(detector.stateDesc)
                            .font(.system(.body, design: .monospaced))
                            .padding(.leading, 20)
                        Spacer()
                    }
                    
                }
                
               // FrameView()
                //    .border(Color(white: 0.47), width: 2)
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .foregroundColor(Color(white: 0.13))
                        .frame(width: 400, height: 45)
                    Toggle("Take Measurements", isOn: $detector.measuring)
                    .toggleStyle(SwitchToggleStyle())
                    .frame(width: 350, height: 70)
                    .font(.system(size: 20))
                }
                Spacer().frame(width: 500, height: 100)
                Text("Thank you for choosing the SpaRTAN Physics Lab at LSU for all your radiation protection needs. Geaux Tigers!").opacity(detector.measuring ? 1.0 : 0.0)
                    
            }.preferredColorScheme(.dark)
                .tabItem {
                    Label("Device", systemImage: "info.circle.fill")
                }
           /* Text("Configuration")
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }*/
        //}.preferredColorScheme(/*@START_MENU_TOKEN@*/.dark/*@END_MENU_TOKEN@*/)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

