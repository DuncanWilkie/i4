//
//  StatisticsView.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 6/30/21.
//

import SwiftUI
import GRDB



struct StatisticArray: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var config: Config
    @ObservedObject var slider: DoubleSlider
    var body: some View {
        let stats = store.stats(units: config.units,
                                conversion: config.conversion_str,
                                startDate: Date(timeIntervalSinceReferenceDate: slider.lowHandle.currentValue),
                                endDate: Date(timeIntervalSinceReferenceDate: slider.highHandle.currentValue))
        ZStack { // Would this look better with the same gray background as the Form()s?
            VStack {
                HStack(spacing: 0) {
                    Statistic(value: stats.0, unit: config.units + "/s", label: "Average")
                    
                    Statistic(value: stats.1 , unit: config.units, label: "Total")
                }
                HStack(spacing: 0) {
                    Statistic(value: stats.2, unit: config.units + "/s", label: "Maximum")
                    
                    Statistic(value: stats.3, unit: config.units + "/s", label: "Variance")
                }
            }
        }
    }
}

/* struct StatisticArray_Previews: PreviewProvider {
    static var previews: some View {
        StatisticArray(slider: DoubleSlider((Date(),Date()))).preferredColorScheme(.dark)
    }
} */
