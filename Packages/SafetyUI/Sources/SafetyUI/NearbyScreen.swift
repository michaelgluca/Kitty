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
    /// Whether this tab is on screen. The scene becoming active refreshes only a
    /// tab someone is looking at: Nearby searches while it is open, not in the
    /// background of another tab (ADR-0013).
    @State private var isShown = false

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            List {
                Section {
                    stationContent
                } header: {
                    Text("nearby.police.header", bundle: .module)
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
            // Each time the tab appears, and each time the app comes back with it
            // open, the model decides whether to look again: always without a
            // result (a permission changed in Settings, a signal came back), and for
            // a result once it is stale. A current result is not searched again.
            .task { await model.refreshIfNeeded() }
            .onAppear { isShown = true }
            .onDisappear { isShown = false }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active, isShown else { return }
                Task { await model.refreshIfNeeded() }
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
            results(found)
        case .locating, .searching, .idle:
            if let previous = model.previousResult {
                // A refresh is replacing a result: keep it on screen rather than
                // blanking, but say plainly, above it, that it is from the last
                // search. The model drops it the moment the refresh ends, so a
                // failure replaces it rather than leaving it looking current.
                progressRow(NearbyCopy.updating)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("nearby.updating")
                results(previous)
            } else {
                progressRow(NearbyCopy.message(for: model.state))
            }
        default:
            VStack(alignment: .leading, spacing: Design.Space.tight) {
                // Every state reaching `default` has real copy — `.idle` and
                // `.found` are handled above — but this renders nothing rather than
                // an empty label if that were ever not true, instead of forcing it.
                if let message = NearbyCopy.message(for: model.state) {
                    Text(message).fixedSize(horizontal: false, vertical: true)
                }
                action
            }
            .padding(.vertical, 2)
            if NearbyCopy.showsCounterNote(in: model.state) {
                PoliceCounterNote(isUnitedKingdom: region.isUnitedKingdom)
            }
        }
    }

    private func progressRow(_ text: String?) -> some View {
        HStack(spacing: Design.Space.tight) {
            ProgressView()
            if let text {
                Text(text).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func results(_ found: NearbyModel.Found) -> some View {
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
            if index == 0 {
                // Directly after the nearest station, not as a footer below the
                // map and up to five rows: it must stay on screen, without
                // scrolling, whenever a station is shown.
                PoliceCounterNote(isUnitedKingdom: region.isUnitedKingdom)
            }
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
                Marker(NearbyCopy.name(of: station), systemImage: "shield.lefthalf.filled", coordinate: station.coordinate.clCoordinate)
            }
            if let route = found.route {
                MapPolyline(coordinates: route.path.map(\.clCoordinate))
                    .stroke(.blue, lineWidth: 5)
            }
        }
        .frame(minHeight: 260)
        .listRowInsets(EdgeInsets())
        .accessibilityLabel(Text("nearby.map.label", bundle: .module))
        .accessibilityIdentifier("nearby.map")
    }
}

/// Front counters keep limited hours, and 999 is the number in an emergency (UK).
/// Kept as its own row — directly after the nearest station, or directly after the
/// message when none is shown — rather than a section footer: see `stationContent`
/// and `NearbyCopy.showsCounterNote(in:)`.
private struct PoliceCounterNote: View {
    let isUnitedKingdom: Bool

    var body: some View {
        Text(NearbyCopy.counterNote(isUnitedKingdom: isUnitedKingdom))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 2)
            .accessibilityIdentifier("nearby.counterNote")
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
            // The row's own identifier lives here, on a plain label, rather than on
            // the enclosing VStack: a List row whose CONTAINER carries an
            // accessibilityIdentifier has that identifier bleed onto every
            // descendant XCUITest reports — including the Directions button below,
            // which then loses its own more specific identifier. Keeping it on a
            // single non-interactive leaf still lets a UI test find "this station's
            // row" without swallowing the button's identity.
            Text(NearbyCopy.name(of: station))
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("nearby.station.\(station.id)")
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
    }
}

private extension Coordinate {
    var clCoordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}
