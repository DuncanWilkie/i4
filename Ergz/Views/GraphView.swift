//
//  GraphView.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 5/24/21.
//

import SwiftUI



struct GraphView: View {
    @ObservedObject var slider: DoubleSlider
    var body: some View {
        let startDate =
            Date(timeIntervalSinceReferenceDate: slider.lowHandle.currentValue)
        let endDate =
            Date(timeIntervalSinceReferenceDate: slider.highHandle.currentValue)
        
        let window = TestWindow(startDate: startDate,
                                endDate: endDate,
                                density: 100,
                                toUpdate: !slider.lowHandle.onDrag && !slider.highHandle.onDrag
                                )
        
        LinesView(window: window)
        
    }
}



struct GraphView_Previews: PreviewProvider {
    static var previews: some View {
        GraphView(slider: DoubleSlider(Scope.db.timeBounds)).preferredColorScheme(/*@START_MENU_TOKEN@*/.dark/*@END_MENU_TOKEN@*/)
    }
}
