//
//  elinkDetailedView.swift
//  Kitty
//
//  Created by Michael on 13/08/2023.
//

import SwiftUI



struct ExtlinkDetailedView: View {
    var links: eLink
    var body: some View {
        VStack {
            Spacer()
            Text(links.title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Color(.accent))
                .shadow(radius: 8)
            Spacer()
            
            Image(links.imageName)
                .resizable()
                .scaledToFit()
                .frame(height: 150)
                .cornerRadius(12)
            Spacer()
            Text(links.description)
                .font(.body)
                .lineLimit(17)
                .padding()
            Spacer()
            Link(destination: links.url, label: {
                Text("Go to Website")
                    .bold()
                    .font(.title2)
                    .frame(width: 280, height: 50)
                    .background(Color(.white))
                    .cornerRadius(10)
                    .shadow(radius: 5)
            })
            Spacer()
        }.background(Color(hue: 0.863, saturation: 0.303, brightness: 0.986))    }
}

#Preview {
    ExtlinkDetailedView(links: eLinkList.links.first!)
}
