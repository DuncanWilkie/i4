//
//  UsingSlider.swift
//  Ergz
//
//  Created by Duncan Wilkie on 3/27/22.
//

import SwiftUI

struct UsingSlider: View { // GraphView and SliderView need to share a slider, but the slider has to have updated bounds based on the store's bounds.
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
