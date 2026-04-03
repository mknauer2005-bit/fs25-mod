-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.











---
-- @category Utils
FenceGate = {}
local FenceGate_mt = Class(FenceGate, FenceSegment)


---
-- @param XMLSchema schema
-- @param string basePath
function FenceGate.registerXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("Fence")
    schema:register(XMLValueType.NODE_INDEX, basePath .. ".gate#node", "")
    schema:register(XMLValueType.BOOL, basePath .. ".gate#alignY", "")
    schema:register(XMLValueType.BOOL, basePath .. ".gate#hasStartPole", "")
    schema:register(XMLValueType.BOOL, basePath .. ".gate#hasEndPole", "")
    schema:register(XMLValueType.FLOAT, basePath .. ".gate#length", "length resp. width of the gate")
    schema:register(XMLValueType.FLOAT, basePath .. ".gate#depth", "depth of the gate including its doors used for overlap checking", "length / 2")
    schema:register(XMLValueType.FLOAT, basePath .. ".gate#depthOffset", "offset of overlap area", "depth / 2")
    AnimatedObject.registerXMLPaths(schema, basePath .. ".gate")
    schema:register(XMLValueType.BOOL,  basePath .. ".gate.animatedObject(?)#useAIBlockingRegion", "Flag to enable AI blocking regions for the fence gate causing GoTo-AI agents to wait in front of gate and automatically open it", false)
    schema:register(XMLValueType.FLOAT, basePath .. ".gate.animatedObject(?).aiBlockingRegion#stopDistance", "Distance the GoTo-AI agent waits in front of the blocking region", 2)
    schema:register(XMLValueType.FLOAT, basePath .. ".gate.animatedObject(?).aiBlockingRegion#openedStateAnimTime", "Normalized time [0..1] of the animation where the gate is in its opened state", 1)
end


---
-- @param XMLSchema schema
-- @param string basePath
function FenceGate.registerSavegameXMLPaths(schema, basePath)
    FenceSegment.registerSavegameXMLPaths(schema, basePath)
    schema:register(XMLValueType.BOOL, basePath .. "#reversed", "Segment is reversed")
    schema:register(XMLValueType.STRING, basePath .. ".animatedObject(?)#id")
    AnimatedObject.registerSavegameXMLPaths(schema, basePath .. ".animatedObject(?)")
end


---
-- @param integer id
-- @param table metadata
-- @param Fence fence
-- @param table? customMt
-- @return FenceGate self
function FenceGate.new(id, metadata, fence, customMt)
    local self = FenceGate:superClass().new(id, metadata, fence, customMt or FenceGate_mt)

    self.isReversed = false

    self.rootHidden = nil

    local xmlFile = XMLFile.load("fenceGateXML", self.fence.xmlFilename, Fence.xmlSchema)

    local i3dFilename = fence.i3dFilename
    local fenceI3d, sharedLoadRequestId, _ = g_i3DManager:loadSharedI3DFile(i3dFilename, false, false)

    local components = I3DUtil.loadI3DComponents(fenceI3d)
    local i3dMapping = I3DUtil.loadI3DMapping(xmlFile, nil, components)

    local gate = self.metadata.gate
    local node = xmlFile:getNode(gate.xmlKey .. "#node", nil, components, i3dMapping)
    unlink(node)
    self.rootHidden = node
    delete(fenceI3d)
    g_i3DManager:releaseSharedI3DFile(sharedLoadRequestId)

    for _, animatedObjectKey in xmlFile:iterator(gate.xmlKey .. ".animatedObject") do
        local animatedObject = AnimatedObject.new(g_server ~= nil, g_client ~= nil)
        animatedObject:load(node, xmlFile, animatedObjectKey, xmlFile:getFilename(), i3dMapping)

        animatedObject.getCanBeTriggered = Utils.overwrittenFunction(animatedObject.getCanBeTriggered, function(_, superFunc)
            if not superFunc(animatedObject) then
                return false
            end

            local playerFarmId = g_currentMission:getFarmId()

            local mission = g_missionManager:getMissionByFarmlandId(self.farmlandId)
            if mission ~= nil and g_currentMission.accessHandler:canFarmAccessOtherId(playerFarmId, mission.farmId) then
                return true
            end

            local farmlandOwnerFarmId = g_farmlandManager:getFarmlandOwner(self.farmlandId)
            if not g_currentMission.accessHandler:canFarmAccessOtherId(playerFarmId, farmlandOwnerFarmId) then
                return false
            end

            return true
        end)

        -- add blocking region if gate is wider than MIN_WIDTH_AI_BLOCKING_REGION
        local useAIBlockingRegion = xmlFile:getBool(animatedObjectKey .. "#useAIBlockingRegion")
        if useAIBlockingRegion and self.metadata.gate.length > FenceGate.MIN_WIDTH_AI_BLOCKING_REGION then
            animatedObject.aiBlockingRegion = {
                stopDistance = xmlFile:getFloat(animatedObjectKey..".aiBlockingRegion#stopDistance"),
                openedStateAnimTime = xmlFile:getFloat(animatedObjectKey..".aiBlockingRegion#openedStateAnimTime") or 1,
            }
        end

        self.animatedObjects = self.animatedObjects or {}
        table.insert(self.animatedObjects, animatedObject)
        animatedObject:register(true)
    end

    xmlFile:delete()

    return self
