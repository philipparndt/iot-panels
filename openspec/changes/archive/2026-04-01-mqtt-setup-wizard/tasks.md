## 1. Wizard View Structure

- [x] 1.1 Create `MQTTSetupView` with step state management (currentStep enum: connect, security, test, finish)
- [x] 1.2 Add step indicator bar (matching InfluxDB2SetupView pattern)
- [x] 1.3 Add Next/Back navigation buttons per step

## 2. Step 1 — Connect

- [x] 2.1 Create connect step view with hostname, port, protocol picker, version picker, basepath
- [x] 2.2 Show common port hints (reuses MQTTServerFormView which has suggested ports)
- [x] 2.3 Validate hostname is not empty before allowing Next

## 3. Step 2 — Security

- [x] 3.1 Create security step view with TLS toggle, allow untrusted, ALPN
- [x] 3.2 Add authentication section — none, username/password
- [x] 3.3 Reuse existing MQTTServerFormView for Step 1

## 4. Step 3 — Test Connection

- [x] 4.1 Create test step that auto-runs connection test on appear
- [x] 4.2 Show loading spinner during test, success/error result after
- [x] 4.3 Add retry button on failure
- [x] 4.4 Add expandable advanced settings (client ID, discovery base topic)

## 5. Step 4 — Finish

- [x] 5.1 Create finish step showing summary of configured settings
- [x] 5.2 Save data source and dismiss on Done

## 6. Integration

- [x] 6.1 Route new MQTT data source creation to wizard in DataSourceDetailView
- [x] 6.2 Keep existing MQTTBrokerFormView for editing existing data sources

## 7. Translations

- [x] 7.1 Add translations for wizard step titles and labels across all 8 languages

## 8. Testing

- [ ] 8.1 Verify wizard completes and creates a functional MQTT data source
- [ ] 8.2 Verify editing existing MQTT source still uses the full form
- [ ] 8.3 Verify connection test works with valid and invalid brokers
