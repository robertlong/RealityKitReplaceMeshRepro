//
//  ReplaceMeshReproApp.swift
//  ReplaceMeshRepro
//
//  Created by Robert Long on 8/23/23.
//

import SwiftUI

@main
struct ReplaceMeshReproApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
        }
    }
}
