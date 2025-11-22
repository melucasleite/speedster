//
//  ProgressionView.swift
//  speedster
//
//  Created by Lucas Leite on 11/22/25.
//

import SwiftUI
import Charts
import CoreData

struct ProgressionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Solve.timestamp, ascending: true)],
        animation: .default)
    private var solves: FetchedResults<Solve>
    
    @State private var selectedDate = Date()
    @State private var solveToDelete: Solve?
    @State private var showingDeleteAlert = false
    @State private var showingDeleteAllAlert = false
    
    var body: some View {
        ZStack {
            SpeedsterTheme.backgroundColor
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    Text("Progression")
                        .font(SpeedsterTheme.headerFont)
                        .foregroundColor(SpeedsterTheme.textColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 20)
                    
                    // Stats summary
                    if !solves.isEmpty {
                        statsView
                            .padding(.horizontal)
                    }
                    
                    // Chart
                    if !solves.isEmpty {
                        chartView
                            .frame(height: 300)
                            .padding(.horizontal)
                    } else {
                        emptyStateView
                    }
                    
                    // Date Picker and Solves List
                    if !solves.isEmpty {
                        VStack(spacing: 16) {
                            // Date Picker
                            DatePicker(
                                "Select Date",
                                selection: $selectedDate,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .colorScheme(.dark)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            
                            // Solves List
                            solvesListView
                                .padding(.horizontal)
                        }
                        
                        // Delete All Data Button
                        Button(action: {
                            showingDeleteAllAlert = true
                        }) {
                            Text("Delete all data")
                                .font(SpeedsterTheme.statsFont)
                                .foregroundColor(.red)
                                .padding(.vertical, 12)
                        }
                        .padding(.top, 20)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Delete Solve?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                solveToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let solve = solveToDelete {
                    deleteSolve(solve)
                }
                solveToDelete = nil
            }
        } message: {
            if let solve = solveToDelete {
                Text("Are you sure you want to delete this solve of \(formatTime(milliseconds: solve.durationMillis))?")
            }
        }
        .alert("Delete All Data?", isPresented: $showingDeleteAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteAllSolves()
            }
        } message: {
            Text("This will permanently delete all \(solves.count) solve(s). This action cannot be undone.")
        }
    }
    
    private var statsView: some View {
        HStack(spacing: 20) {
            statBox(title: "Total Solves", value: "\(solves.count)")
            statBox(title: "Best Time", value: bestTimeString)
            statBox(title: "Avg 5", value: averageLast5String)
        }
    }
    
    private func statBox(title: String, value: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(SpeedsterTheme.labelFont)
                .foregroundColor(SpeedsterTheme.textColor.opacity(0.7))
            Text(value)
                .font(SpeedsterTheme.statsFont)
                .foregroundStyle(SpeedsterTheme.orangeGradient)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var chartView: some View {
        Chart {
            if solves.count < 5 {
                // Show individual solve times when less than 5 solves
                ForEach(Array(solves.enumerated()), id: \.offset) { index, solve in
                    if let timestamp = solve.timestamp {
                        LineMark(
                            x: .value("Date", timestamp),
                            y: .value("Time", Double(solve.durationMillis) / 1000.0)
                        )
                        .foregroundStyle(SpeedsterTheme.orangeGradient)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        
                        AreaMark(
                            x: .value("Date", timestamp),
                            y: .value("Time", Double(solve.durationMillis) / 1000.0)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.4, blue: 0.0).opacity(0.3),
                                    Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
                        PointMark(
                            x: .value("Date", timestamp),
                            y: .value("Time", Double(solve.durationMillis) / 1000.0)
                        )
                        .foregroundStyle(SpeedsterTheme.orangeGradient)
                    }
                }
            } else {
                // Show rolling average when 5 or more solves
                ForEach(Array(rollingAverageData.enumerated()), id: \.offset) { index, point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Time", point.averageTime / 1000.0)
                    )
                    .foregroundStyle(SpeedsterTheme.orangeGradient)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Time", point.averageTime / 1000.0)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.4, blue: 0.0).opacity(0.3),
                                Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
        }
        .chartXAxis {
            AxisMarks(preset: .aligned, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.2))
                AxisValueLabel(format: .dateTime.month().day())
                    .foregroundStyle(SpeedsterTheme.textColor.opacity(0.6))
            }
        }
        .chartYAxis {
            AxisMarks(preset: .aligned, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.2))
                AxisValueLabel {
                    if let seconds = value.as(Double.self) {
                        Text(String(format: "%.1fs", seconds))
                            .foregroundStyle(SpeedsterTheme.textColor.opacity(0.6))
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.03))
        .cornerRadius(16)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "timer")
                .font(.system(size: 60))
                .foregroundColor(SpeedsterTheme.textColor.opacity(0.3))
            Text("No solves yet")
                .font(SpeedsterTheme.headerFont)
                .foregroundColor(SpeedsterTheme.textColor.opacity(0.5))
            Text("Complete some solves to see your progression")
                .font(SpeedsterTheme.statsFont)
                .foregroundColor(SpeedsterTheme.textColor.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(height: 300)
        .padding()
    }
    
    private var solvesListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Solves for \(selectedDate, formatter: dateFormatter)")
                .font(SpeedsterTheme.labelFont)
                .foregroundColor(SpeedsterTheme.textColor.opacity(0.7))
                .padding(.horizontal, 8)
            
            if filteredSolves.isEmpty {
                Text("No solves for this date")
                    .font(SpeedsterTheme.statsFont)
                    .foregroundColor(SpeedsterTheme.textColor.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(filteredSolves, id: \.objectID) { solve in
                        solveRow(solve: solve)
                            .onLongPressGesture {
                                solveToDelete = solve
                                showingDeleteAlert = true
                            }
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func solveRow(solve: Solve) -> some View {
        HStack {
            Text(solve.timestamp ?? Date(), formatter: timeFormatter)
                .font(SpeedsterTheme.statsFont)
                .foregroundColor(SpeedsterTheme.textColor.opacity(0.7))
            
            Spacer()
            
            Text(formatTime(milliseconds: solve.durationMillis))
                .font(SpeedsterTheme.averageFont)
                .foregroundStyle(SpeedsterTheme.orangeGradient)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }
    
    // Computed properties for stats
    private var bestTimeString: String {
        guard let bestTime = solves.map({ $0.durationMillis }).min() else {
            return "--:--.--"
        }
        return formatTime(milliseconds: bestTime)
    }
    
    private var averageLast5String: String {
        let last5 = Array(solves.suffix(5))
        guard !last5.isEmpty else { return "--:--.--" }
        let sum = last5.reduce(0.0) { $0 + Double($1.durationMillis) }
        let average = sum / Double(last5.count)
        return formatTime(milliseconds: Int64(average))
    }
    
    // Filter solves for selected date (most recent first)
    private var filteredSolves: [Solve] {
        let calendar = Calendar.current
        return solves.filter { solve in
            guard let timestamp = solve.timestamp else { return false }
            return calendar.isDate(timestamp, inSameDayAs: selectedDate)
        }.sorted { ($0.timestamp ?? Date()) > ($1.timestamp ?? Date()) }
    }
    
    // Delete solve
    private func deleteSolve(_ solve: Solve) {
        withAnimation {
            viewContext.delete(solve)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error deleting solve: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    // Delete all solves
    private func deleteAllSolves() {
        withAnimation {
            for solve in solves {
                viewContext.delete(solve)
            }
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error deleting all solves: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    // Date formatters
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }
    
    // Rolling average data for chart
    private var rollingAverageData: [(date: Date, averageTime: Double)] {
        guard solves.count >= 5 else { return [] }
        
        var data: [(Date, Double)] = []
        
        for i in 4..<solves.count {
            let window = Array(solves[(i-4)...i])
            let sum = window.reduce(0.0) { $0 + Double($1.durationMillis) }
            let average = sum / 5.0
            if let date = solves[i].timestamp {
                data.append((date, average))
            }
        }
        
        return data
    }
    
    private func formatTime(milliseconds: Int64) -> String {
        let totalSeconds = Double(milliseconds) / 1000.0
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        let millisecondsPart = Int((totalSeconds.truncatingRemainder(dividingBy: 1.0)) * 1000)
        
        if minutes > 0 {
            return String(format: "%d:%02d.%03d", minutes, seconds, millisecondsPart)
        } else {
            return String(format: "%d.%03d", seconds, millisecondsPart)
        }
    }
}

#Preview {
    ProgressionView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
