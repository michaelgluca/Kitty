//
//  Settings.swift
//  Kitty
//
//  Created by Michael Luca on 03/08/2023.
//

import SwiftUI

struct SetupView: View {
    
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
                    Toggle(isOn: $darkModeOn, label: {
                        Text("Dark mode")
                    })
                    .onChange(of: darkModeOn, perform: { _ in
                        SystemThemeManager.shared.handleTheme(darkMode: darkModeOn, system: systemThemeOn)
                    })
                    
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
    SetupView(darkModeOn: .constant(false), systemThemeOn: .constant(true), faceIdOn: .constant(false))
}
