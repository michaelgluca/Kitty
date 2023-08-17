//
//  Settings.swift
//  Kitty
//
//  Created by Michael Luca on 03/08/2023.
//

import SwiftUI

struct SettingsView: View {
    
    @Binding var darkModeOn: Bool
    @Binding var systemThemeOn: Bool
    @Binding var faceIdOn: Bool
    
    var body: some View {
        
        NavigationView {
            
            Form {
                Section(header: Text("Display"), footer: Text("Current theme is the system defult theme")){
                    Toggle(isOn: $faceIdOn, label: {
                        Text("Lock with Face ID")
                    })
                    .onChange(of: faceIdOn) {
                        faceIdOn.toggle()
                        
                    }
                    Toggle(isOn: $darkModeOn, label: {
                        Text("Dark mode")
                    })
                    .onChange(of: darkModeOn, perform: { _ in
                        SystemThemeManager.shared.handleTheme(darkMode: darkModeOn, system: systemThemeOn)
                    })
                    
                }
                Section(header: Text("iPhone Setup"), footer: Text("Guids to optimise  iPhone's emergency settings")) {
                    
                    Link("Contact Emergency Services", destination: URL(string: "https://support.apple.com/en-gb/guide/iphone/iph3c99374c/")!)
                    
                    Link("Medical ID", destination: URL(string: "https://support.apple.com/en-gb/guide/iphone/iph08022b192/")!)
                    
                    Link("Use Emergency SOS via satellite", destination: URL(string: "https://support.apple.com/en-gb/guide/iphone/iph2968440de/")!)
                    
                }
                Section(header: Text("Contact"), footer: Text("Use the above links to be redirected")) {
                    
                    Link("National Domestic Abuse Halpline", destination: URL(string: Constansts.phone)!)
                    
                    Link("Follow me on X (Twitter)", destination: URL(string: Constansts.twitter)!)
                    
                    Link("Feedback", destination: URL(string: Constansts.email)!)
                    
                }
                
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background{
                Image(.background)
            }
        }
    }
}

#Preview {
    SettingsView(darkModeOn: .constant(false), systemThemeOn: .constant(true), faceIdOn: .constant(false))
}
