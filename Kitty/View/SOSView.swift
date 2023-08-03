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
