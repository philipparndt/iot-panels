## ADDED Requirements

### Requirement: Auto-scale values to human-readable magnitude
The system SHALL automatically scale numeric values to the most readable unit prefix within the same unit family when displaying them in dashboards, widgets, and panels.

#### Scenario: Scale bytes to gigabytes
- **WHEN** the value is `5307109376` and the unit is "B"
- **THEN** the system SHALL display approximately "4.94" with unit "GB"

#### Scenario: Scale bytes to megabytes
- **WHEN** the value is `2097152` and the unit is "B"
- **THEN** the system SHALL display "2.00" with unit "MB"

#### Scenario: Scale small amperage to milliamps
- **WHEN** the value is `0.023` and the unit is "A"
- **THEN** the system SHALL display "23.0" with unit "mA"

#### Scenario: Scale seconds to days
- **WHEN** the value is `86400` and the unit is "s"
- **THEN** the system SHALL display "1.0" with unit "days"

### Requirement: Support common unit families
The system SHALL support auto-scaling for the following unit families:
- **Bytes**: B, KB, MB, GB, TB (1024-based)
- **Bytes rate**: B/s, KB/s, MB/s, GB/s (1024-based)
- **Bits rate**: bit/s, kbit/s, Mbit/s, Gbit/s (1000-based)
- **Watts**: mW, W, kW, MW (1000-based)
- **Watt-hours**: Wh, kWh, MWh (1000-based)
- **Volts**: µV, mV, V, kV (1000-based)
- **Amps**: µA, mA, A (1000-based)
- **Time**: ms, s, min, h, days (mixed conversion factors)
- **Frequency**: Hz, kHz, MHz, GHz (1000-based)

#### Scenario: Bytes use 1024-based scaling
- **WHEN** the value is `1024` and the unit is "B"
- **THEN** the system SHALL display "1.0" with unit "KB"

#### Scenario: Watts use 1000-based scaling
- **WHEN** the value is `1500` and the unit is "W"
- **THEN** the system SHALL display "1.50" with unit "kW"

### Requirement: Pass through unknown units unchanged
If the configured unit is not in a known unit family, the system SHALL format the value with standard rounding and display the unit as-is.

#### Scenario: Unknown unit
- **WHEN** the value is `23.5` and the unit is "°C"
- **THEN** the system SHALL display "23.5" with unit "°C" (no scaling)

#### Scenario: No unit configured
- **WHEN** the value is `42.1` and the unit is empty
- **THEN** the system SHALL display "42.1" with no unit

### Requirement: Smart decimal places
The formatted value SHALL use decimal places appropriate to the magnitude:
- Values ≥ 100: 0 decimal places
- Values ≥ 10: 1 decimal place
- Values < 10: 2 decimal places

#### Scenario: Large value formatting
- **WHEN** the scaled value is `512`
- **THEN** it SHALL be displayed as "512"

#### Scenario: Medium value formatting
- **WHEN** the scaled value is `49.3`
- **THEN** it SHALL be displayed as "49.3"

#### Scenario: Small value formatting
- **WHEN** the scaled value is `4.94`
- **THEN** it SHALL be displayed as "4.94"

### Requirement: Consistent formatting across all display surfaces
The auto-scaling formatter SHALL be used in:
- Dashboard panel views (PanelCardView)
- Home screen widgets (SingleValueWidget)
- watchOS widgets (IoTPanelsWatchWidget)

#### Scenario: Dashboard shows scaled value
- **WHEN** a dashboard panel displays a Prometheus memory query returning bytes
- **THEN** the value SHALL be auto-scaled to GB/MB as appropriate

#### Scenario: Widget shows scaled value
- **WHEN** a home screen widget displays the same query
- **THEN** the value SHALL be auto-scaled identically to the dashboard
