//
//  ContentView.swift
//  Kitty
//
//  Created by Michael Luca on 27/07/2023.
//

import SwiftUI
import LocalAuthentication

struct ContentView: View {
    
    @AppStorage("darkModeOn") private var darkModeOn = false
    @AppStorage("systemThemeOn") private var systemThemeOn = false
    @AppStorage("faceIdOn") private var faceIdOn = false
    
    @State private var unlocked = true
    
    var body: some View {
        
        if unlocked {
            TabView {
                ReportView()
                    .tabItem{
                        Label("Report", systemImage: "exclamationmark.bubble.fill")
                    }
                
                MapView()
                    .tabItem{
                        Label("Map", systemImage: "map.fill")
                    }
                
                ExternalLinks()
                    .tabItem{
                        Label("Resourcess", systemImage: "square.and.arrow.up")
                    }
                
                SettingsView(darkModeOn: $darkModeOn, systemThemeOn: $systemThemeOn, faceIdOn: $faceIdOn)
                    .tabItem{
                        Label("Setup", systemImage: "gear")
                    }
            }.onAppear {
                
                UITabBar.appearance().backgroundColor = .white

                SystemThemeManager.shared.handleTheme(darkMode: darkModeOn, system: systemThemeOn)
                if faceIdOn {
                    authenticate()
                }
            }
        }
    }
    func authenticate() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "This is for security reasons"){ success, authenticationError in
                if success {
                    self.unlocked = true
                }
                else{
                    authenticate()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
