GarageStorage = {}
GarageStorage.modName = g_currentModName
GarageStorage.modDirectory = g_currentModDirectory

local GS_STATIC_MOD_NAME = g_currentModName
local GS_LOG_PREFIX = "[GarageStorage]"
local GS_LOG_ENABLED = true

-- data from map onCreate before mission exists
g_garageStorageOnCreateData = g_garageStorageOnCreateData or {}

local function gsLog(stage, message)
    if not GS_LOG_ENABLED then
        return
    end

    print(string.format("%s[%s] %s", GS_LOG_PREFIX, tostring(stage or "-"), tostring(message or "")))
end

local function gsExposeGlobal(name, value)
    _G[name] = value

    local rootEnv = getfenv ~= nil and getfenv(0) or nil
    if rootEnv ~= nil then
        rootEnv[name] = value
    end
end

local function normalizeDirPath(dir)
    if dir == nil or dir == "" then
        return nil
    end

    if dir:sub(-1) ~= "/" and dir:sub(-1) ~= "\\" then
        dir = dir .. "/"
    end

    return dir
end

local function findChildByName(nodeId, wantedName)
    if nodeId == nil or wantedName == nil then
        return nil
    end

    if getName(nodeId) == wantedName then
        return nodeId
    end

    local childCount = getNumOfChildren(nodeId)
    for i = 0, childCount - 1 do
        local child = getChildAt(nodeId, i)
        local found = findChildByName(child, wantedName)
        if found ~= nil then
            return found
        end
    end

    return nil
end

local function collectDirectChildren(nodeId)
    local result = {}
    if nodeId == nil then
        return result
    end

    local childCount = getNumOfChildren(nodeId)
    for i = 0, childCount - 1 do
        table.insert(result, getChildAt(nodeId, i))
    end

    return result
end
local function resolveNodeObject(nodeId)
    if g_currentMission == nil or nodeId == nil then
        return nil
    end

    local currentNode = nodeId
    while currentNode ~= nil and currentNode ~= 0 do
        local object = g_currentMission.nodeToObject[currentNode]
        if object ~= nil then
            return object
        end

        if getParent == nil then
            break
        end

        currentNode = getParent(currentNode)
    end

    return nil
end

local function resolveVehicleFromNode(nodeId)
    local object = resolveNodeObject(nodeId)
    local current = object

    while current ~= nil do
        if current.rootNode ~= nil and current.getOwnerFarmId ~= nil and current.saveToXMLFile ~= nil and current.delete ~= nil then
            return current
        end

        current = current.parentVehicle
    end

    return nil
end


function GarageStorage_onCreate(nodeId)
    local garageId = tonumber(getUserAttribute(nodeId, "garageId"))
    local doorOpenAngle = tonumber(getUserAttribute(nodeId, "doorOpenAngle")) or 90

    local startPoint = findChildByName(nodeId, "startPoint")
    local spawnX, spawnY, spawnZ = getWorldTranslation(nodeId)
    local spawnRotY = 0

    if startPoint ~= nil then
        spawnX, spawnY, spawnZ = getWorldTranslation(startPoint)
        local _, ry, _ = getWorldRotation(startPoint)
        spawnRotY = math.deg(ry)
    else
        local _, ry, _ = getWorldRotation(nodeId)
        spawnRotY = math.deg(ry)
    end

    table.insert(g_garageStorageOnCreateData, {
        id = garageId,
        spawnX = spawnX,
        spawnY = spawnY,
        spawnZ = spawnZ,
        spawnRotY = spawnRotY,
        nodeId = nodeId,
        doorOpenAngle = doorOpenAngle
    })

    gsLog("onCreate", string.format("Queued garage node: id=%s node=%s", tostring(garageId), tostring(nodeId)))
end

local function registerOnCreateAliases()
    local modName = g_currentModName or GS_STATIC_MOD_NAME or GarageStorage.modName

    if modName ~= nil and modName ~= "" then
        _G[modName] = _G[modName] or {}
        _G[modName].GarageStorage_onCreate = GarageStorage_onCreate
    end

    gsExposeGlobal("GarageStorage_onCreate", GarageStorage_onCreate)

    _G["modOnCreate"] = _G["modOnCreate"] or {}
    _G["modOnCreate"].GarageStorage_onCreate = GarageStorage_onCreate

    local rootEnv = getfenv ~= nil and getfenv(0) or nil
    if rootEnv ~= nil then
        rootEnv.modOnCreate = rootEnv.modOnCreate or {}
        rootEnv.modOnCreate.GarageStorage_onCreate = GarageStorage_onCreate
    end

    gsLog("aliases", "Registered onCreate aliases")
end

registerOnCreateAliases()

local function ensureOnCreateAliases(reason)
    local hasGlobal = type(_G["GarageStorage_onCreate"]) == "function"
    local hasModOnCreate = _G["modOnCreate"] ~= nil and type(_G["modOnCreate"].GarageStorage_onCreate) == "function"

    if not hasGlobal or not hasModOnCreate then
        gsLog("aliases", string.format("Missing alias before %s, re-registering", tostring(reason)))
    end

    registerOnCreateAliases()
