//
//  SidebarView.swift
//  Kitty
//
//  Created by Michael Luca on 30/07/2023.
//

import SwiftUI
import MapKit

struct MapView: View {
    
    var body: some View {
        
        VStack {
            Text("map")
        }
    }
}

extension CLLocationCoordinate2D {
    static var usrerLocation: CLLocationCoordinate2D{
        return .init(latitude: 51.50853, longitude: -0.12574)
    }
}

extension MKCoordinateRegion {
    static var userRegion: MKCoordinateRegion {
        return .init(center: .usrerLocation, latitudinalMeters: 10000, longitudinalMeters: 10000)
    }
}

#Preview {
    MapView()
}
