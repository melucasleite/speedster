//
//  speedsterApp.swift
//  speedster
//
//  Created by Lucas Leite on 11/22/25.
//

import SwiftUI
import CoreData

@main
struct speedsterApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
