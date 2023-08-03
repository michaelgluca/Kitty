//
//  SidebarView.swift
//  Kitty
//
//  Created by Michael Luca on 30/07/2023.
//

import SwiftUI

struct MoreMenu: View {
    
    var body: some View {
        
        ZStack {
            Image("background")
        }
    }
}
struct SideMenu_Previews: PreviewProvider {
    static var previews: some View{
        NavigationView {
            MoreMenu()
        }
    }
}
