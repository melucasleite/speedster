//
//  ContentView.swift
//  speedster
//
//  Created by Lucas Leite on 11/22/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        TabView {
            TimerView()
                .environment(\.managedObjectContext, viewContext)
                .tabItem {
                    Label("Timer", systemImage: "timer")
                }
            
            ProgressionView()
                .environment(\.managedObjectContext, viewContext)
                .tabItem {
                    Label("Progression", systemImage: "chart.line.uptrend.xyaxis")
                }
        }
        .tint(Color(red: 1.0, green: 0.5, blue: 0.1))
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
