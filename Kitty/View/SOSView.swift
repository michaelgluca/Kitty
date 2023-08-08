//
//  HomePage.swift
//  Kitty
//
//  Created by Michael Luca on 27/07/2023.
//

import SwiftUI

struct SOSView: View {
    
    @State var metMessage = ""
    @State var btpMessage = ""
    @State var metNumber = "18000"
    @State var btpNumber = "61016"
    
    
    var body: some View {
        
        
        ZStack {
            Image("background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea(.all)
            
            VStack{
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
                
                HStack {
                    Label("For Emergency assitance \nPress & release the lock button \nFIVE times", systemImage: "bubble.right.fill")
                    Image(systemName: "arrow.right.circle.fill")
                    
                }
                .shadow(radius: 5)
                .foregroundColor(.white)
                .bold()
                
                Spacer()
                
                HStack {
                    Spacer()
                    TextField("Message the Metropolitan Police...", text: $metMessage)
                        .padding()
                    
                    
                    Spacer()
                    Button(action: {metMessage}){Image(systemName: "arrow.up.circle.fill")}
                    Spacer()
                    
                } .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white, lineWidth: 2))
                    .padding(.all, 30)
                
                HStack {
                    Spacer()
                    TextField("Message the Transport Police...", text: $btpMessage)
                        .padding()
                    
                    
                    Spacer()
                    Button(action: {}){Image(systemName: "arrow.up.circle.fill")}
                    Spacer()
                    
                } .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white, lineWidth: 2))
                    .padding(.all, 30)
                Spacer()
                
            }
        }
        
    }
    func sendMet(){
        let sms: String = "sms:\(metNumber)&body=\(metMessage)"
        let strURL: String = sms.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        UIApplication.shared.open(URL.init(string: strURL)!, options:[:], completionHandler: nil)
    }
    func sendBtp(){
        let sms: String = "sms:\(btpNumber)&body=\(btpMessage)"
        let strURL: String = sms.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        UIApplication.shared.open(URL.init(string: strURL)!, options:[:], completionHandler: nil)
    }
}




struct HomeView_Previews: PreviewProvider {
    static var previews: some View{
        NavigationView {
            SOSView()
        }
    }
}
