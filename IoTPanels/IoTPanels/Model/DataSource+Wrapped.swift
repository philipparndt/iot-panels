import Foundation

extension DataSource {
    var wrappedId: UUID {
        get { id ?? UUID() }
        set { id = newValue }
    }

    var wrappedName: String {
        get { name ?? "" }
        set { name = newValue }
    }

    var wrappedBackendType: BackendType {
        get { BackendType(rawValue: backendType ?? "") ?? .influxDB2 }
        set { backendType = newValue.rawValue }
    }

    var wrappedUrl: String {
        get { url ?? "" }
        set { url = newValue }
    }

    var wrappedToken: String {
        get { token ?? "" }
        set { token = newValue }
    }

    var wrappedOrganization: String {
        get { organization ?? "" }
        set { organization = newValue }
    }

    var wrappedBucket: String {
        get { bucket ?? "" }
        set { bucket = newValue }
    }

    var wrappedCreatedAt: Date {
        get { createdAt ?? Date() }
        set { createdAt = newValue }
    }

    var wrappedModifiedAt: Date {
        get { modifiedAt ?? Date() }
        set { modifiedAt = newValue }
    }
}
