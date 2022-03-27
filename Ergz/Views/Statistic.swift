//
//  Statistic.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 6/30/21.
//

import SwiftUI

struct Statistic: View {
    var value: Double
    var unit: String
    var label: String
    var description: String? = nil
    @State var pressed: Bool = false
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading) {
                Text(autoDoubleFormatter(value: value, unit: unit, width: 6))
                    
                
                Text(label)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            ZStack {
                Text(description ?? "").overlay(
                    Rectangle()
                        .fill(Color.gray)
                        .opacity(0.5)
                )
            }
            .opacity(pressed ? 1 : 0)
            .frame(width: 300, height: 65)
            .offset(x: 0, y: -55)            
        }.onTapGesture {
            pressed.toggle()
        }
        .frame(width: 170, height: 100)
    
        
    }
}


struct Statistic_Previews: PreviewProvider {
    static var previews: some View {
        Statistic(value: 10.230, unit: "keV/s", label: "Expected Dose", description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et mag")
            .preferredColorScheme(/*@START_MENU_TOKEN@*/.dark/*@END_MENU_TOKEN@*/)
    }
}
