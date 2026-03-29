import SwiftUI

private func getVersion() -> String {
    if let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
       let marketingVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
        return "\(marketingVersion).\(buildNumber)"
    } else {
        return "unknown"
    }
}

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading) {
            AboutTitleView()
                .padding([.top, .bottom])

            Text("""
            This project is open source. Contributions are welcome. Feel free to open an issue ticket and discuss new features.
            [Source Code](https://github.com/philipparndt/iot-panels), [License](https://github.com/philipparndt/iot-panels/blob/main/LICENSE), [Issue tracker](https://github.com/philipparndt/iot-panels/issues)

            **Dependencies**
            [CocoaMQTT](https://github.com/emqx/CocoaMQTT)
            """)
            .foregroundStyle(.secondary)
            .font(.footnote)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutTitleView: View {
    var body: some View {
        HStack {
            Image("AppIcon")
                .resizable()
                .frame(width: 50, height: 50)
                .cornerRadius(10)
                .shadow(radius: 10)
                .padding(.trailing)

            VStack(alignment: .leading) {
                Text("IoT Panels")
                    .font(.title)

                Text("[© 2026 Philipp Arndt](https://github.com/philipparndt)")
                    .font(.caption)
                    .foregroundStyle(.blue)

                Text(getVersion())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
        .padding([.top, .bottom])
    }
}
