//
//  HomePage.swift
//  Kitty
//
//  Created by Michael Luca on 27/07/2023.
//

import SwiftUI

struct ReportView: View {
    
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
                Link(destination: URL(string: Constansts.metReport)!, label: {
                    Label("Report Crime Online", systemImage: "shield.righthalf.filled")
                        .font(.largeTitle)
                        .background(Color(.init(red: 0.815, green: 0.496, blue: 0.847, alpha: 1)))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        .shadow(radius: 5)
                        .frame(width: 400, height: 70)
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
                        .foregroundColor(.white)
                        .padding()
                    
                    
                    Spacer()
                    Button(action: {sendMet()}){Image(systemName: "arrow.up.circle.fill")}
                    Spacer()
                    
                } .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white, lineWidth: 2).shadow(radius: 5))
                    .padding(.all, 30)
                
                HStack {
                    Spacer()
                    TextField("Message the Transport Police...", text: $btpMessage)
                        .foregroundColor(.white)
                        .padding()
                    
                    
                    Spacer()
                    Button(action: {sendBtp()}){Image(systemName: "arrow.up.circle.fill")}
                    Spacer()
                    
                } .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white, lineWidth: 2).shadow(radius: 5))
                    .padding(.all, 30)
                
                Spacer()
                
                Link(destination: URL(string: Constansts.metStats)!, label: {
                    Label("Local Crime Stats", systemImage: "list.bullet.clipboard")
                        .font(.largeTitle)
                        .background(Color(.init(red: 0.815, green: 0.496, blue: 0.847, alpha: 1)))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        .shadow(radius: 5)
                        .frame(width: 400, height: 70)
                })
                
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


#Preview {
    ReportView()
}
