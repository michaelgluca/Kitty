//
//  ExternalLinks.swift
//  Kitty
//
//  Created by Michael Luca on 03/08/2023.
//

import SwiftUI

struct ExternalLinks: View {
    
    var dlinks: [eLink] = eLinkList.links
    
    var body: some View {
        NavigationView {
            List(dlinks, id: \.id){ link in
                NavigationLink(destination: ExtlinkDetailedView(links: link), label: {                VStack(alignment: .leading, spacing: 5){
                    Text(link.title)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(link.type)
                        .lineLimit(1)
                        .font(.subheadline)
                        .foregroundStyle(Color(hue: 1.0, saturation: 0.045, brightness: 0.535))
                }})
            }
            .navigationTitle("External Resources")
            .foregroundColor(.accentColor)
            .shadow(radius: 5)
            .scrollContentBackground(.hidden)
            .background{
                Image(.background)
            }
        }
    }
}

#Preview {
    ExternalLinks()
}
