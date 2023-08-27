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
   advice(title: "Active Emergency", body: "- Are you in an immediate danger?\n- Do you need emergency assistance?\n- Do you feel unsafe?\n- Are you having a medical emergency?\n\nIf the answer is YES to any of these questions then you should call 999 or trigger the SOS alarm.\n\nPress and hold the side button and one of the volume buttons until the Emergency SOS slider appears. Drag the Emergency Call slider to call the emergency services, or press the lock button FIVE times.\n\nIf you are unable to speak, you can make a silent call by calling 999 and then pressing 55.\n\nTo call the police for a non-emergency enquiry dial 101."),
   advice(title: "Past Incident", body: "Past incidents are NOT active emergencies.\n\n- If the incident or crime you are reporting is not an active emergency \n- If It happened in the past\n- If you want to report a crime via text\n- If you want to report a crime online\n\nUse the Report page and follow the links.\n\nIf you witness a crime you have a vital role to play in bringing the criminals to justice.\n\nYou may well be feeling upset and have doubts about reporting a crime.\n\nThere is no legal obligation to contact the police, but the information you give them could bring a criminal to justice."),
   advice(title: "Future Incident", body: "Following crime prevention advice helps to reduce your risk of being a victim of crime and makes you and your loved ones safer.\n\nCheck our resources page for a list of useful charities and organisations who can provide essential services and advise regarding domestic violence, providing shelters and more.\n\nThe ‘Local Crime Stats’ provide an over view on what is happening at a specific address and offers a crime prevention advise that relates to it.\n\nBeing vigilant and aware is one of the best ways to know when you are in danger and be able to prevent a threat before it occurs.")
   ]
}
