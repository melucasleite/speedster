//
//  TimerView.swift
//  speedster
//
//  Created by Lucas Leite on 11/22/25.
//

import SwiftUI
import CoreData
import AVFoundation

enum TimerState {
    case idle
    case countdown(remaining: Int)
    case running
    case showingResult
}

struct SolveResult {
    let time: Int64
    let comparedToAverage: Int64? // positive = slower, negative = faster
}

struct TimerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Solve.timestamp, ascending: false)],
        animation: .default)
    private var solves: FetchedResults<Solve>
    
    @State private var timerState: TimerState = .idle
    @State private var elapsedMilliseconds: Int64 = 0
    @State private var timer: Timer?
    @State private var countdownTimer: Timer?
    @State private var startTime: Date?
    @State private var lastResult: SolveResult?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var currentScramble: String = ""
    
    var body: some View {
        ZStack {
            SpeedsterTheme.backgroundColor
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                VStack(spacing: 20) {
                    // Main timer or countdown display
                    timerDisplayView
                    
                    // Scramble sequence (only shown when idle)
                    if case .idle = timerState {
                        Text(currentScramble)
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundColor(SpeedsterTheme.textColor.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .lineLimit(3)
                    }
                }
                
                Spacer()
                
                // Averages at the bottom
                HStack(spacing: 40) {
                    averageView(label: "Avg 5", value: averageLast5)
                    averageView(label: "Avg All", value: averageAll)
                }
                .padding(.bottom, 50)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            handleTap()
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if currentScramble.isEmpty {
                currentScramble = generateScramble()
            }
        }
    }
    
    @ViewBuilder
    private var timerDisplayView: some View {
        switch timerState {
        case .idle:
            Text(formatTime(milliseconds: 0))
                .font(SpeedsterTheme.timerFont)
                .foregroundStyle(SpeedsterTheme.orangeGradient)
        case .countdown(let remaining):
            Text("\(remaining)")
                .font(SpeedsterTheme.countdownFont)
                .foregroundStyle(SpeedsterTheme.orangeGradient)
        case .running:
            Text(formatTime(milliseconds: elapsedMilliseconds))
                .font(SpeedsterTheme.timerFont)
                .foregroundStyle(SpeedsterTheme.orangeGradient)
        case .showingResult:
            if let result = lastResult {
                VStack(spacing: 16) {
                    Text(formatTime(milliseconds: result.time))
                        .font(SpeedsterTheme.timerFont)
                        .foregroundStyle(resultGradient(for: result))
                    
                    if let comparison = result.comparedToAverage {
                        resultComparisonView(comparison: comparison)
                    }
                }
            }
        }
    }
    
    private func resultGradient(for result: SolveResult) -> LinearGradient {
        guard let comparison = result.comparedToAverage else {
            return SpeedsterTheme.orangeGradient
        }
        
        if comparison < 0 {
            return SpeedsterTheme.greenGradient // Faster than average
        } else if comparison > 0 {
            return SpeedsterTheme.redGradient // Slower than average
        } else {
            return SpeedsterTheme.orangeGradient // Exactly average
        }
    }
    
    private func resultComparisonView(comparison: Int64) -> some View {
        let absDiff = abs(comparison)
        let isFaster = comparison < 0
        
        return HStack(spacing: 8) {
            Image(systemName: isFaster ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .font(.system(size: 24))
            
            Text("\(formatTimeDifference(milliseconds: absDiff)) \(isFaster ? "faster" : "slower")")
                .font(SpeedsterTheme.resultFont)
        }
        .foregroundStyle(isFaster ? SpeedsterTheme.greenGradient : SpeedsterTheme.redGradient)
    }
    
    private func averageView(label: String, value: Double?) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(SpeedsterTheme.labelFont)
                .foregroundColor(SpeedsterTheme.textColor.opacity(0.7))
            
            if let value = value {
                Text(formatTime(milliseconds: Int64(value)))
                    .font(SpeedsterTheme.averageFont)
                    .foregroundStyle(SpeedsterTheme.orangeGradient)
            } else {
                Text("--:--.--")
                    .font(SpeedsterTheme.averageFont)
                    .foregroundColor(SpeedsterTheme.textColor.opacity(0.5))
            }
        }
    }
    
    private func handleTap() {
        switch timerState {
        case .idle:
            startCountdown()
        case .countdown:
            // Cancel countdown and return to idle (don't save)
            cancelCountdown()
        case .running:
            stopTimer()
        case .showingResult:
            // Tap to dismiss result and return to idle
            timerState = .idle
            lastResult = nil
            // Generate new scramble for next solve
            currentScramble = generateScramble()
        }
    }
    
    private func startCountdown() {
        var remaining = 5
        timerState = .countdown(remaining: remaining)
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            remaining -= 1
            if remaining > 0 {
                timerState = .countdown(remaining: remaining)
            } else {
                timer.invalidate()
                startTimer()
            }
        }
    }
    
    private func cancelCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        timerState = .idle
    }
    
    private func startTimer() {
        // Play elegant beep sound
        playStartSound()
        
        timerState = .running
        elapsedMilliseconds = 0
        startTime = Date()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            if let startTime = startTime {
                elapsedMilliseconds = Int64(Date().timeIntervalSince(startTime) * 1000)
            }
        }
    }
    
    private func playStartSound() {
        // Create a simple beep tone using system sound
        AudioServicesPlaySystemSound(1103) // Tock sound - elegant and short
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        
        let solveTime = elapsedMilliseconds
        
        // Calculate comparison with average of last 5 solves (Avg 5)
        let comparison: Int64?
        if let avg5 = averageLast5 {
            comparison = solveTime - Int64(avg5)
        } else {
            comparison = nil
        }
        
        // Save the solve
        saveSolve(durationMillis: solveTime)
        
        // Show result (stays until user taps)
        lastResult = SolveResult(time: solveTime, comparedToAverage: comparison)
        timerState = .showingResult
        
        elapsedMilliseconds = 0
        startTime = nil
    }
    
    private func saveSolve(durationMillis: Int64) {
        withAnimation {
            let newSolve = Solve(context: viewContext)
            newSolve.timestamp = Date()
            newSolve.durationMillis = durationMillis
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error saving solve: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private var averageLast5: Double? {
        let last5 = Array(solves.prefix(5))
        guard !last5.isEmpty else { return nil }
        let sum = last5.reduce(0.0) { $0 + Double($1.durationMillis) }
        return sum / Double(last5.count)
    }
    
    private var averageAll: Double? {
        guard !solves.isEmpty else { return nil }
        let sum = solves.reduce(0.0) { $0 + Double($1.durationMillis) }
        return sum / Double(solves.count)
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
    
    private func formatTimeDifference(milliseconds: Int64) -> String {
        let totalSeconds = Double(milliseconds) / 1000.0
        let seconds = Int(totalSeconds)
        let millisecondsPart = Int((totalSeconds.truncatingRemainder(dividingBy: 1.0)) * 1000)
        
        if seconds > 0 {
            return String(format: "%d.%03ds", seconds, millisecondsPart)
        } else {
            return String(format: "0.%03ds", millisecondsPart)
        }
    }
    
    // Generate a random 25-move scramble sequence in cube notation
    private func generateScramble() -> String {
        let moves = ["U", "D", "F", "B", "L", "R"]
        let modifiers = ["", "'", "2"]
        var scramble: [String] = []
        var lastMove = ""
        
        for _ in 0..<25 {
            var move: String
            var fullMove: String
            
            // Avoid consecutive moves on the same face or opposite faces
            repeat {
                move = moves.randomElement()!
                let modifier = modifiers.randomElement()!
                fullMove = move + modifier
            } while move == lastMove || 
                    (move == "U" && lastMove == "D") ||
                    (move == "D" && lastMove == "U") ||
                    (move == "F" && lastMove == "B") ||
                    (move == "B" && lastMove == "F") ||
                    (move == "L" && lastMove == "R") ||
                    (move == "R" && lastMove == "L")
            
            scramble.append(fullMove)
            lastMove = move
        }
        
        return scramble.joined(separator: " ")
    }
}

#Preview {
    TimerView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