end

local GarageStorage_mt = Class(GarageStorage)

function GarageStorage.new(mission)
    local self = setmetatable({}, GarageStorage_mt)

    self.mission = mission
    self.garages = {}
    self.currentGarageId = 1
    self.pendingLoadTasks = {}
    self.triggerToGarageId = {}

    self.storageDb = { entries = {} }
    self.storageDbPath = nil

    self.playerInsideGarageId = nil
    self.actionEventId = nil

    addConsoleCommand("gsGarageClose", "Close garage and store vehicles", "consoleCloseGarage", self)
    addConsoleCommand("gsGarageOpen", "Open garage and restore vehicles", "consoleOpenGarage", self)
    addConsoleCommand("gsGarageToggle", "Toggle garage state", "consoleToggleGarage", self)
    addConsoleCommand("gsGarageDiag", "Garage diagnostics", "consoleDiag", self)

    gsLog("new", "GarageStorage created")
    return self
end

function GarageStorage:loadMap()
    ensureOnCreateAliases("loadMap")
    self.storageDbPath = self:getStorageDbPath()
    self:loadStorageDb()

    local configFile = self.modDirectory .. "xml/garages.xml"
    self:loadGarageConfig(configFile)

    -- merge map onCreate garages (priority over xml if same id)
    for _, data in ipairs(g_garageStorageOnCreateData) do
        self:addGarage(data)
    end

    -- fallback discovery: read garage nodes directly from scene graph
    self:discoverGaragesFromScene()

    -- runtime trigger setup
    for _, garage in pairs(self.garages) do
        self:setupGarageRuntime(garage)
    end

    gsLog("loadMap", string.format("Garages active: %d", self:getGarageCount()))
end

function GarageStorage:deleteMap()
    self:removeToggleActionEvent()

    for _, garage in pairs(self.garages) do
        if garage.vehicleTriggerNode ~= nil then
            removeTrigger(garage.vehicleTriggerNode)
        end
        if garage.playerTriggerNode ~= nil then
            removeTrigger(garage.playerTriggerNode)
        end
    end

    gsLog("deleteMap", "Removed triggers")
end

function GarageStorage:getGarageCount()
    local count = 0
    for _ in pairs(self.garages) do
        count = count + 1
    end
    return count
end

function GarageStorage:scanGarageNodesRecursive(nodeId, result)
    if nodeId == nil then
        return
    end

    local garageId = tonumber(getUserAttribute(nodeId, "garageId"))
    if garageId ~= nil then
        local vehicleTrigger = findChildByName(nodeId, "gs_vehicleTrigger")
        local playerTrigger = findChildByName(nodeId, "gs_playerTrigger")

        if vehicleTrigger ~= nil and playerTrigger ~= nil then
            local _, ry, _ = getWorldRotation(nodeId)
            local spawnX, spawnY, spawnZ = getWorldTranslation(nodeId)
            local startPoint = findChildByName(nodeId, "startPoint")
            if startPoint ~= nil then
                spawnX, spawnY, spawnZ = getWorldTranslation(startPoint)
                local _, sry, _ = getWorldRotation(startPoint)
                ry = sry
            end

            table.insert(result, {
                id = garageId,
                nodeId = nodeId,
                doorOpenAngle = tonumber(getUserAttribute(nodeId, "doorOpenAngle")) or 90,
                spawnX = spawnX,
                spawnY = spawnY,
                spawnZ = spawnZ,
                spawnRotY = math.deg(ry)
            })
        end
    end

    local childCount = getNumOfChildren(nodeId)
    for i = 0, childCount - 1 do
        self:scanGarageNodesRecursive(getChildAt(nodeId, i), result)
    end
end

