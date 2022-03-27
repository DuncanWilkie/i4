//
//  GraphView.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 5/24/21.
//

import SwiftUI



struct GraphView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var slider: DoubleSlider
    @ViewBuilder var body: some View {
        let startDate =
        Date(timeIntervalSinceReferenceDate: slider.lowHandle.currentValue)
        let endDate =
        Date(timeIntervalSinceReferenceDate: slider.highHandle.currentValue)
        
        GeometryReader { reader in
            if slider.lowHandle.onDrag || slider.highHandle.onDrag {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color("primaryAccent")))
                    .scaleEffect(1.5)
                    .frame(width: reader.size.width, height: reader.size.height)
            } else {
                if store.hasData {
                    let points = getPoints(store: store,
                                           startDate: startDate,
                                           endDate: endDate,
                                           density: 100)
                    LinesView(data: points, start: startDate, end: endDate).frame(width: reader.size.width, height: reader.size.height)
                } else {
                        Text("No Measurements Taken")
                            .foregroundColor(Color.gray)
                            .frame(width: reader.size.width, height: reader.size.height)
                }
            }
        }
        // TODO: Validate LinesView
        
        
    }
}



struct GraphView_Previews: PreviewProvider {
    static var previews: some View {
        GraphView().environmentObject(DoubleSlider((Date(), Date(timeIntervalSinceReferenceDate: 0))))
            .environmentObject(Store())
            .preferredColorScheme(/*@START_MENU_TOKEN@*/.dark/*@END_MENU_TOKEN@*/)
    }
}
