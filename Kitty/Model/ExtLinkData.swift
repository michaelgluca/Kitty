//
//  ExtLinkData.swift
//  Kitty
//
//  Created by Michael on 13/08/2023.
//

import Foundation

struct eLink: Identifiable {
    let id = UUID()
    let title: String
    let imageName: String
    let description: String
    let type: String
    let url: URL
}

struct eLinkList {
    static let links = [
        eLink(title: "Womens's Aid", imageName: "womensaid", description: "Women’s Aid is the national charity working to end domestic abuse against women and children. they have been at the forefront of shaping and coordinating responses to domestic violence and abuse through practice for over 45 years. they empower survivors by keeping their voices at the heart of our work, working with and for women and children by listening to them and responding to their needs. Women’s Aid was founded on women’s struggle against patriarchy, sexism and male violence and grew out of the Women’s movement in the 70’s and 80’s. Today they take an intersectional approach to our work to end domestic abuse and stand with other feminist organisations leading the way in eradicating Violence Against Women and Girls.",type: "Charity", url: URL(string:"https://www.womensaid.org.uk")!),
        eLink(title: "Refuge", imageName: "refuge", description: "Refuge is the largest specialist domestic abuse organisation in the UK. On any given day its services support thousands of survivors, helping them to overcome the physical, emotional, financial and logistical impacts of abuse and rebuild their lives — free from fear.", type: "Charity", url: URL(string:"https://www.refuge.org.uk")!),
        eLink(title: "Citizens Advice", imageName: "citizenzadvice", description: "Citizens Advice helps people find a way forward At Citizens Advice they believe no one should have to face these problems without good quality, independent advice. That’s why they’re here: to give people the knowledge and the confidence they need to find their way forward - whoever they are, and whatever their problem. they give advice to millions of people. Their network of independent charities offers confidential advice online, over the phone, and in person, for free", type: "Organisation", url: URL(string:"https://www.citizensadvice.org.uk/family/gender-violence/domestic-violence-and-abuse")!),
        eLink(title: "NHS", imageName: "nhs", description: "The NHS was set up in 1948 to provide everyone in the UK with healthcare based on their needs, and not on their ability to pay. The NHS is respected throughout the world for the standard of care it gives to patients. Although most people think about the NHS as being their local hospital, when you visit your dentist, your GP or even your local pharmacist you could be speaking to someone employed by the NHS. And increasingly there is more and more NHS staff whose work is not based in a hospital, but who work in local health centres, GP practices or even in patients' own homes.", type: "Organisation", url: URL(string:"https://www.nhs.uk/live-well/getting-help-for-domestic-violence")!),
        eLink(title: "United Nations", imageName: "un", description: "The United Nations is an international organization founded in 1945. Currently made up of 193 Member States, the UN and its work are guided by the purposes and principles contained in its founding Charter. The UN has evolved over the years to keep pace with a rapidly changing world. But one thing has stayed the same: it remains the one place on Earth where all the world’s nations can gather together, discuss common problems, and find shared solutions that benefit all of humanity.", type: "Organisation", url: URL(string:"https://www.un.org/en/coronavirus/what-is-domestic-abuse")!),
        eLink(title: "World Health Organaization", imageName: "who", description: "Founded in 1948, WHO is the United Nations agency that connects nations, partners and people to promote health, keep the world safe and serve the vulnerable – so everyone, everywhere can attain the highest level of health.", type: "Organisation", url: URL(string:"https://www.who.int/news-room/fact-sheets/detail/violence-against-women")!)
    ]
}
