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
                    Label("SOS", systemImage: "sos.circle.fill")
                }
            
            MapView()
                .tabItem{
                    Label("More", systemImage: "list.dash")
                }
            
            ExternalLinks()
                .tabItem{
                    Label("External", systemImage: "square.and.arrow.up")
                }
            
            Settings()
                .tabItem{
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
