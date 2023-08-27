//
//  NotSrueDetailedView.swift
//  Kitty
//
//  Created by Michael on 22/08/2023.
//

import SwiftUI

struct NotSrueDetailedView: View {
    
    @State var advice: advice
    
    var body: some View {
        VStack(alignment: .center, spacing: 20){
            Text(advice.title)
                .font(.largeTitle)
            Spacer()
            Text(advice.body)
                .multilineTextAlignment(.leading)
            Spacer()
        }.padding()
            .frame(width: 340, height: 650, alignment: .center)
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(20)
            .shadow(radius: /*@START_MENU_TOKEN@*/10/*@END_MENU_TOKEN@*/)
    }
}

#Preview {
    NotSrueDetailedView(advice: advice(title: "Title", body: "body"))
}
