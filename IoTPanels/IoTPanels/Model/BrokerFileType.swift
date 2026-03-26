import UniformTypeIdentifiers

extension UTType {
    /// Shared `.mqttbroker` file type — same UTI as MQTT Analyzer.
    /// Declared as `importedAs` since MQTT Analyzer is the owner (exportedAs).
    static let mqttBroker = UTType(importedAs: "de.rnd7.mqtt-broker")
}
