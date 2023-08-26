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
    @State private var searchText = ""
    @State private var results = [MKMapItem]()
    @State private var mapSelection: MKMapItem?
    @State private var showDetails = false
    @State private var getDirections = false
    @State private var routeDisplaying = false
    @State private var route: MKRoute?
    @State private var routeDestination: MKMapItem?
    
    var body: some View {
        
        Map(position: $camerPosition, selection: $mapSelection) {
            
            Annotation("My location", coordinate: .usrerLocation){
                ZStack{
                    Circle()
                        .frame(width: 32, height: 32)
                        .foregroundColor(.purple.opacity(0.25))
                    Circle()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.white)
                    Circle()
                        .frame(width: 12, height: 12)
                        .foregroundColor(.purple)
                }
            }
            
            ForEach(results, id: \.self) { item in
                if routeDisplaying {
                    if item == routeDestination {
                        let placemark = item.placemark
                        Marker(placemark.name ?? "", coordinate: placemark.coordinate)
                    }
                } else {
                    let placemark = item.placemark
                    Marker(placemark.name ?? "", coordinate: placemark.coordinate)
                }
            }
            
            if let route {
                MapPolyline(route.polyline)
                    .stroke(.purple, lineWidth: 6)
            }
            UserAnnotation()
        }
        .mapStyle(.standard(elevation: .realistic))
        .overlay(alignment:.top){
            TextField("Police Stations near me...", text: $searchText)
                .font(.subheadline)
                .padding(12)
                .background(.background)
                .padding(.horizontal, 55)
                .padding(.vertical, 5.0)
                .shadow(radius: 10)
            
        }.onSubmit (of: .text){
            Task {
                await searchPlaces()
            }
        }
        .onChange(of: getDirections, { oldValue, newValue in
            if newValue {
                fetchRoute()
            }
        })
        .onChange(of: mapSelection, { oldValue, newValue in
            showDetails = newValue != nil
        })
        .sheet(isPresented: $showDetails, content: {
            MapDetailedView(mapSelection: $mapSelection, show: $showDetails, getDirections: $getDirections)
                .presentationDetents([.height(340)])
                .presentationBackgroundInteraction(.enabled(upThrough: .height(340)))
                .presentationCornerRadius(12)
        })
        .mapControls{
            MapCompass()
            MapPitchToggle()
            MapUserLocationButton()
        }
    }
}

extension MapView {
    func searchPlaces() async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = .userRegion
        let results = try? await MKLocalSearch(request: request).start()
        self.results = results?.mapItems ?? []
    }
    func fetchRoute(){
        if let mapSelection{
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: .init(coordinate: .usrerLocation))
            request.destination = mapSelection
            
            Task {
                let result = try? await MKDirections(request: request).calculate()
                route = result?.routes.first
                routeDestination = mapSelection
                
                withAnimation(.snappy) {
                    routeDisplaying = true
                    showDetails = false
                    
                    if let rect = route?.polyline.boundingMapRect, routeDisplaying {
                        camerPosition = .rect(rect)
                    }
                }
            }
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
