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
                Section(header: Text("iPhone Setup"), footer: Text("Guides to optimise iPhone's emergency settings")) {
                    
                    Link("Contact Emergency Services Setup", destination: URL(string: Constants.sosSetup)!)
                    
                    Link("Emergency SOS via Satellite Guide", destination: URL(string: Constants.satelliteGuide)!)
                    
                    Link("Emergency SOS Guide", destination: URL(string: Constants.sosGuide)!)
                    
                    Link("Medical ID Setup", destination: URL(string: Constants.medicalId)!)
                    
                }
                Section(header: Text("Contact"), footer: Text("Use the above links to be redirected")) {
                    
                    Link("National Domestic Abuse Helpline", destination: URL(string: Constants.phone)!)
                    
                    Link("Follow me on X (Twitter)", destination: URL(string: Constants.twitter)!)
                    
                    Link("Feedback", destination: URL(string: Constants.email)!)
                    
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
