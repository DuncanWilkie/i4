//
//  StatusView.swift
//  Ergz
//
//  Created by Duncan Wilkie on 3/17/22.
//

import SwiftUI

struct StatusView: View {
    @EnvironmentObject var detector: Detector
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 5)
                .foregroundColor(Color(white: 0.13))
                .frame(height: 24)
            HStack {
                Text(detector.stateDesc)
                    .font(.system(.body, design: .monospaced))
                    .padding(.leading, 10)
                Spacer()
            }
        }
    }
}

struct StatusView_Previews: PreviewProvider {
    static var previews: some View {
        StatusView()
    }
}