function GarageStorage:discoverGaragesFromScene()
    local found = {}
    local rootNode = getRootNode ~= nil and getRootNode() or nil
    if rootNode ~= nil then
        self:scanGarageNodesRecursive(rootNode, found)
    end

    local added = 0
    for _, data in ipairs(found) do
        if self.garages[data.id] == nil or self.garages[data.id].nodeId == nil then
            self:addGarage(data)
            added = added + 1
        end
    end

    gsLog("discover", string.format("Scene scan found %d garage candidates, added %d", #found, added))
end

function GarageStorage:getSavegameDirectory()
    local savegameIndex = nil
    if self.mission ~= nil and self.mission.missionInfo ~= nil then
        savegameIndex = self.mission.missionInfo.savegameIndex or savegameIndex
    end
    if savegameIndex == nil and g_currentMission ~= nil and g_currentMission.missionInfo ~= nil then
        savegameIndex = g_currentMission.missionInfo.savegameIndex
    end

    local modName = g_currentModName or GS_STATIC_MOD_NAME or "FS25_SvapaAgro"
    local modSettingsDir = string.format("%smodSettings/%s/garageStorage/", getUserProfileAppPath(), tostring(modName))

    if not fileExists(modSettingsDir) then
        createFolder(modSettingsDir)
    end

    local saveSlotPart = savegameIndex ~= nil and string.format("savegame%d/", savegameIndex) or "savegameUnknown/"
    local scopedDir = normalizeDirPath(modSettingsDir .. saveSlotPart)
    if scopedDir ~= nil and not fileExists(scopedDir) then
        createFolder(scopedDir)
    end

    gsLog("savegame", "Using modSettings storage dir: " .. tostring(scopedDir))
    return scopedDir
end

function GarageStorage:getStorageDbPath()
    local saveDir = self:getSavegameDirectory()
    local dir = string.format("%sgarageStorage/", saveDir)
    if not fileExists(dir) then
        createFolder(dir)
    end
    return dir .. "garageVehicles.xml"
end

function GarageStorage:getVehiclesStorageDir()
    local saveDir = self:getSavegameDirectory()
    local baseDir = string.format("%sgarageStorage/", saveDir)

    if not fileExists(baseDir) then
        createFolder(baseDir)
    end

    -- FS25 can restrict nested custom folders in some contexts.
    -- Keep vehicle XML files in the same allowed garageStorage root folder.
    return baseDir
end

function GarageStorage:loadStorageDb()
    self.storageDb = { entries = {} }

    if self.storageDbPath == nil or not fileExists(self.storageDbPath) then
        gsLog("storageDb", "No db file yet: " .. tostring(self.storageDbPath))
        return
    end

    local xml = XMLFile.load("GarageStorageDb", self.storageDbPath, "garageStorage")
    if xml == nil then
        gsLog("storageDb", "Failed to load db file")
        return
    end

    xml:iterate("garageStorage.entries.entry", function(index, key)
        local entry = {
            entryId = xml:getString(key .. "#entryId"),
            garageId = xml:getInt(key .. "#garageId") or 0,
            farmId = xml:getInt(key .. "#farmId") or 0,
            uniqueId = xml:getString(key .. "#uniqueId"),
            displayName = xml:getString(key .. "#displayName"),
            vehicleFile = xml:getString(key .. "#vehicleFile"),
            posX = xml:getFloat(key .. "#posX"),
            posY = xml:getFloat(key .. "#posY"),
            posZ = xml:getFloat(key .. "#posZ"),
            rotX = xml:getFloat(key .. "#rotX"),
            rotY = xml:getFloat(key .. "#rotY"),
            rotZ = xml:getFloat(key .. "#rotZ")
        }

        if entry.vehicleFile ~= nil and entry.vehicleFile ~= "" then
            table.insert(self.storageDb.entries, entry)
        end
    end)

    xml:delete()
    gsLog("storageDb", string.format("Loaded entries: %d", #self.storageDb.entries))
end

function GarageStorage:saveStorageDb()
    if self.storageDbPath == nil then
        self.storageDbPath = self:getStorageDbPath()
    end

    local function xmlEscape(value)
        local s = tostring(value)
        s = s:gsub("&", "&amp;")
        s = s:gsub("\"", "&quot;")
        s = s:gsub("<", "&lt;")
        s = s:gsub(">", "&gt;")
        return s
    end

    local file = io.open(self.storageDbPath, "w")
    if file == nil then
        gsLog("storageDb", "Failed to open db file for write: " .. tostring(self.storageDbPath))
        return
    end

    file:write('<?xml version="1.0" encoding="utf-8" standalone="no" ?>\n')
    file:write('<garageStorage>\n')
    file:write('  <entries>\n')

    for _, entry in ipairs(self.storageDb.entries) do
        local attrs = {}

        if entry.entryId ~= nil then table.insert(attrs, string.format('entryId="%s"', xmlEscape(entry.entryId))) end
        if entry.garageId ~= nil then table.insert(attrs, string.format('garageId="%s"', xmlEscape(entry.garageId))) end
        if entry.farmId ~= nil then table.insert(attrs, string.format('farmId="%s"', xmlEscape(entry.farmId))) end
        if entry.uniqueId ~= nil then table.insert(attrs, string.format('uniqueId="%s"', xmlEscape(entry.uniqueId))) end
        if entry.displayName ~= nil then table.insert(attrs, string.format('displayName="%s"', xmlEscape(entry.displayName))) end
        if entry.vehicleFile ~= nil then table.insert(attrs, string.format('vehicleFile="%s"', xmlEscape(entry.vehicleFile))) end
        if entry.posX ~= nil then table.insert(attrs, string.format('posX="%s"', xmlEscape(entry.posX))) end
        if entry.posY ~= nil then table.insert(attrs, string.format('posY="%s"', xmlEscape(entry.posY))) end
        if entry.posZ ~= nil then table.insert(attrs, string.format('posZ="%s"', xmlEscape(entry.posZ))) end
        if entry.rotX ~= nil then table.insert(attrs, string.format('rotX="%s"', xmlEscape(entry.rotX))) end
        if entry.rotY ~= nil then table.insert(attrs, string.format('rotY="%s"', xmlEscape(entry.rotY))) end
        if entry.rotZ ~= nil then table.insert(attrs, string.format('rotZ="%s"', xmlEscape(entry.rotZ))) end

        file:write(string.format('    <entry %s />\n', table.concat(attrs, " ")))
    end

    file:write('  </entries>\n')
    file:write('</garageStorage>\n')
    file:close()

    gsLog("storageDb", string.format("Saved db entries: %d -> %s", #self.storageDb.entries, tostring(self.storageDbPath)))
end

function GarageStorage:loadGarageConfig(configFile)
    if not fileExists(configFile) then
        gsLog("loadGarageConfig", "No garages.xml found: " .. tostring(configFile))
        return
    end

    local xml = XMLFile.load("GarageConfig", configFile, "garages")
    if xml == nil then
        gsLog("loadGarageConfig", "Could not open garages.xml")
        return
    end

    xml:iterate("garages.garage", function(_, key)
        self:addGarage({
            id = xml:getInt(key .. "#id"),
            doorOpenAngle = xml:getFloat(key .. "#doorOpenAngle") or 90
        })
    end)

    xml:delete()
end

function GarageStorage:addGarage(data)
    local id = tonumber(data.id)
    if id == nil then
        return
    end

    local garage = self.garages[id] or {}
    garage.id = id
    garage.spawnX = tonumber(data.spawnX) or garage.spawnX or 0
    garage.spawnY = tonumber(data.spawnY) or garage.spawnY or 0
    garage.spawnZ = tonumber(data.spawnZ) or garage.spawnZ or 0
    garage.spawnRotY = tonumber(data.spawnRotY) or garage.spawnRotY or 0
    garage.nodeId = data.nodeId or garage.nodeId
    garage.doorOpenAngle = tonumber(data.doorOpenAngle) or garage.doorOpenAngle or 90

    garage.vehiclesInTrigger = garage.vehiclesInTrigger or {}
    garage.doors = garage.doors or {}
    garage.isOpen = garage.isOpen ~= nil and garage.isOpen or true

    self.garages[id] = garage
    gsLog("addGarage", string.format("Garage %d registered", id))
end

function GarageStorage:setupGarageRuntime(garage)
    if garage == nil or garage.nodeId == nil then
        gsLog("setup", "Garage runtime setup skipped: missing garage or nodeId")
        return
    end

    gsLog("setup", string.format("Setup garage %d node=%s name=%s", garage.id, tostring(garage.nodeId), tostring(getName(garage.nodeId))))

    garage.vehicleTriggerNode = findChildByName(garage.nodeId, "gs_vehicleTrigger")
    garage.playerTriggerNode = findChildByName(garage.nodeId, "gs_playerTrigger")

    if garage.vehicleTriggerNode == nil then
        gsLog("setup", string.format("Garage %d: node gs_vehicleTrigger NOT FOUND", garage.id))
    else
        gsLog("setup", string.format("Garage %d: gs_vehicleTrigger node=%s", garage.id, tostring(garage.vehicleTriggerNode)))
    end

    if garage.playerTriggerNode == nil then
        gsLog("setup", string.format("Garage %d: node gs_playerTrigger NOT FOUND", garage.id))
    else
        gsLog("setup", string.format("Garage %d: gs_playerTrigger node=%s", garage.id, tostring(garage.playerTriggerNode)))
    end

    local gatesNode = findChildByName(garage.nodeId, "gates")
    garage.doors = collectDirectChildren(gatesNode)

    for _, doorNode in ipairs(garage.doors) do
        if garage.doorBaseRot == nil then garage.doorBaseRot = {} end
        if garage.doorOpenOffset == nil then garage.doorOpenOffset = {} end

        local rx, ry, rz = getRotation(doorNode)
        garage.doorBaseRot[doorNode] = {x = rx, y = ry, z = rz}

        local defaultRotY = tonumber(garage.doorOpenAngle) or 0
        local rotXAttr = tonumber(getUserAttribute(doorNode, "gsOpenRotX") or getUserAttribute(doorNode, "rotX") or 0)
        local rotYAttr = tonumber(getUserAttribute(doorNode, "gsOpenRotY") or getUserAttribute(doorNode, "rotY") or defaultRotY)
        local rotZAttr = tonumber(getUserAttribute(doorNode, "gsOpenRotZ") or getUserAttribute(doorNode, "rotZ") or 0)

        garage.doorOpenOffset[doorNode] = {
            x = math.rad(rotXAttr),
            y = math.rad(rotYAttr),
            z = math.rad(rotZAttr)
        }

        gsLog("setup", string.format("Garage %d door '%s' openOffset=(%.1f, %.1f, %.1f)", garage.id, tostring(getName(doorNode)), rotXAttr, rotYAttr, rotZAttr))
    end

    if garage.vehicleTriggerNode ~= nil then
        self.triggerToGarageId[garage.vehicleTriggerNode] = garage.id
        addTrigger(garage.vehicleTriggerNode, "onVehicleTriggerCallback", self)
        gsLog("setup", string.format("Garage %d vehicle trigger added", garage.id))
    end

    if garage.playerTriggerNode ~= nil then
        self.triggerToGarageId[garage.playerTriggerNode] = garage.id
        addTrigger(garage.playerTriggerNode, "onPlayerTriggerCallback", self)
        gsLog("setup", string.format("Garage %d player trigger added", garage.id))
    end

    if garage.vehicleTriggerNode ~= nil then
        garage.spawnX, garage.spawnY, garage.spawnZ = getWorldTranslation(garage.vehicleTriggerNode)
        local _, ry, _ = getWorldRotation(garage.vehicleTriggerNode)
        garage.spawnRotY = math.deg(ry)
    end
end

function GarageStorage:onVehicleTriggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
    gsLog("vehicleTrigger", string.format("Callback fired trigger=%s actor=%s shape=%s enter=%s leave=%s stay=%s", tostring(triggerId), tostring(otherActorId), tostring(otherShapeId), tostring(onEnter), tostring(onLeave), tostring(onStay)))

    local garageId = self.triggerToGarageId[triggerId]
    local garage = self.garages[garageId]
    if garage == nil then
        return
    end

    local vehicle = resolveVehicleFromNode(otherShapeId)
    if vehicle == nil then
        vehicle = resolveVehicleFromNode(otherActorId)
    end

    if vehicle ~= nil then
        if onEnter or onStay then
            garage.vehiclesInTrigger[vehicle] = true
        end

        if onEnter then
            gsLog("vehicleTrigger", string.format("Garage %d vehicle entered: %s", garageId, tostring(vehicle.uniqueId)))
        elseif onLeave then
            garage.vehiclesInTrigger[vehicle] = nil
            gsLog("vehicleTrigger", string.format("Garage %d vehicle left: %s", garageId, tostring(vehicle.uniqueId)))
        end
    elseif onEnter or onStay then
        gsLog("vehicleTrigger", string.format("Garage %d callback had no vehicle object for actor=%s shape=%s", garageId, tostring(otherActorId), tostring(otherShapeId)))
    end
end

function GarageStorage:onPlayerTriggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
    gsLog("playerTrigger", string.format("Callback fired trigger=%s actor=%s shape=%s enter=%s leave=%s stay=%s", tostring(triggerId), tostring(otherActorId), tostring(otherShapeId), tostring(onEnter), tostring(onLeave), tostring(onStay)))

    local garageId = self.triggerToGarageId[triggerId]
    if garageId == nil then
        return
    end

    local player = g_currentMission ~= nil and g_currentMission.player or nil
    local localPlayer = g_localPlayer
    local objectFromShape = resolveNodeObject(otherShapeId)
    local objectFromActor = resolveNodeObject(otherActorId)

    local isPlayer = false
    if player ~= nil and (otherShapeId == player.rootNode or otherActorId == player.rootNode) then
        isPlayer = true
    elseif objectFromShape ~= nil and (objectFromShape == player or objectFromShape == localPlayer) then
        isPlayer = true
    elseif objectFromActor ~= nil and (objectFromActor == player or objectFromActor == localPlayer) then
        isPlayer = true
    end

    if not isPlayer then
        return
    end

    if onEnter then
        self.playerInsideGarageId = garageId
        gsLog("playerTrigger", string.format("Player entered garage trigger: %d (actor=%s shape=%s)", garageId, tostring(otherActorId), tostring(otherShapeId)))
    elseif onLeave then
        if self.playerInsideGarageId == garageId then
            self.playerInsideGarageId = nil
            self:removeToggleActionEvent()
            gsLog("playerTrigger", string.format("Player left garage trigger: %d (actor=%s shape=%s)", garageId, tostring(otherActorId), tostring(otherShapeId)))
        end
    end
end

function GarageStorage:getGarageActionText(garage)
    if garage ~= nil and garage.isOpen then
        return "Закрыть гараж"
    end

    return "Открыть гараж"
end

function GarageStorage:getCurrentFarmId()
    if g_currentMission ~= nil and g_currentMission.missionDynamicInfo ~= nil and g_currentMission.missionDynamicInfo.isMultiplayer and g_localPlayer ~= nil then
        return g_localPlayer:getFarmId()
    end

    return 0
end

function GarageStorage:getStoredEntriesForGarage(garageId, farmId)
    local result = {}

    for _, entry in ipairs(self.storageDb.entries) do
        if entry.garageId == garageId and entry.farmId == farmId then
            table.insert(result, entry)
        end
    end

    return result
end

function GarageStorage:removeToggleActionEvent()
    if self.actionEventId ~= nil and g_inputBinding ~= nil then
        g_inputBinding:removeActionEvent(self.actionEventId)
        self.actionEventId = nil
    end
end

function GarageStorage:onActionToggleGarage(actionName, inputValue, callbackState, isAnalog)
    if self.playerInsideGarageId ~= nil then
        self:toggleGarage(self.playerInsideGarageId)
    end

    return true
end

function GarageStorage:update(dt)
    local garageId = self.playerInsideGarageId

    if garageId == nil then
        self:removeToggleActionEvent()
        return
    end

    local garage = self.garages[garageId]
    if garage == nil or g_inputBinding == nil then
        self:removeToggleActionEvent()
        return
    end

    if self.actionEventId == nil then
        local _, eventId = g_inputBinding:registerActionEvent(InputAction.ACTIVATE_OBJECT, self, self.onActionToggleGarage, false, true, false, true, nil)
        self.actionEventId = eventId

        if self.actionEventId ~= nil then
            g_inputBinding:setActionEventTextVisibility(self.actionEventId, true)
            g_inputBinding:setActionEventActive(self.actionEventId, true)
            gsLog("action", string.format("Registered action event id=%s for garage=%s", tostring(self.actionEventId), tostring(garageId)))
        else
            gsLog("action", "Failed to register action event")
        end
    end

    if self.actionEventId ~= nil then
        g_inputBinding:setActionEventText(self.actionEventId, self:getGarageActionText(garage))
        g_inputBinding:setActionEventActive(self.actionEventId, true)
    end

    if garage ~= nil and not garage.isOpen then
        local entries = self:getStoredEntriesForGarage(garageId, self:getCurrentFarmId())
        if #entries > 0 then
            setTextColor(1, 1, 1, 1)
            setTextAlignment(RenderText.ALIGN_CENTER)
            renderText(0.5, 0.245, 0.018, string.format("Техника в гараже: %d", #entries))

            local maxRows = math.min(#entries, 3)
            for i = 1, maxRows do
                local row = entries[i]
                local name = row.displayName or row.uniqueId or "Unknown"
                renderText(0.5, 0.225 - (i - 1) * 0.018, 0.015, string.format("• %s", tostring(name)))
            end

            setTextAlignment(RenderText.ALIGN_LEFT)
        end
    end
end

function GarageStorage:applyDoorState(garage, isOpen)
    if garage == nil or garage.doors == nil then
        return
    end

    for _, doorNode in ipairs(garage.doors) do
        local base = garage.doorBaseRot ~= nil and garage.doorBaseRot[doorNode] or nil
        local offset = garage.doorOpenOffset ~= nil and garage.doorOpenOffset[doorNode] or nil
        if base ~= nil then
            local ox = offset ~= nil and offset.x or 0
            local oy = offset ~= nil and offset.y or math.rad(garage.doorOpenAngle or 0)
            local oz = offset ~= nil and offset.z or 0

            if isOpen then
                setRotation(doorNode, base.x + ox, base.y + oy, base.z + oz)
            else
                setRotation(doorNode, base.x, base.y, base.z)
            end
        end
    end
end

function GarageStorage:getVehicleDisplayName(vehicle)
    if vehicle == nil then
        return "Unknown"
    end

    local name = nil
    if vehicle.getName ~= nil then
        name = vehicle:getName()
    end

    if (name == nil or name == "") and vehicle.configFileName ~= nil and g_storeManager ~= nil then
        local storeItem = g_storeManager:getItemByXMLFilename(vehicle.configFileName)
        if storeItem ~= nil then
            local brandTitle = ""
            if g_brandManager ~= nil and storeItem.brandIndex ~= nil then
                local brand = g_brandManager:getBrandByIndex(storeItem.brandIndex)
                if brand ~= nil and brand.title ~= nil then
                    brandTitle = brand.title .. " "
                end
            end
            name = brandTitle .. (storeItem.name or "")
        end
    end

    return (name ~= nil and name ~= "") and name or tostring(vehicle.uniqueId or "Unknown")
end

function GarageStorage:toggleGarage(garageId)
    local garage = self.garages[garageId]
    if garage == nil then
        gsLog("toggleGarage", "Unknown garage id: " .. tostring(garageId))
        return
    end

    if garage.isOpen then
        self:closeGarage(garageId)
        garage.isOpen = false
        self:applyDoorState(garage, false)
    else
        self:openGarage(garageId)
        garage.isOpen = true
        self:applyDoorState(garage, true)
    end

    gsLog("toggleGarage", string.format("Garage %d new state open=%s", garageId, tostring(garage.isOpen)))
end

function GarageStorage:consoleCloseGarage(garageId)
    local id = tonumber(garageId) or self.currentGarageId
    gsLog("console", string.format("gsGarageClose id=%s", tostring(id)))
    self:closeGarage(id)
    local garage = self.garages[id]
    if garage ~= nil then
        garage.isOpen = false
        self:applyDoorState(garage, false)
    end
end

function GarageStorage:consoleOpenGarage(garageId)
    local id = tonumber(garageId) or self.currentGarageId
    gsLog("console", string.format("gsGarageOpen id=%s", tostring(id)))
    self:openGarage(id)
    local garage = self.garages[id]
    if garage ~= nil then
        garage.isOpen = true
        self:applyDoorState(garage, true)
    end
end

function GarageStorage:consoleToggleGarage(garageId)
    local id = tonumber(garageId) or self.currentGarageId
    gsLog("console", string.format("gsGarageToggle id=%s", tostring(id)))
    self:toggleGarage(id)
end

function GarageStorage:consoleDiag()
    ensureOnCreateAliases("consoleDiag")

    gsLog("diag", "--- GarageStorage diagnostics start ---")
    gsLog("diag", "_G.GarageStorage_onCreate type=" .. tostring(type(_G["GarageStorage_onCreate"])))
    gsLog("diag", "_G.modOnCreate type=" .. tostring(type(_G["modOnCreate"])))
    gsLog("diag", "_G.modOnCreate.GarageStorage_onCreate type=" .. tostring(_G["modOnCreate"] ~= nil and type(_G["modOnCreate"].GarageStorage_onCreate) or "nil"))
    gsLog("diag", "Queued onCreate garages count=" .. tostring(#g_garageStorageOnCreateData))
    gsLog("diag", "Registered garages count=" .. tostring(self:getGarageCount()))
    gsLog("diag", "Storage db path=" .. tostring(self.storageDbPath))
    gsLog("diag", "Storage db entries=" .. tostring(#self.storageDb.entries))
    gsLog("diag", "--- GarageStorage diagnostics end ---")
end

function GarageStorage:getFarmIdFromVehicle(vehicle)
    if g_currentMission == nil or not g_currentMission.missionDynamicInfo.isMultiplayer then
        return 0
    end

    if g_localPlayer ~= nil then
        return g_localPlayer:getFarmId()
    end

    local farmId = 0
    if vehicle ~= nil and vehicle.getOwnerFarmId ~= nil then
        farmId = vehicle:getOwnerFarmId() or 0
    end
    if vehicle ~= nil then
        farmId = vehicle.ownerFarmId or farmId
    end
    return farmId
end

function GarageStorage:saveVehicleToFile(vehicle, entryId)
    local vehiclesDir = self:getVehiclesStorageDir()
    local vehicleFilePath = string.format("%s%s.xml", vehiclesDir, tostring(entryId))

    local xml = XMLFile.create("GarageStoredVehicleWrite", vehicleFilePath, "vehicles", Vehicle.xmlSchemaSavegame)
    if xml == nil then
        gsLog("storeVehicle", "Could not create vehicle xml file")
        return nil
    end

    local key = "vehicles.vehicle(0)"
    vehicle.currentSavegameId = 1

    local modName = vehicle.customEnvironment
    if modName ~= nil then
        xml:setValue(key .. "#modName", modName)
    end

    vehicle:saveToXMLFile(xml, key, {})
    xml:setValue(key .. "#filename", HTMLUtil.encodeToHTML(NetworkUtil.convertToNetworkFilename(vehicle.configFileName)))
    xml:save()
    xml:delete()

    if not fileExists(vehicleFilePath) then
        gsLog("storeVehicle", "Vehicle xml file was not created on disk")
        return nil
    end

    return vehicleFilePath
end

function GarageStorage:storeVehicle(vehicle, garageId, farmId)
    if vehicle == nil then
        return false
    end

    local entryId = string.format("%d_%d_%s", garageId, farmId, tostring(vehicle.uniqueId))

    for i = #self.storageDb.entries, 1, -1 do
        if self.storageDb.entries[i].entryId == entryId then
            local oldFile = self.storageDb.entries[i].vehicleFile
            if oldFile ~= nil and oldFile ~= "" and fileExists(oldFile) then
                deleteFile(oldFile)
            end
            table.remove(self.storageDb.entries, i)
        end
    end

    local vehicleFile = self:saveVehicleToFile(vehicle, entryId)
    if vehicleFile == nil then
        gsLog("storeVehicle", "Failed to save vehicle xml file")
        return false
    end

    local px, py, pz = getWorldTranslation(vehicle.rootNode)
    local rx, ry, rz = getWorldRotation(vehicle.rootNode)

    local entry = {
        entryId = entryId,
        garageId = garageId,
        farmId = farmId,
        uniqueId = tostring(vehicle.uniqueId),
        displayName = self:getVehicleDisplayName(vehicle),
        vehicleFile = vehicleFile,
        posX = px,
        posY = py,
        posZ = pz,
        rotX = rx,
        rotY = ry,
        rotZ = rz
    }

    table.insert(self.storageDb.entries, entry)
    self:saveStorageDb()

    vehicle:delete()
    gsLog("storeVehicle", string.format("Stored and removed vehicle %s", tostring(vehicle.uniqueId)))
    return true
end

function GarageStorage:closeGarage(garageId)
    local garage = self.garages[garageId]
    if garage == nil then
        return
    end

    local stored = 0
    local toStore = {}

    for vehicle, _ in pairs(garage.vehiclesInTrigger) do
        if vehicle ~= nil and vehicle.rootNode ~= nil then
            table.insert(toStore, vehicle)
        end
    end

    gsLog("closeGarage", string.format("Garage %d vehicles in trigger: %d", garageId, #toStore))

    for _, vehicle in ipairs(toStore) do
        local farmId = self:getFarmIdFromVehicle(vehicle)
        if self:storeVehicle(vehicle, garageId, farmId) then
            stored = stored + 1
            garage.vehiclesInTrigger[vehicle] = nil
        else
            gsLog("closeGarage", string.format("Failed to store vehicle %s", tostring(vehicle.uniqueId)))
        end
    end

    gsLog("closeGarage", string.format("Garage %d closed. Stored: %d", garageId, stored))
end

function GarageStorage:spawnStoredEntry(entry, garage)
    local vehicleFile = entry.vehicleFile
    if vehicleFile == nil or vehicleFile == "" or not fileExists(vehicleFile) then
        gsLog("openGarage", "Stored vehicle xml file is missing: " .. tostring(vehicleFile))
        return false
    end

    local xml = XMLFile.load("GarageStoredVehicle", vehicleFile, Vehicle.xmlSchemaSavegame)
    if xml == nil then
        gsLog("openGarage", "Cannot load stored vehicle xml: " .. tostring(vehicleFile))
        return false
    end

    local args = {
        vehicleFile = vehicleFile,
        entryId = entry.entryId,
        garage = garage,
        entry = entry
    }

    local function onLoaded(_, vehicle, vehicleLoadState, a)
        if vehicle ~= nil and vehicle.rootNode ~= nil then
            local spawnX = a.entry.posX or a.garage.spawnX
            local spawnY = a.entry.posY or a.garage.spawnY
            local spawnZ = a.entry.posZ or a.garage.spawnZ
            setWorldTranslation(vehicle.rootNode, spawnX, spawnY, spawnZ)

            if a.entry.rotX ~= nil and a.entry.rotY ~= nil and a.entry.rotZ ~= nil then
                setWorldRotation(vehicle.rootNode, a.entry.rotX, a.entry.rotY, a.entry.rotZ)
            else
                local rx, _, rz = getWorldRotation(vehicle.rootNode)
                setWorldRotation(vehicle.rootNode, rx, math.rad(a.garage.spawnRotY), rz)
            end

            for i = #self.storageDb.entries, 1, -1 do
                if self.storageDb.entries[i].entryId == a.entryId then
                    table.remove(self.storageDb.entries, i)
                end
            end
            self:saveStorageDb()

            if a.vehicleFile ~= nil and fileExists(a.vehicleFile) then
                deleteFile(a.vehicleFile)
            end

            gsLog("openGarage", "Spawned vehicle and removed db entry " .. tostring(a.entryId))
        else
            if g_currentMission ~= nil and g_currentMission.vehicleSystem ~= nil and a.entry ~= nil and a.entry.uniqueId ~= nil then
                local spawnedVehicle = g_currentMission.vehicleSystem:getVehicleByUniqueId(a.entry.uniqueId)
                if spawnedVehicle ~= nil and spawnedVehicle.rootNode ~= nil then
                    gsLog("openGarage", "Spawn state not OK but vehicle exists, cleaning db entry " .. tostring(a.entryId))

                    for i = #self.storageDb.entries, 1, -1 do
                        if self.storageDb.entries[i].entryId == a.entryId then
                            table.remove(self.storageDb.entries, i)
                        end
                    end
                    self:saveStorageDb()

                    if a.vehicleFile ~= nil and fileExists(a.vehicleFile) then
                        deleteFile(a.vehicleFile)
                    end

                    return
                end
            end

            gsLog("openGarage", "Vehicle spawn failed for entry " .. tostring(a.entryId) .. " state=" .. tostring(vehicleLoadState))
        end

    end

    g_asyncTaskManager:addTask(function()
        g_currentMission.vehicleSystem:loadFromXMLFile(xml, onLoaded, nil, args, false, false)
    end)

    return true
end

function GarageStorage:openGarage(garageId)
    local garage = self.garages[garageId]
    if garage == nil then
        return
    end

    local farmId = self:getCurrentFarmId()

    local selected = {}
    local seenEntryIds = {}
    for _, entry in ipairs(self.storageDb.entries) do
        if entry.garageId == garageId and entry.farmId == farmId and entry.entryId ~= nil and not seenEntryIds[entry.entryId] then
            if g_currentMission ~= nil and g_currentMission.vehicleSystem ~= nil and entry.uniqueId ~= nil and g_currentMission.vehicleSystem:getVehicleByUniqueId(entry.uniqueId) ~= nil then
                gsLog("openGarage", "Vehicle already exists in world, cleaning stale db entry " .. tostring(entry.entryId))
                for i = #self.storageDb.entries, 1, -1 do
                    if self.storageDb.entries[i].entryId == entry.entryId then
                        local staleFile = self.storageDb.entries[i].vehicleFile
                        if staleFile ~= nil and staleFile ~= "" and fileExists(staleFile) then
                            deleteFile(staleFile)
                        end
                        table.remove(self.storageDb.entries, i)
                    end
                end
            else
                seenEntryIds[entry.entryId] = true
                table.insert(selected, entry)
            end
        end
    end

    self:saveStorageDb()
    gsLog("openGarage", string.format("Garage %d entries to spawn: %d", garageId, #selected))

    for _, entry in ipairs(selected) do
        self:spawnStoredEntry(entry, garage)
    end
end

local function loadMission(mission)
    ensureOnCreateAliases("loadMission")

    if g_garageStorage == nil then
        g_garageStorage = GarageStorage.new(mission)

        for _, data in ipairs(g_garageStorageOnCreateData) do
            if data.id ~= nil then
                g_garageStorage:addGarage(data)
            end
        end

        addModEventListener(g_garageStorage)
    end
end

local function deleteMission()
    if g_garageStorage ~= nil then
        removeModEventListener(g_garageStorage)
        g_garageStorage = nil
    end
end

gsLog("init", "Installing mission hooks")
Mission00.load = Utils.prependedFunction(Mission00.load, loadMission)
FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, deleteMission)
