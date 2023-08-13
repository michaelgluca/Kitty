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
        eLink(title: "Womens's Aid", imageName: "womensaid", description: "Women’s Aid is the national charity working to end domestic abuse against women and children. they have been at the forefront of shaping and coordinating responses to domestic violence and abuse through practice for over 45 years. they empower survivors by keeping their voices at the heart of our work, working with and for women and children by listening to them and responding to their needs. Women’s Aid was founded on women’s struggle against patriarchy, sexism and male violence and grew out of the Women’s movement in the 70’s and 80’s. Today they take an intersectional approach to our work to end domestic abuse and stand with other feminist organisations leading the way in eradicating Violence Against Women and Girls.",type: "Charity", url: URL(string:"https://www.womensaid.org.uk")!)
    ]
}
