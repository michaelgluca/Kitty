//
//  ExternalLinks.swift
//  Kitty
//
//  Created by Michael Luca on 03/08/2023.
//

import SwiftUI

struct ExternalLinks: View {
    var body: some View {
        NavigationView {

                List {
                    Section {
                        Text("Women's Aid")
                            .listRowBackground(Capsule().fill(Color(red: 0.815, green: 0.496, blue: 0.847, opacity: 0.9)))
                            .foregroundColor(Color.white)
                            .font(Font.body)
                            .bold()
                            .listRowSeparator(.hidden)
                            .padding()
                        Text("Shelters")
                            .listRowBackground(Capsule().fill(Color(red: 0.815, green: 0.496, blue: 0.847, opacity: 0.9)))
                            .foregroundColor(Color.white)
                            .font(Font.body)
                            .bold()
                            .listRowSeparator(.hidden)
                            .padding()
                        Text("Citizens Advice")
                            .listRowBackground(Capsule().fill(Color(red: 0.815, green: 0.496, blue: 0.847, opacity: 0.9)))
                            .foregroundColor(Color.white)
                            .font(Font.body)
                            .bold()
                            .listRowSeparator(.hidden)
                            .padding()
                    } header: {
                        Text("External Links")
                            .font(.title)
                            .bold()
                            .foregroundColor(.accentColor)
                            .shadow(radius: 5)
                    }
                }
                .scrollContentBackground(.hidden)
                .background{
                    Image("background")
                }
        }
    }
}

struct ExternalLinks_Previews: PreviewProvider {
    static var previews: some View {
        ExternalLinks()
    }
}