end


---
-- @param XMLFile xmlFile
-- @param string key
-- @param string id
-- @param Fence fence
-- @return table metadata
function FenceGate.loadMetadataFromXML(xmlFile, key, id, fence)
    local metadata = FenceSegment.loadMetadataFromXML(xmlFile, key, id, fence)

    metadata.class = FenceGate

    local gateKey = key .. ".gate"
    local length = xmlFile:getFloat(gateKey .. "#length")
    local depth = xmlFile:getFloat(gateKey .. "#depth")
    local depthOffset = xmlFile:getFloat(gateKey .. "#depthOffset")
    local alignY = xmlFile:getBool(gateKey .. "#alignY")
    local hasStartPole = xmlFile:getBool(gateKey .. "#hasStartPole", true)
    local hasEndPole = xmlFile:getBool(gateKey .. "#hasEndPole", true)

    metadata.gate = {
        xmlKey = gateKey,
        length = length,
        depth = depth,
        alignY = alignY,
        depthOffset=depthOffset,
        hasStartPole = hasStartPole,
        hasEndPole = hasEndPole,
    }

    return metadata
end



---
function FenceGate:delete()
    if self.animatedObjects ~= nil then
        for _, animatedObject in ipairs(self.animatedObjects) do
            if animatedObject.aiBlockingRegion ~= nil then
                g_currentMission.aiSystem:removeBlockingRegion(animatedObject.aiBlockingRegion.blockingRegionId)
                animatedObject.aiBlockingRegion = nil
            end
            animatedObject:delete()
        end
        self.animatedObjects = nil
    end

    if self.rootHidden ~= nil then
        delete(self.rootHidden)
        self.rootHidden = nil
    end

    g_messageCenter:unsubscribe(MessageType.FARMLAND_OWNER_CHANGED, self)

    FenceGate:superClass().delete(self)
end



---
-- @param XMLFile xmlFile
-- @param string key
-- @return boolean success
function FenceGate:loadFromXMLFile(xmlFile, key)
    self.isReversed = xmlFile:getBool(key .. "#reversed", false)

    if not FenceGate:superClass().loadFromXMLFile(self, xmlFile, key) then
        return false
    end

    for _, animatedObjectKey in xmlFile:iterator(key .. ".animatedObject") do
        local id = xmlFile:getString(animatedObjectKey .. "#id")
        for _, animatedObject in ipairs(self.animatedObjects) do
            if animatedObject.saveId == id then
                animatedObject:loadFromXMLFile(xmlFile, animatedObjectKey)
            end
        end
    end

    return true
end


---
-- @param XMLFile xmlFile
-- @param string key
-- @return boolean success
function FenceGate:saveToXMLFile(xmlFile, key)
    if not FenceGate:superClass().saveToXMLFile(self, xmlFile, key) then
        return false
    end

    if self.isReversed then
        xmlFile:setBool(key .. "#reversed", self.isReversed)
    end

    if self.animatedObjects ~= nil then
        local index = 0
        for _, animatedObject in ipairs(self.animatedObjects) do
            local animatedObjectKey = string.format("%s.animatedObject(%d)", key, index)
            xmlFile:setString(animatedObjectKey .. "#id", animatedObject.saveId)
            animatedObject:saveToXMLFile(xmlFile, animatedObjectKey)  -- TODO: usedModNames
            index = index + 1
        end
    end

    return true
end


---Called on client side on join
-- @param integer streamId stream ID
-- @param table connection connection
-- @param FenceSegment lastSegment
function FenceGate:readStream(streamId, connection, lastSegment)
    FenceGate:superClass().readStream(self, streamId, connection, lastSegment)

    self.isReversed = streamReadBool(streamId)

    if connection:getIsServer() then
        if self.animatedObjects ~= nil then
            for _, animatedObject in ipairs(self.animatedObjects) do
                local animatedObjectId = NetworkUtil.readNodeObjectId(streamId)
                animatedObject:readStream(streamId, connection)
                g_client:finishRegisterObject(animatedObject, animatedObjectId)
            end
        end
    end
end


---Called on server side on join
-- @param integer streamId stream ID
-- @param table connection connection
-- @param FenceSegment lastSegment
function FenceGate:writeStream(streamId, connection, lastSegment)
    FenceGate:superClass().writeStream(self, streamId, connection, lastSegment)

    streamWriteBool(streamId, self.isReversed)

    if not connection:getIsServer() then
        if self.animatedObjects ~= nil then
            for _, animatedObject in ipairs(self.animatedObjects) do
                NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(animatedObject))
                animatedObject:writeStream(streamId, connection)
                g_server:registerObjectInStream(connection, animatedObject)
            end
        end
    end
end
