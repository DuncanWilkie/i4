//
//  UsingSlider.swift
//  Ergz
//
//  Created by Duncan Wilkie on 3/27/22.
//

import SwiftUI

struct UsingSlider: View {
    @EnvironmentObject var store: Store
    var body: some View {
        let slider = DoubleSlider(store.timeBounds)
        GraphView(slider: slider)
        Spacer().frame(height: 40)
        SliderView(slider: slider)
    }
}

struct UsingSlider_Previews: PreviewProvider {
    static var previews: some View {
        UsingSlider()
    }
}
