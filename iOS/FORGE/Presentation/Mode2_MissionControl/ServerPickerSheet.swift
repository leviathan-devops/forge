import SwiftUI

/// ServerPickerSheet
///
/// Per FORGE Engineering Specification §16.2.
///
/// A modal form for adding and removing Mission Control servers. Supports:
/// - Manual hostname entry (with optional port and bearer token).
/// - Listing of Bonjour-discovered servers for one-tap addition.
/// - Listing and deletion of saved servers.
struct ServerPickerSheet: View {

    @Environment(\.dismiss) private var dismiss

    @ObservedObject var connectionManager: ConnectionManager

    @State private var name: String = ""
    @State private var hostname: String = ""
    @State private var port: String = "8080"
    @State private var bearerToken: String = ""
    @State private var useTLS: Bool = false

    var body: some View {
        NavigationView {
            Form {
                // MARK: - Add server form
                Section("Add Server") {
                    TextField("Name", text: $name)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    TextField("Hostname / IP", text: $hostname)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)

                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)

                    SecureField("Bearer Token (optional)", text: $bearerToken)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    Toggle("Use TLS (wss/https)", isOn: $useTLS)

                    Button {
                        addServer()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Server")
                        }
                        .foregroundColor(canAdd ? .forgeAccent : .forgeSecondaryText)
                    }
                    .disabled(!canAdd)
                }

                // MARK: - Discovered servers
                if !connectionManager.discoveredServers.isEmpty {
                    Section("Discovered on Network") {
                        ForEach(connectionManager.discoveredServers) { server in
                            HStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .foregroundColor(.forgeAccent)
                                Text(server.name)
                                    .foregroundColor(.forgePrimaryText)
                                Spacer()
                                Button("Add") {
                                    addDiscoveredServer(server)
                                }
                                .foregroundColor(.forgeAccent)
                                .font(.forgeCaption)
                            }
                        }
                    }
                }

                // MARK: - Saved servers
                Section("Saved Servers") {
                    if connectionManager.savedServers.isEmpty {
                        Text("No servers saved")
                            .foregroundColor(.forgeSecondaryText)
                    }
                    ForEach(connectionManager.savedServers) { server in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(server.name)
                                    .foregroundColor(.forgePrimaryText)
                                Text("\(server.hostname):\(server.port)")
                                    .font(.forgeCaption)
                                    .foregroundColor(.forgeSecondaryText)
                            }
                            Spacer()
                            Button {
                                removeServer(server)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.forgeError)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Servers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.forgeAccent)
                }
            }
        }
    }

    // MARK: - Actions

    private var canAdd: Bool {
        !name.isEmpty && !hostname.isEmpty && Int(port) != nil
    }

    private func addServer() {
        guard let portInt = Int(port) else { return }
        let token = bearerToken.isEmpty ? nil : bearerToken
        let server = ConnectionManager.ServerConnection(
            name: name,
            hostname: hostname,
            port: portInt,
            bearerToken: token,
            useTLS: useTLS
        )
        connectionManager.addServer(server)
        connectionManager.refreshSessions(for: server)
        ForgeHaptics.success()

        // Reset form.
        name = ""
        hostname = ""
        port = "8080"
        bearerToken = ""
        useTLS = false
    }

    private func addDiscoveredServer(_ discovered: ConnectionManager.DiscoveredServer) {
        // We do not have a resolved hostname/port from the NWEndpoint without
        // a connection, so pre-fill the name and let the user complete the
        // host details.
        name = discovered.name
        ForgeHaptics.tap()
    }

    private func removeServer(_ server: ConnectionManager.ServerConnection) {
        connectionManager.removeServer(server)
        ForgeHaptics.tap()
    }
}
