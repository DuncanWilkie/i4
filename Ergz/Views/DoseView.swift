//
//  DoseView.swift
//  Ergz
//
//  Created by Duncan Wilkie on 3/27/22.
//

import SwiftUI

struct DoseView: View { // Localizing updates
    @EnvironmentObject var detector: Detector
    @EnvironmentObject var config: Config
    var body: some View {
        Text(autoDoubleFormatter(value: detector.lastValue, unit: config.units + "/s", width: 6) )
            .font(.system(.title))
    }
}

struct DoseView_Previews: PreviewProvider {
    static var previews: some View {
        DoseView()
    }
}
