//
//  NoConnection.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 5/14/21.
//

import SwiftUI

struct NoConnection: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("No Device Found").foregroundColor(.white)
        }
    }
}

struct NoConnection_Previews: PreviewProvider {
    static var previews: some View {
        NoConnection()
    }
}
