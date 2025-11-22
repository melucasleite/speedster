//
//  SpeedsterTheme.swift
//  speedster
//
//  Created by Lucas Leite on 11/22/25.
//

import SwiftUI

struct SpeedsterTheme {
    // Colors
    static let backgroundColor = Color.black
    static let textColor = Color.white
    
    // Orange gradient for accents, charts, buttons, and highlighted numbers
    static let orangeGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.4, blue: 0.0), Color(red: 1.0, green: 0.6, blue: 0.2)],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // Green gradient for better than average solves
    static let greenGradient = LinearGradient(
        colors: [Color(red: 0.0, green: 0.8, blue: 0.3), Color(red: 0.2, green: 1.0, blue: 0.5)],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // Red gradient for worse than average solves
    static let redGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.2, blue: 0.2), Color(red: 1.0, green: 0.4, blue: 0.3)],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // Text styles
    static let timerFont = Font.system(size: 80, weight: .bold, design: .monospaced)
    static let countdownFont = Font.system(size: 120, weight: .bold)
    static let labelFont = Font.system(size: 14, weight: .medium)
    static let averageFont = Font.system(size: 20, weight: .semibold, design: .monospaced)
    static let headerFont = Font.system(size: 28, weight: .bold)
    static let statsFont = Font.system(size: 16, weight: .regular)
    static let resultFont = Font.system(size: 18, weight: .semibold, design: .monospaced)
}
