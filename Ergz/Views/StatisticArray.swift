//
//  StatisticsView.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 6/30/21.
//

import SwiftUI
import GRDB

func gatherStats(store: Store, startDate: Date, endDate: Date) -> (Double, Double, Double, Double) {
    // TODO: Debug (should work on Testrecord); currently no date filtering so...SQL
   /* let query = "SELECT AVG(DEPOSITION / EXPOSURE) AS AVDEPRT, SUM(DEPOSITION) AS TOTDEP, SUM(DOSE) AS TOTDOSE, MAX(DOSE) AS PKDOSE FROM MEASUREMENT WHERE DATE >= '\(toSQL(startDate))' AND DATE <= '\(toSQL(endDate))'"
    var res: Row?
    do {
        res = try store.queue.read {db in
            try Row.fetchOne(db, sql: query)
        }
    } catch {
        print(error)
    }
    
    if let i = res {
        if i.allSatisfy({ !$0.1.isNull }) {
            let avdeprt: Double = i["AVDEPRT"]
            let totdep: Double = i["TOTDEP"]
            let totdose: Double = i["TOTDOSE"]
            let pkdose: Double = i["PKDOSE"]
            
            return (avdeprt, totdep, totdose, pkdose)
        } else {
            return (0, 0, 0, 0)
        }
    } else {
        print("Error in gatherStats: query returned nil")
        return (0, 0, 0, 0)
    } */
    
    let query = "SELECT AVG(DEPOSITION / EXPOSURE) AS AVDEPRT, SUM(DEPOSITION) AS TOTDEP FROM TESTRECORD WHERE DATE >= '\(toSQL(startDate))' AND DATE <= '\(toSQL(endDate))'"
    
    var res: Row?
    do {
        res = try store.queue.read {db in
            try Row.fetchOne(db, sql: query)
        }
    } catch {
        print(error)
    }
    
    if let i = res {
        if i.allSatisfy({ !$0.1.isNull }) {
            
            
            let avdep: Double = i["AVDEPRT"]
            //let exp: Double = i["EXP"]
            let totdep: Double = i["TOTDEP"]
            
            return (avdep, totdep, 0, 0)
        } else {
            return (0, 0, 0, 0)
        }
    } else {
        print("Error in gatherStats: query returned nil")
        return (0, 0, 0, 0)
    }
    
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
                    Statistic(value: stats.0, unit: "eV/s", label: "Avg. Dep. Rate")
                    
                    Statistic(value: stats.1 , unit: "eV", label: "Tot. Deposition")
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
