import Foundation

struct ResourceMetrics: Equatable, Sendable {
    let deviceCount: Int
    let activeDeviceCount: Int
    let entityCount: Int
    let activeEntityCount: Int
    let unavailableEntityCount: Int
}

extension AppModel {
    func resourceMetrics(inArea areaID: String) -> ResourceMetrics {
        let areaDevices = devices(inArea: areaID)
        let areaEntities = entities(inArea: areaID)
        let activeEntities = areaEntities.filter(\.isOn)
        let deviceIDs = Set(areaDevices.map(\.id))
        let activeEntityIDs = Set(activeEntities.map(\.entityID))
        let activeDeviceIDs = Set(entityRegistry.compactMap { registry -> String? in
            guard activeEntityIDs.contains(registry.entityID),
                  let deviceID = registry.deviceID,
                  deviceIDs.contains(deviceID) else { return nil }
            return deviceID
        })
        return ResourceMetrics(
            deviceCount: areaDevices.count,
            activeDeviceCount: activeDeviceIDs.count,
            entityCount: areaEntities.count,
            activeEntityCount: activeEntities.count,
            unavailableEntityCount: areaEntities.filter { !$0.isAvailable }.count
        )
    }

    func resourceMetrics(inFloor floorID: String) -> ResourceMetrics {
        let floorAreas = areas(inFloor: floorID)
        let deviceIDs = Set(floorAreas.flatMap { devices(inArea: $0.id).map(\.id) })
        let floorEntities = floorAreas.flatMap { entities(inArea: $0.id) }
        var uniqueByID: [String: HomeAssistantEntity] = [:]
        for entity in floorEntities {
            uniqueByID[entity.entityID] = entity
        }
        let uniqueEntities = Array(uniqueByID.values)
        let activeEntities = uniqueEntities.filter(\.isOn)
        let activeEntityIDs = Set(activeEntities.map(\.entityID))
        let activeDeviceIDs = Set(entityRegistry.compactMap { registry -> String? in
            guard activeEntityIDs.contains(registry.entityID),
                  let deviceID = registry.deviceID,
                  deviceIDs.contains(deviceID) else { return nil }
            return deviceID
        })
        return ResourceMetrics(
            deviceCount: deviceIDs.count,
            activeDeviceCount: activeDeviceIDs.count,
            entityCount: uniqueEntities.count,
            activeEntityCount: activeEntities.count,
            unavailableEntityCount: uniqueEntities.filter { !$0.isAvailable }.count
        )
    }
}
