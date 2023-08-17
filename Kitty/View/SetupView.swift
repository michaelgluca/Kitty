//
//  Settings.swift
//  Kitty
//
//  Created by Michael Luca on 03/08/2023.
//

import SwiftUI

struct SetupView: View {
    var body: some View {
        
        NavigationView {
            
            Form {
                Section(header: Text("Display"), footer: Text("System settings usses the current device display settings")){
                    Toggle(isOn: .constant(false), label: {
                        Text("Lock with Face ID")
                    })
                    Toggle(isOn: .constant(false), label: {
                        Text("Dark mode")
                    })
                    Toggle(isOn: .constant(true), label: {
                        Text("Use system settings")
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
    SetupView()
}
