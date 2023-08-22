//
//  NotSureView.swift
//  Kitty
//
//  Created by Michael on 22/08/2023.
//

import SwiftUI

struct NotSureView: View {
    
    @StateObject var advice = AdviceList()
    
    var body: some View {
        TabView{
            ForEach(advice.advices,  id: \.id){ advice in
                NotSrueDetailedView(advice: advice)
            }
        }.tabViewStyle(.page(indexDisplayMode: .automatic))
    }
}

#Preview {
    NotSureView()
}
