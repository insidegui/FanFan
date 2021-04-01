//
//  DebugView.swift
//  FanFan
//
//  Created by Guilherme Rambo on 26/03/21.
//

import SwiftUI

#if !arch(x86_64)
struct DebugView: View {
    @EnvironmentObject var engine: FanSimulationEngine
    
    var body: some View {
        VStack {
            Slider(value: $engine.intensity, in: 0.001...1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
