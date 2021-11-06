//
//  StatisticsView.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 6/30/21.
//

import SwiftUI

struct StatisticArray: View {
    var body: some View {
        ZStack {
            VStack {
                HStack(spacing: 0) {
                    Statistic(value: 120.2, unit: "keV/s", label: "Avg. Dep. Rate")
                
                    Statistic(value: 1.023 , unit: "MeV", label: "Tot. Deposition")
                }
                HStack(spacing: 0) {
                    Statistic(value: 20, unit: "Gy", label: "Est. Exposure")
                
                    Statistic(value: 0.23, unit: "Gy/hr", label: "Peak Exposure")
                }
            }
        }
    }
}

struct StatisticArray_Previews: PreviewProvider {
    static var previews: some View {
        StatisticArray().preferredColorScheme(.dark)
    }
}
