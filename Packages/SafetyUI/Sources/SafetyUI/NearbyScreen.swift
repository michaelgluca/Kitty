import MapKit
import SafetyContent
import SafetyDomain
import SafetyServices
import SwiftUI

/// The Nearby tab: the nearest police stations on a map with walking directions, and
/// the way to women's refuges.
struct NearbyScreen: View {

    @Environment(\.services) private var services
    @Environment(\.regionStance) private var region
    @Environment(\.scenePhase) private var scenePhase
    @Environment(NearbyModel.self) private var model

    let pack: ContentPack?

    @State private var settingsFailed = false

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            List {
                Section {
                    stationContent
                } header: {
                    Text("nearby.police.header", bundle: .module)
                } footer: {
                    Text(region.isUnitedKingdom ? "nearby.police.footer.uk" : "nearby.police.footer.elsewhere", bundle: .module)
                }

                if region.isUnitedKingdom {
                    Section {
                        NavigationLink {
                            RefugesScreen(pack: pack, detected: model.detectedNation)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("nearby.refuges.link", bundle: .module).font(.headline)
                                Text("nearby.refuges.detail", bundle: .module)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("nearby.refuges")
                    }
                } else {
                    // Refuge routes are UK services; outside the UK they are withheld.
                    Section { NonUKNotice() }
                }
            }
            .navigationTitle(Text("tab.nearby", bundle: .module))
            .refreshable { await model.refresh() }
            .task { if model.state == .idle { await model.refresh() } }
            .onChange(of: scenePhase) { _, phase in
                // Back from Settings, permission may have changed.
                guard phase == .active else { return }
                switch model.state {
                case .needsPermission, .locationOff, .locationApproximate, .locationRestricted:
                    Task { await model.refresh() }
                default:
                    break
                }
            }
            .alert(Text("nearby.directionsFailed", bundle: .module), isPresented: $model.directionsFailed) {
                Button(Strings.localized("help.ok"), role: .cancel) {}
            }
            .alert(Text(Strings.localized("alert.location.settingsFailed")), isPresented: $settingsFailed) {
                Button(Strings.localized("help.ok"), role: .cancel) {}
            }
        }
    }

    @ViewBuilder
    private var stationContent: some View {
        switch model.state {
        case let .found(found):
            StationMap(found: found)
            ForEach(Array(found.stations.enumerated()), id: \.element.id) { index, station in
                StationRow(
                    station: station,
                    metres: Distance.metres(from: found.origin, to: station.coordinate),
                    route: index == 0 ? found.route : nil,
                    isNearest: index == 0
                ) {
                    Task { await model.openDirections(to: station) }
                }
            }
        case .locating, .searching, .idle:
            HStack(spacing: Design.Space.tight) {
                ProgressView()
                Text(NearbyCopy.message(for: model.state) ?? "")
            }
        default:
            VStack(alignment: .leading, spacing: Design.Space.tight) {
                Text(NearbyCopy.message(for: model.state) ?? "").fixedSize(horizontal: false, vertical: true)
                action
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var action: some View {
        switch model.state {
        case .needsPermission:
            Button { Task { await model.allowLocation() } } label: {
                Text(Strings.localized("alert.location.allow")).frame(minHeight: Design.minimumTapTarget)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("nearby.allow")
        case .locationOff, .locationApproximate:
            Button {
                let settings = services.settings
                Task { @MainActor in if await settings.openAppSettings() == false { settingsFailed = true } }
            } label: {
                Text(Strings.localized("alert.location.openSettings")).frame(minHeight: Design.minimumTapTarget)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("nearby.settings")
        case .noLocation, .noneFound, .searchFailed:
            Button { Task { await model.refresh() } } label: {
                Text(Strings.localized("nearby.retry")).frame(minHeight: Design.minimumTapTarget)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("nearby.retry")
        default:
            EmptyView()
        }
    }
}

/// The person, the stations, and one walking route to the nearest. Framed to fit
/// them all. There is no default position: it is only drawn once a real fix exists.
private struct StationMap: View {

    let found: NearbyModel.Found

    var body: some View {
        Map(initialPosition: .automatic) {
            UserAnnotation()
            ForEach(found.stations) { station in
                Marker(
                    station.name ?? Strings.localized("nearby.station.unnamed"),
                    systemImage: "shield.lefthalf.filled",
                    coordinate: CLLocationCoordinate2D(latitude: station.coordinate.latitude, longitude: station.coordinate.longitude)
                )
            }
            if let route = found.route {
                MapPolyline(coordinates: route.path.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
                    .stroke(.blue, lineWidth: 5)
            }
        }
        .frame(minHeight: 260)
        .listRowInsets(EdgeInsets())
        .accessibilityLabel(Text("nearby.map.label", bundle: .module))
        .accessibilityIdentifier("nearby.map")
    }
}

private struct StationRow: View {

    let station: NearbyPlace
    let metres: Double
    let route: WalkingRoute?
    let isNearest: Bool
    let onDirections: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Space.tight) {
            Text(station.name ?? Strings.localized("nearby.station.unnamed"))
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text(String(format: Strings.localized("nearby.station.distance"), NearbyCopy.distance(metres)))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if isNearest {
                if let route {
                    Text(String(format: Strings.localized("nearby.route.walk"), NearbyCopy.walk(route.expectedSeconds)))
                        .font(.subheadline)
                } else {
                    Text("nearby.route.unavailable", bundle: .module)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button(action: onDirections) {
                Label { Text("nearby.directions", bundle: .module) } icon: { Image(systemName: "figure.walk") }
                    .frame(minHeight: Design.minimumTapTarget)
            }
            .buttonStyle(.bordered)
            .accessibilityHint(Text("nearby.directions.hint", bundle: .module))
            .accessibilityIdentifier("nearby.directions.\(station.id)")
        }
        .padding(.vertical, 2)
        .accessibilityIdentifier("nearby.station.\(station.id)")
    }
}
