import XCTest
@testable import IOSNext

final class ArchitectureRegressionTests: XCTestCase {
    func testAreaIndexUsesDirectAreaBeforeDeviceAreaAndFallsBackToDevice() {
        let devices = [
            HomeAssistantDevice(id: "device-1", name: "Lamp", areaID: "living"),
            HomeAssistantDevice(id: "device-2", name: "TV", areaID: "bedroom")
        ]
        let registry = [
            HomeAssistantRegistryEntity(entityID: "light.direct", deviceID: "device-1", areaID: "kitchen", platform: "hue"),
            HomeAssistantRegistryEntity(entityID: "media_player.fallback", deviceID: "device-2", areaID: nil, platform: "test")
        ]

        let index = HomeAssistantLookupIndex(devices: devices, entityRegistry: registry)
        XCTAssertEqual(index.resolvedAreaID(for: "light.direct"), "kitchen")
        XCTAssertEqual(index.resolvedAreaID(for: "media_player.fallback"), "bedroom")
        XCTAssertEqual(index.entityIDs(inArea: "kitchen"), ["light.direct"])
        XCTAssertEqual(index.deviceIDs(inArea: "kitchen"), ["device-1"])
        XCTAssertEqual(index.deviceIDs(inArea: "bedroom"), ["device-2"])
    }

    func testAreaIndexDeduplicatesDevicesWithMultipleEntities() {
        let devices = [HomeAssistantDevice(id: "device-1", name: "Combo", areaID: "office")]
        let registry = [
            HomeAssistantRegistryEntity(entityID: "light.combo", deviceID: "device-1", areaID: nil, platform: "test"),
            HomeAssistantRegistryEntity(entityID: "sensor.combo", deviceID: "device-1", areaID: nil, platform: "test")
        ]
        let index = HomeAssistantLookupIndex(devices: devices, entityRegistry: registry)
        XCTAssertEqual(index.deviceIDs(inArea: "office"), ["device-1"])
        XCTAssertEqual(index.entityIDs(inArea: "office").count, 2)
    }

    func testCommunicationSnapshotDistinguishesNotLoadedFromZero() {
        let notLoaded = CommunicationHealthSnapshot(
            clientState: .offline("relay down"),
            registeredPrincipals: nil,
            registeredDevices: nil,
            queuedChunks: nil,
            queuedBytes: nil,
            deviceQueues: nil
        )
        XCTAssertEqual(notLoaded.clientTitle, "Offline")
        XCTAssertEqual(notLoaded.clientDetail, "relay down")
        XCTAssertNil(notLoaded.registeredPrincipals)

        let loadedEmpty = CommunicationHealthSnapshot(
            clientState: .online,
            registeredPrincipals: 0,
            registeredDevices: 0,
            queuedChunks: 0,
            queuedBytes: 0,
            deviceQueues: 0
        )
        XCTAssertTrue(loadedEmpty.isClientOnline)
        XCTAssertEqual(loadedEmpty.registeredPrincipals, 0)
        XCTAssertEqual(loadedEmpty.registeredDevices, 0)
    }

    func testProjectSnapshotFiltersAndSortsJobsAndPreservesMissingCI() {
        let project = AdminProjectStatusV2(
            id: "ios-next",
            title: "iOS Next",
            repository: "Bambis-Lab/ios-next",
            dispatchCount: 2,
            activeJobs: 1,
            latestDispatchState: "running",
            ci: nil
        )
        let older = AdminJobStatusV2(id: "old", ticketID: "T1", projectID: "ios-next", state: "completed", approvedBy: "owner", approvedAt: Date(timeIntervalSince1970: 100))
        let newer = AdminJobStatusV2(id: "new", ticketID: "T2", projectID: "ios-next", state: "running", approvedBy: "owner", approvedAt: Date(timeIntervalSince1970: 200))
        let other = AdminJobStatusV2(id: "other", ticketID: "T3", projectID: "fire-tv", state: "running", approvedBy: "owner", approvedAt: Date(timeIntervalSince1970: 300))

        let snapshot = ProjectPresentationSnapshot(project: project, jobs: [older, other, newer])
        XCTAssertFalse(snapshot.hasCISnapshot)
        XCTAssertEqual(snapshot.jobs.map(\.id), ["new", "old"])
        XCTAssertEqual(snapshot.repository, "Bambis-Lab/ios-next")
    }

    func testLookupIndexScalesLinearlyForLargeRegistry() {
        let count = 10_000
        let devices = (0..<count).map { HomeAssistantDevice(id: "d\($0)", name: "D\($0)", areaID: "a\($0 % 20)") }
        let registry = (0..<count).map { HomeAssistantRegistryEntity(entityID: "sensor.e\($0)", deviceID: "d\($0)", areaID: nil, platform: "test") }
        let index = HomeAssistantLookupIndex(devices: devices, entityRegistry: registry)
        XCTAssertEqual(index.registryByEntityID.count, count)
        XCTAssertEqual(index.deviceByID.count, count)
        XCTAssertEqual(index.entityIDs(inArea: "a0").count, count / 20)
    }
}
