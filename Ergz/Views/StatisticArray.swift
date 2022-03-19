//
//  StatisticsView.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 6/30/21.
//

import SwiftUI
import GRDB

func gatherStats(store: Store, startDate: Date, endDate: Date) -> (Double, Double, Double, Double) {
    // TODO: Debug (should work on Testrecord)
    var ret: (Double, Double, Double, Double) = (0, 0, 0, 0)
    do {
        try store.queue.read {db in
            let avdep = try Testrecord.select(average(Column("DEPOSITION")), as: Double.self).fetchOne(db) ?? 0.0
            let avexp = try Testrecord.select(average(Column("EXPOSURE")), as: Double.self).fetchOne(db) ?? 0.0
            let totdep = try Testrecord.select(sum(Column("DEPOSITION")), as: Double.self).fetchOne(db) ?? 0.0
            let totdose = try Testrecord.select(sum(Column("DOSE")), as: Double.self).fetchOne(db) ?? 0.0
            let peakdose = try Testrecord.select(max(Column("DOSE")), as: Double.self).fetchOne(db) ?? 0.0
            
            ret = (avdep / avexp, totdep, totdose, peakdose)
        }
    } catch {
        print(error)
    }
    
    return ret
    
}

struct StatisticArray: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var slider: DoubleSlider
    var body: some View {
        let stats = gatherStats(store: store,
                                startDate: Date(timeIntervalSinceReferenceDate: slider.lowHandle.currentValue),
                                endDate: Date(timeIntervalSinceReferenceDate: slider.highHandle.currentValue))
        ZStack {
            VStack {
                HStack(spacing: 0) {
                    Statistic(value: stats.0, unit: "keV/s", label: "Avg. Dep. Rate")
                
                    Statistic(value: stats.1 , unit: "MeV", label: "Tot. Deposition")
                }
                HStack(spacing: 0) {
                    Statistic(value: stats.2, unit: "Gy", label: "Est. Dose")
                
                    Statistic(value: stats.3, unit: "Gy/hr", label: "Peak Dose")
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
