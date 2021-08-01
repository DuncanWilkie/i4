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
                    Statistic(value: 120.2, unit: "keV/s", label: "Test")
                
                    Statistic(value: 1.023, unit: "°C", label: "Temp")
                }
                HStack(spacing: 0) {
                    Statistic(value: 75.43, unit: "Gy", label: "Lorem impusm")
                
                    Statistic(value: 0.023, unit: "µSv/hr", label: "Replace")
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
