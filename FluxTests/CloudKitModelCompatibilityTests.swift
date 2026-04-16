import SwiftData
import XCTest
@testable import Flux

@MainActor
final class CloudKitModelCompatibilityTests: XCTestCase {
    func testSwiftDataSchemaCanLoadCloudKitBackedContainer() throws {
        let schema = Schema(ModelContainerConfiguration.modelTypes)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .private(ModelContainerConfiguration.cloudKitContainerIdentifier)
        )

        _ = try ModelContainer(for: schema, configurations: [configuration])
    }
}
