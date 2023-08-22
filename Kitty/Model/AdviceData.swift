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
   advice(title: "Active Emergency", body: "Call 999"),
   advice(title: "Past Incident", body: "Use our Report page"),
   advice(title: "Future Incident", body: "check our External Resources page")
   ]
}
