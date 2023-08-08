//
//  SidebarView.swift
//  Kitty
//
//  Created by Michael Luca on 30/07/2023.
//

import SwiftUI
import MapKit


struct MapView: View {
    
    @State private var camerPosition: MapCameraPosition = .region(.userRegion)
    @State private var searchText = "Police Stations near me"
    @State private var results = [MKMapItem]()
    @State private var mapSelection: MKMapItem?
    
    var body: some View {
        
        
        Map(position: $camerPosition, selection: $mapSelection) {
            
            Annotation("My location", coordinate: .usrerLocation){
                ZStack{
                    Circle()
                        .frame(width: 32, height: 32)
                        .foregroundColor(.blue.opacity(0.25))
                    Circle()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.white)
                    Circle()
                        .frame(width: 12, height: 12)
                        .foregroundColor(.blue)
                }
            }
            ForEach(results, id: \.self) { item in
                let placemark = item.placemark
                Marker(placemark.name ?? "", coordinate: placemark.coordinate)
            }
        }.overlay(alignment:.top){
            TextField("", text: $searchText)
                .font(.subheadline)
                .padding(12)
                .background(.white)
                .padding()
                .shadow(radius: 10)
            
        }.onSubmit (of: .text){
            Task {
                await SearchPlaces()
            }
        }
        .onChange(of: mapSelection, { oldValue, newValue in
            // preview location card
        })
        .mapControls{
            MapCompass()
            MapPitchToggle()
            MapUserLocationButton()
        }
        
    }
}

extension MapView {
    func SearchPlaces() async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = .userRegion
        let results = try? await MKLocalSearch(request: request).start()
        self.results = results?.mapItems ?? []
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
