//
//  HomePage.swift
//  Kitty
//
//  Created by Michael Luca on 27/07/2023.
//

import SwiftUI

struct SOSView: View {
    
    var body: some View {
        
        ZStack {
            
            Image("background")
            
            VStack{
                Spacer()
                HStack {
                    Label("For Emergency assitance \nPress and release the lock button \nFIVE times", systemImage: "bubble.right.fill")
                    Image(systemName: "arrow.down.forward.circle.fill")
                    
                }
                .shadow(radius: 5)
                .foregroundColor(.white)
                .bold()
                
                Spacer()
                Link(destination: URL(string: "https://www.met.police.uk/ro/report/ocr/af/how-to-report-a-crime/")!, label: {
                    Label("Report crime online", systemImage: "shield.righthalf.filled")
                        .font(.largeTitle)
                        .background(Color(.init(red: 0.815, green: 0.496, blue: 0.847, alpha: 1)))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        .shadow(radius: 5)
                })
                
                Spacer()
            }
        }
    }
}




struct HomeView_Previews: PreviewProvider {
    static var previews: some View{
        NavigationView {
            SOSView()
        }
    }
}
