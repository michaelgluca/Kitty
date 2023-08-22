//
//  AdviceData.swift
//  Kitty
//
//  Created by Michael on 22/08/2023.
//

import Foundation

struct advice: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}

class AdviceList: ObservableObject {
   var advices = [
   advice(title: "1", body: "1"),
   advice(title: "2", body: "2"),
   advice(title: "3", body: "3")
   ]
}
