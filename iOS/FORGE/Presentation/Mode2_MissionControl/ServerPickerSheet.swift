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
        NavigationStack {
            Form {
                // MARK: - Add server form
                Section("Add Server") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Hostname / IP", text: $hostname)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)

                    SecureField("Bearer Token (optional)", text: $bearerToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

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
        .onAppear {
            // CI/demo hook: FORGE_TEST_MC_AUTOCONNECT=1 fills the form with
            // the given FORGE_TEST_SERVER host and taps Add Server — driving
            // the SAME code path as a human typing + tapping (no env bypass).
            let env = ProcessInfo.processInfo.environment
            if env["FORGE_TEST_MC_AUTOCONNECT"] == "1" {
                let parts = (env["FORGE_TEST_SERVER"] ?? "").split(separator: ":")
                let host = parts.first.map(String.init) ?? "192.168.100.7"
                let portStr = parts.count >= 2 ? String(parts[1]) : "8090"
                name = "Host"
                hostname = host
                port = portStr
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    addServer()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        dismiss()
                    }
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
        name = discovered.name

        if case .service(let svcName, let type, let domain, _) = discovered.endpoint {
            let cleanType = type.hasSuffix(".") ? String(type.dropLast()) : type
            let cleanDomain = domain.hasSuffix(".") ? String(domain.dropLast()) : domain
            hostname = "\(svcName).\(cleanType).\(cleanDomain)"
        } else if case .hostPort(let host, _) = discovered.endpoint {
            hostname = "\(host)"
        }

        port = "8080"
        ForgeHaptics.tap()
    }

    private func removeServer(_ server: ConnectionManager.ServerConnection) {
        connectionManager.removeServer(server)
        ForgeHaptics.tap()
    }
}
