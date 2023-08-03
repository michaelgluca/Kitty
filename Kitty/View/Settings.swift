//
//  Settings.swift
//  Kitty
//
//  Created by Michael Luca on 03/08/2023.
//

import SwiftUI

struct Settings: View {
    var body: some View {
        ScrollView{
            NavigationView {
                
                List {
                    Text("1")
                    Text("2")
                    Text("3")
                }
                
            }.navigationTitle("Settings")
        }
    }
}

struct Settings_Previews: PreviewProvider {
    static var previews: some View {
        Settings()
    }
}
