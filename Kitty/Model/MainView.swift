//
//  ContentView.swift
//  Kitty
//
//  Created by Michael Luca on 27/07/2023.
//

import SwiftUI

struct MainView: View {
    
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
            
            SetupView()
                .tabItem{
                    Label("Setup", systemImage: "gear")
                }
        }
    }
}

#Preview {
    MainView()
}
