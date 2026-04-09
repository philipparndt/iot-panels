import SwiftUI

/// Dedicated page for MQTT broker configuration, matching MQTTAnalyzer's layout.
struct MQTTBrokerFormView: View {
    @Binding var hostname: String
    @Binding var port: String
    @Binding var protocolMethod: MQTTProtocolMethod
    @Binding var protocolVersion: MQTTProtocolVersion
    @Binding var basePath: String
    @Binding var ssl: Bool
    @Binding var untrustedSSL: Bool
    @Binding var certServerCA: MQTTCertificateFile?
    @Binding var alpn: String
    @Binding var usernamePasswordAuth: Bool
    @Binding var username: String
    @Binding var password: String
    @Binding var certificateAuth: Bool
    @Binding var certP12: MQTTCertificateFile?
    @Binding var certClientKeyPassword: String
    @Binding var clientID: String
    @Binding var baseTopic: String

    @State private var showAdvanced = false
    @State private var showCertificateHelp = false

    var body: some View {
        Form {
            MQTTServerFormView(
                hostname: $hostname,
                port: $port,
                protocolMethod: $protocolMethod,
                protocolVersion: $protocolVersion,
                basePath: $basePath,
                ssl: $ssl
            )

            MQTTTLSFormView(
                ssl: $ssl,
                untrustedSSL: $untrustedSSL,
                certServerCA: $certServerCA,
                alpn: $alpn
            )

            MQTTAuthFormView(
                usernamePasswordAuth: $usernamePasswordAuth,
                username: $username,
                password: $password,
                certificateAuth: $certificateAuth,
                certP12: $certP12,
                certClientKeyPassword: $certClientKeyPassword,
                showCertificateHelp: $showCertificateHelp
            )

            Section {
                HStack {
                    Text("Base Topic")
                    Spacer()
                    TextField("e.g. home/#", text: $baseTopic)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            } header: {
                Text("Discovery")
            } footer: {
                Text("Used to discover topics when creating queries. Leave empty to subscribe to all topics (#).")
            }

            Toggle(isOn: $showAdvanced) {
                Text("More settings")
                    .font(.headline)
            }

            if showAdvanced {
                MQTTClientIDFormView(clientID: $clientID)
            }

            Section {
                Link(destination: URL(string: "https://apps.apple.com/us/app/mqttanalyzer/id1493015317")!) {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("Powered by")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text("MQTTAnalyzer")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Broker Settings")
        .inlineNavigationTitle()
        .sheet(isPresented: $showCertificateHelp) {
            MQTTCertificateHelpSheet()
        }
    }
}
