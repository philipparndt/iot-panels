import Foundation

enum UnitCategory: String, CaseIterable, Identifiable {
    case none
    case temperature
    case humidity
    case pressure
    case power
    case energy
    case voltage
    case current
    case speed
    case distance
    case time
    case percentage
    case volume
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .temperature: return "Temperature"
        case .humidity: return "Humidity"
        case .pressure: return "Pressure"
        case .power: return "Power"
        case .energy: return "Energy"
        case .voltage: return "Voltage"
        case .current: return "Current"
        case .speed: return "Speed"
        case .distance: return "Distance"
        case .time: return "Time"
        case .percentage: return "Percentage"
        case .volume: return "Volume"
        case .custom: return "Custom"
        }
    }

    var units: [String] {
        switch self {
        case .none: return [""]
        case .temperature: return ["°C", "°F", "K"]
        case .humidity: return ["%RH", "%"]
        case .pressure: return ["hPa", "mbar", "Pa", "mmHg", "inHg", "atm", "psi"]
        case .power: return ["W", "kW", "MW", "mW", "VA", "kVA"]
        case .energy: return ["Wh", "kWh", "MWh", "J", "kJ"]
        case .voltage: return ["V", "mV", "kV"]
        case .current: return ["A", "mA", "µA"]
        case .speed: return ["m/s", "km/h", "mph", "kn"]
        case .distance: return ["m", "km", "cm", "mm", "mi", "ft", "in"]
        case .time: return ["s", "ms", "min", "h", "d"]
        case .percentage: return ["%"]
        case .volume: return ["L", "mL", "m³", "gal", "fl oz"]
        case .custom: return []
        }
    }
}
