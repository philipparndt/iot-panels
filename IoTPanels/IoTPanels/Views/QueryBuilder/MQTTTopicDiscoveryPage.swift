import SwiftUI
import Combine

#if canImport(CocoaMQTT)

struct MQTTTopicDiscoveryPage: View {
    let dataSource: DataSource
    @Binding var selectedTopic: String
    @Binding var discoveredFields: [String]
    @Environment(\.dismiss) private var dismiss

    @State private var discoveredTopics: [(topic: String, count: Int)] = []
    @State private var topicCounts: [String: Int] = [:]
    @State private var topicPayloads: [String: Set<String>] = [:]  // topic -> collected field names
    @State private var isRunning = true
    @State private var cancellable: AnyCancellable?
    @State private var searchText = ""

    private var baseTopic: String {
        let bt = dataSource.wrappedMqttBaseTopic
        return bt.isEmpty ? "#" : bt
    }

    private var filteredTopics: [(topic: String, count: Int)] {
        let sorted = discoveredTopics.sorted { $0.topic < $1.topic }
        if searchText.isEmpty { return sorted }
        let query = searchText.lowercased()
        return sorted.filter { $0.topic.lowercased().contains(query) }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: isRunning ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                        .foregroundStyle(isRunning ? .green : .secondary)
                    Text(baseTopic)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(topicCounts.count) topics")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    isRunning.toggle()
                    if isRunning { startDiscovery() } else { stopDiscovery() }
                } label: {
                    Label(isRunning ? "Stop" : "Resume", systemImage: isRunning ? "stop.fill" : "play.fill")
                }
            }

            Section {
                if filteredTopics.isEmpty && isRunning {
                    HStack {
                        ProgressView()
                        Text("Discovering topics...")
                            .foregroundStyle(.secondary)
                            .padding(.leading, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                ForEach(filteredTopics, id: \.topic) { item in
                    let fields = topicPayloads[item.topic] ?? []
                    Button {
                        selectedTopic = item.topic
                        discoveredFields = Array(fields).sorted()
                        stopDiscovery()
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.topic)
                                    .font(.body.monospaced())
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                if !fields.isEmpty {
                                    Text(fields.sorted().joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Text("\(item.count)")
                                .font(.caption.monospacedDigit())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .clipShape(Capsule())
                            if selectedTopic == item.topic {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Filter topics")
        .navigationTitle("Select Topic")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { startDiscovery() }
        .onDisappear { stopDiscovery() }
    }

    private func startDiscovery() {
        let service = MQTTService(dataSource: dataSource)
        let manager = MQTTConnectionManager.shared
        let key = service.connectionKey

        Task {
            _ = try? await manager.getMessages(for: service, topic: baseTopic, rangeSeconds: 0)
        }

        cancellable = manager.messageReceived
            .filter { $0.connectionKey == key }
            .receive(on: DispatchQueue.main)
            .sink { msg in
                guard isRunning else { return }
                topicCounts[msg.topic, default: 0] += 1
                discoveredTopics = topicCounts.map { (topic: $0.key, count: $0.value) }

                // Extract field names from JSON payload
                let fields = extractFieldNames(from: msg.payload)
                if !fields.isEmpty {
                    if topicPayloads[msg.topic] == nil {
                        topicPayloads[msg.topic] = fields
                    } else {
                        topicPayloads[msg.topic]?.formUnion(fields)
                    }
                }
            }
    }

    private func stopDiscovery() {
        cancellable?.cancel()
        cancellable = nil
    }

    private func extractFieldNames(from payload: String) -> Set<String> {
        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        // Only include keys with numeric values
        return Set(json.compactMap { key, value in
            if value is NSNumber || Double("\(value)") != nil { return key }
            return nil
        })
    }
}

#endif
