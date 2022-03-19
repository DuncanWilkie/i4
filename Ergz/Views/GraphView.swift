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
    var body: some View {
        let startDate =
            Date(timeIntervalSinceReferenceDate: slider.lowHandle.currentValue)
        let endDate =
            Date(timeIntervalSinceReferenceDate: slider.highHandle.currentValue)
        
       /* let window = TestWindow(startDate: startDate,
                                endDate: endDate,
                                density: 100,
                                toUpdate: !slider.lowHandle.onDrag && !slider.highHandle.onDrag
                                ) */
        let points = getPoints(store: store,
                               startDate: startDate,
                               endDate: endDate,
                               density: 100,
                               toUpdate: !slider.lowHandle.onDrag && !slider.highHandle.onDrag)
        
        LinesView(data: points, start: startDate, end: endDate)
        
        
    }
}



struct GraphView_Previews: PreviewProvider {
    static var previews: some View {
        GraphView().environmentObject(DoubleSlider((Date(), Date(timeIntervalSinceReferenceDate: 0))))
            .environmentObject(Store())
            .preferredColorScheme(/*@START_MENU_TOKEN@*/.dark/*@END_MENU_TOKEN@*/)
    }
}
