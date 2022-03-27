//
//  DoseView.swift
//  Ergz
//
//  Created by Duncan Wilkie on 3/27/22.
//

import SwiftUI

struct DoseView: View {
    @EnvironmentObject var detector: Detector
    var body: some View {
        Text(String(format: "%.2f Gy/hr", detector.lastValue))
            .font(.system(.title))
    }
}

struct DoseView_Previews: PreviewProvider {
    static var previews: some View {
        DoseView()
    }
}
