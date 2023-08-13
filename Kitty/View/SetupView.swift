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

                    List {
                        Section {
                            Text("Guardians Setup")
                                .listRowBackground(Capsule().fill(Color(red: 0.815, green: 0.496, blue: 0.847, opacity: 0.9)))
                                .foregroundColor(Color.white)
                                .font(Font.body)
                                .bold()
                                .listRowSeparator(.hidden)
                                .padding()
                            Text("Location Access")
                                .listRowBackground(Capsule().fill(Color(red: 0.815, green: 0.496, blue: 0.847, opacity: 0.9)))
                                .foregroundColor(Color.white)
                                .font(Font.body)
                                .bold()
                                .listRowSeparator(.hidden)
                                .padding()
                            Text("App Passcode")
                                .listRowBackground(Capsule().fill(Color(red: 0.815, green: 0.496, blue: 0.847, opacity: 0.9)))
                                .foregroundColor(Color.white)
                                .font(Font.body)
                                .bold()
                                .listRowSeparator(.hidden)
                                .padding()
                        } header: {
                            Text("Emergency settings setup")
                                .font(.title)
                                .bold()
                                .foregroundColor(.accentColor)
                                .shadow(radius: 5)
                        }
                    }
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
