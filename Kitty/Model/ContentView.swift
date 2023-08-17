//
//  ContentView.swift
//  Kitty
//
//  Created by Michael Luca on 27/07/2023.
//

import SwiftUI

struct ContentView: View {
    
    @AppStorage("darkModeOn") private var darkModeOn = false
    @AppStorage("systemThemeOn") private var systemThemeOn = false
    @AppStorage("f") private var faceIdOn = false
    
    var body: some View {
        
        TabView {
            SOSView()
                .tabItem{
                    Label("Report", systemImage: "exclamationmark.bubble.fill")
                }
            
            MapView()
                .tabItem{
                    Label("Map", systemImage: "map.fill")
                }
            
            ExternalLinks()
                .tabItem{
                    Label("External", systemImage: "square.and.arrow.up")
                }
            
            SettingsView(darkModeOn: $darkModeOn, systemThemeOn: $systemThemeOn, faceIdOn: $faceIdOn)
                .tabItem{
                    Label("Setup", systemImage: "gear")
                }
        }.onAppear {
            UITabBar.appearance().isTranslucent = false
            SystemThemeManager.shared.handleTheme(darkMode: darkModeOn, system: systemThemeOn)
                
        }
    }
}

#Preview {
    ContentView()
}
