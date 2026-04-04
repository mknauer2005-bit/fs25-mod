GarageStorage = {}
GarageStorage.modName = g_currentModName
GarageStorage.modDirectory = g_currentModDirectory
GarageStorage.DEBUG = false

local GS_STATIC_MOD_NAME = g_currentModName
local GS_LOG_PREFIX = "[GarageStorage]"
local GS_LOG_ENABLED = false

-- data from map onCreate before mission exists
g_garageStorageOnCreateData = g_garageStorageOnCreateData or {}

local function gsLog(stage, message)
    if not GS_LOG_ENABLED then
        return
    end

    print(string.format("%s[%s] %s", GS_LOG_PREFIX, tostring(stage or "-"), tostring(message or "")))
end

local function gsError(stage, message)
    print(string.format("%s[%s][ERROR] %s", GS_LOG_PREFIX, tostring(stage or "-"), tostring(message or "")))
end

local function gsDiag(stage, message)
    if GarageStorage == nil or GarageStorage.DEBUG ~= true then
        return
    end
    print(string.format("%s[%s] %s", GS_LOG_PREFIX, tostring(stage or "diag"), tostring(message or "")))
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


local function gsEnsureDir(dir)
    local normalized = normalizeDirPath(dir)
    if normalized ~= nil and not fileExists(normalized) then
        createFolder(normalized)
    end
    return normalized
end

local function gsGenerateUniqueId()
    local t = os ~= nil and os.time ~= nil and os.time() or 0
    local r = math.random(100000, 999999)
    return string.format("gs_%d_%d", t, r)
end

local function gsGetParentDir(path)
    if path == nil then
        return nil
    end

    local normalized = path:gsub('\\', '/')
    local idx = normalized:match('^.*()/')
    if idx == nil then
        return nil
    end

    return normalizeDirPath(normalized:sub(1, idx - 1))
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


GarageStorageToggleGarageRequestEvent = {}
local GarageStorageToggleGarageRequestEvent_mt = Class(GarageStorageToggleGarageRequestEvent, Event)
InitEventClass(GarageStorageToggleGarageRequestEvent, "GarageStorageToggleGarageRequestEvent")

function GarageStorageToggleGarageRequestEvent.emptyNew()
    local self = Event.new(GarageStorageToggleGarageRequestEvent_mt)
    return self
end

function GarageStorageToggleGarageRequestEvent.new(garageId, farmId)
    local self = GarageStorageToggleGarageRequestEvent.emptyNew()
    self.garageId = garageId
    self.farmId = farmId
    return self
end

function GarageStorageToggleGarageRequestEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.garageId or 0)
    streamWriteInt32(streamId, self.farmId or 0)
    gsDiag("network", string.format(
        "request writeStream garageId=%s farmId=%s connection=%s",
        tostring(self.garageId),
        tostring(self.farmId),
        tostring(connection)
    ))
end

function GarageStorageToggleGarageRequestEvent:readStream(streamId, connection)
    self.garageId = streamReadInt32(streamId)
    self.farmId = streamReadInt32(streamId)
    gsDiag("network", string.format(
        "request readStream garageId=%s farmId=%s connection=%s",
        tostring(self.garageId),
        tostring(self.farmId),
        tostring(connection)
    ))
    self:run(connection)
end

function GarageStorageToggleGarageRequestEvent:run(connection)
    if g_server ~= nil and g_garageStorage ~= nil then
        gsDiag("network", string.format(
            "request event received garageId=%s farmId=%s connection=%s",
            tostring(self.garageId),
            tostring(self.farmId),
            tostring(connection)
        ))
        local primaryFarmId = tonumber(self.farmId)
        if primaryFarmId ~= nil and primaryFarmId <= 0 then
            primaryFarmId = nil
        end

        local fallbackFarmId = g_garageStorage:getFarmIdForConnection(connection)
        local resolvedFarmId = primaryFarmId
        if resolvedFarmId == nil then
            resolvedFarmId = fallbackFarmId
        end

        if primaryFarmId ~= nil and fallbackFarmId ~= nil and primaryFarmId ~= fallbackFarmId then
            gsDiag("network", string.format(
                "request farmId mismatch primary=%s fallback=%s (use primary)",
                tostring(primaryFarmId),
                tostring(fallbackFarmId)
            ))
        end

        gsDiag("network", string.format(
            "request event resolved garageId=%s primaryFarmId=%s fallbackFarmId=%s selectedFarmId=%s",
            tostring(self.garageId),
            tostring(primaryFarmId),
            tostring(fallbackFarmId),
            tostring(resolvedFarmId)
        ))
        g_garageStorage:toggleGarageForFarm(self.garageId, resolvedFarmId, connection)
    end
end

function GarageStorageToggleGarageRequestEvent.sendToServer(garageId, farmId)
    if g_client ~= nil then
        gsDiag("network", string.format(
            "request sendToServer garageId=%s farmId=%s",
            tostring(garageId),
            tostring(farmId)
        ))
        g_client:getServerConnection():sendEvent(GarageStorageToggleGarageRequestEvent.new(garageId, farmId))
    end
end

GarageStorageStateSyncEvent = {}
local GarageStorageStateSyncEvent_mt = Class(GarageStorageStateSyncEvent, Event)
InitEventClass(GarageStorageStateSyncEvent, "GarageStorageStateSyncEvent")

function GarageStorageStateSyncEvent.emptyNew()
    local self = Event.new(GarageStorageStateSyncEvent_mt)
    return self
end

function GarageStorageStateSyncEvent.new(storage)
    local self = GarageStorageStateSyncEvent.emptyNew()
    self.storage = storage
    return self
end

function GarageStorageStateSyncEvent:writeStream(streamId, connection)
    if self.storage ~= nil then
        self.storage:onWriteStream(streamId, connection)
    else
        streamWriteInt32(streamId, 0)
        streamWriteInt32(streamId, 0)
    end
end

function GarageStorageStateSyncEvent:readStream(streamId, connection)
    if g_garageStorage ~= nil then
        g_garageStorage:onReadStream(streamId, connection)
    end
end

function GarageStorageStateSyncEvent:run(connection)
end

function GarageStorageStateSyncEvent.broadcast(storage)
    if g_server ~= nil then
        g_server:broadcastEvent(GarageStorageStateSyncEvent.new(storage), nil, nil, nil)
    end
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
    self.savedGarageStates = {}
    self.activeStorageDir = nil
    self.sessionStorageDir = nil
    self.persistentStorageDir = nil
    self.persistentCareerId = nil
    self.sessionUniqueId = gsGenerateUniqueId()
    self.savegameAnchorPath = nil
    self.storageMode = "session"
    self.persistentAuthorized = false
    self.saveHooksInstalled = false
    self.saveHookRetryTimer = 0
    self.lastSavePipelineTimeMs = 0
    self.resolvedSavegameDirectory = nil
    self.anchorDeferred = false
    self.lastLoadedEntryCount = 0
    self.doorAnimationDurationMs = 3000
    self.activeDoorAnimations = {}
    self.doorOpenSample = nil
    self.doorOpenSampleLoaded = false
    self.doorCloseSample = nil
    self.doorCloseSampleLoaded = false

    self.playerInsideGarageId = nil
    self.actionEventId = nil
    self.previewOverlays = {}
    self.hudGarageEntries = nil

    addConsoleCommand("gsGarageClose", "Close garage and store vehicles", "consoleCloseGarage", self)
    addConsoleCommand("gsGarageOpen", "Open garage and restore vehicles", "consoleOpenGarage", self)
    addConsoleCommand("gsGarageToggle", "Toggle garage state", "consoleToggleGarage", self)
    addConsoleCommand("gsGarageDiag", "Garage diagnostics", "consoleDiag", self)

    gsLog("new", "GarageStorage created")
    return self
end


function GarageStorage:isServer()
    if g_currentMission ~= nil and g_currentMission.getIsServer ~= nil then
        return g_currentMission:getIsServer()
    end
    return g_server ~= nil
end

function GarageStorage:isClient()
    if g_currentMission ~= nil and g_currentMission.getIsClient ~= nil then
        return g_currentMission:getIsClient()
    end
    return g_client ~= nil
end

function GarageStorage:getFarmIdForConnection(connection)
    gsDiag("network", string.format("getFarmIdForConnection start connection=%s", tostring(connection)))

    local function pickValid(sourceName, value)
        local n = tonumber(value)
        gsDiag("network", string.format("getFarmIdForConnection check source=%s raw=%s tonumber=%s", tostring(sourceName), tostring(value), tostring(n)))
        if n ~= nil and n > 0 then
            gsDiag("network", string.format("getFarmIdForConnection resolved source=%s farmId=%s", tostring(sourceName), tostring(n)))
            return n
        end
        return nil
    end

    if connection == nil then
        gsDiag("network", "getFarmIdForConnection result=nil reason=connection nil")
        return nil
    end

    if connection.getFarmId ~= nil then
        local ok, value = pcall(function()
            return connection:getFarmId()
        end)
        gsDiag("network", string.format("getFarmIdForConnection method connection:getFarmId() ok=%s value=%s", tostring(ok), tostring(value)))
        if ok then
            local resolved = pickValid("connection:getFarmId()", value)
            if resolved ~= nil then
                return resolved
            end
        end
    end

    local resolved = pickValid("connection.farmId", connection.farmId)
    if resolved ~= nil then
        return resolved
    end

    if connection.player ~= nil then
        if connection.player.getFarmId ~= nil then
            local ok, value = pcall(function()
                return connection.player:getFarmId()
            end)
            gsDiag("network", string.format("getFarmIdForConnection method connection.player:getFarmId() ok=%s value=%s", tostring(ok), tostring(value)))
            if ok then
                resolved = pickValid("connection.player:getFarmId()", value)
                if resolved ~= nil then
                    return resolved
                end
            end
        end

        resolved = pickValid("connection.player.farmId", connection.player.farmId)
        if resolved ~= nil then
            return resolved
        end

        resolved = pickValid("connection.player.farm", connection.player.farm)
        if resolved ~= nil then
            return resolved
        end
    end

    if connection.user ~= nil then
        resolved = pickValid("connection.user.farmId", connection.user.farmId)
        if resolved ~= nil then
            return resolved
        end
    end

    if g_currentMission ~= nil then
        local userFarmIds = g_currentMission.userFarmIds
        local uniqueUserId = connection.uniqueUserId
        if userFarmIds ~= nil and uniqueUserId ~= nil then
            resolved = pickValid("g_currentMission.userFarmIds[uniqueUserId]", userFarmIds[uniqueUserId])
            if resolved ~= nil then
                return resolved
            end
        end

        local userManager = g_currentMission.userManager
        if userManager ~= nil and uniqueUserId ~= nil and userManager.getUserByUniqueId ~= nil then
            local ok, user = pcall(function()
                return userManager:getUserByUniqueId(uniqueUserId)
            end)
            gsDiag("network", string.format("getFarmIdForConnection userManager:getUserByUniqueId ok=%s user=%s", tostring(ok), tostring(user)))
            if ok and user ~= nil then
                resolved = pickValid("userManager.user.farmId", user.farmId)
                if resolved ~= nil then
                    return resolved
                end
            end
        end
    end

    gsDiag("network", "getFarmIdForConnection result=nil reason=no valid farm source")
    return nil
end

function GarageStorage:canFarmUseGarage(connection, garageId, farmId)
    gsDiag("network", string.format(
        "canFarmUseGarage check garageId=%s farmId=%s connection=%s",
        tostring(garageId),
        tostring(farmId),
        tostring(connection)
    ))

    if self.garages[garageId] == nil then
        gsDiag("network", "reject request: unknown garageId=" .. tostring(garageId))
        return false
    end

    if g_currentMission ~= nil and g_currentMission.missionDynamicInfo ~= nil and g_currentMission.missionDynamicInfo.isMultiplayer then
        if farmId == nil or farmId == 0 then
            gsDiag("network", "reject request: invalid farmId for MP garageId=" .. tostring(garageId))
            return false
        end
    end

    gsDiag("network", string.format("accept request: garageId=%s farmId=%s", tostring(garageId), tostring(farmId)))
    return true
end

function GarageStorage:getCurrentSavegameIndex()
    local savegameIndex = nil
    if self.mission ~= nil and self.mission.missionInfo ~= nil then
        savegameIndex = self.mission.missionInfo.savegameIndex or savegameIndex
    end
    if savegameIndex == nil and g_currentMission ~= nil and g_currentMission.missionInfo ~= nil then
        savegameIndex = g_currentMission.missionInfo.savegameIndex or savegameIndex
    end
    return savegameIndex
end

function GarageStorage:getLogContext()
    return string.format("mode=%s savegameIndex=%s uniqueId=%s", tostring(self.storageMode), tostring(self:getCurrentSavegameIndex()), tostring(self.persistentCareerId))
end

function GarageStorage:generateSavegameUniqueId()
    local idx = self:getCurrentSavegameIndex()
    local id = string.format("gs_%s_%s", tostring(idx or "unknown"), tostring(gsGenerateUniqueId()))
    gsDiag("anchor", "generateSavegameUniqueId result=" .. tostring(id))
    return id
end

function GarageStorage:saveSavegameAnchor(uniqueId)

    if not self:isServer() then
        return false
    end
    local anchorPath = self.savegameAnchorPath or self:getAnchorPathInSavegame()
    gsDiag("anchor", string.format("create start path=%s uniqueId=%s", tostring(anchorPath), tostring(uniqueId)))

    if anchorPath == nil or uniqueId == nil or uniqueId == "" then
        gsError("anchor", "create failed reason=invalid arguments")
        return false
    end

    local saveDir = self:getSavegameDirectory()
    if self:isTempSavegameDir(saveDir) then
        self.anchorDeferred = true
        gsDiag("anchor", "create postponed because temp dir=" .. tostring(saveDir) .. " (deferred success)")
        return true
    end

    local parent = gsGetParentDir(anchorPath)
    if parent ~= nil then
        gsEnsureDir(parent)
    end

    local success = false
    if createXMLFile ~= nil and saveXMLFile ~= nil then
        local xmlFile = createXMLFile("GarageStorageAnchor", anchorPath, "garageStorageAnchor")
        if xmlFile ~= nil then
            setXMLString(xmlFile, "garageStorageAnchor.savegameUniqueId", tostring(uniqueId))
            saveXMLFile(xmlFile)
            delete(xmlFile)
            success = fileExists(anchorPath)
        end
    end

    if not success then
        gsError("anchor", "create failed reason=createXMLFile/saveXMLFile unavailable or write failed")
    else
        self.anchorDeferred = false
    end

    gsDiag("anchor", string.format("create result exists=%s path=%s", tostring(fileExists(anchorPath)), tostring(anchorPath)))
    return success
end

function GarageStorage:initializeSavegameIdentity(createIfMissing)
    gsDiag("anchor", string.format("initializeSavegameIdentity(createIfMissing=%s) start %s", tostring(createIfMissing), self:getLogContext()))

    self.savegameAnchorPath = self:getAnchorPathInSavegame()
    gsDiag("anchor", "resolved anchor path=" .. tostring(self.savegameAnchorPath))

    local anchorId = self:readAnchorCareerId(self.savegameAnchorPath)
    if anchorId ~= nil and anchorId ~= "" then
        self.persistentCareerId = anchorId
        gsDiag("anchor", "anchor read success uniqueId=" .. tostring(anchorId))
        return true
    end

    gsDiag("anchor", "anchor missing or unreadable")
    if not createIfMissing then
        return false
    end

    local newId = self:generateSavegameUniqueId()
    local anchorOk = self:saveSavegameAnchor(newId)
    if not anchorOk then
        gsError("anchor", "failed to create anchor on save")
        return false
    end

    self.persistentCareerId = newId
    if self.anchorDeferred then
        gsDiag("anchor", "identity preserved; anchor deferred until real savegame directory is available")
    else
        gsDiag("anchor", "anchor created uniqueId=" .. tostring(newId))
    end
    return true
end

function GarageStorage:ensurePersistentStorageReady()
    gsDiag("saveHook", "ensurePersistentStorageReady start " .. self:getLogContext())

    if not self:initializeSavegameIdentity(true) then
        gsError("persistent", "ensurePersistentStorageReady failed: identity not ready")
        self.persistentAuthorized = false
        return false, false
    end

    if self.anchorDeferred then
        gsDiag("persistent", "identity ready but anchor deferred due to temp save directory; persistent activation deferred")
        self.persistentAuthorized = false
        return false, true
    end

    local dir = self:getPersistentStorageDir(self.persistentCareerId)
    if dir == nil then
        gsError("persistent", "ensurePersistentStorageReady failed: dir missing")
        self.persistentAuthorized = false
        gsDiag("persistent", "persistent allowed=denied")
        return false, false
    end

    self.persistentStorageDir = dir
    self.activeStorageDir = dir
    self.storageMode = "persistent"
    self.persistentAuthorized = true
    gsDiag("diag", "mode after initialize=" .. tostring(self.storageMode) .. " persistentAuthorized=" .. tostring(self.persistentAuthorized))
    self.storageDbPath = self:getStorageDbPath()
    gsDiag("storageDb", "selected storageDb path=" .. tostring(self.storageDbPath))

    gsDiag("persistent", string.format("dir create result path=%s exists=%s", tostring(dir), tostring(fileExists(dir))))
    gsDiag("persistent", "persistent allowed=accepted")
    local ready = self.storageDbPath ~= nil and fileExists(dir)
    gsDiag("saveHook", string.format("ensurePersistentStorageReady end ready=%s dir=%s db=%s", tostring(ready), tostring(dir), tostring(self.storageDbPath)))
    return ready, false
end


function GarageStorage:createSaveHookSmokeTestFile()
    if GarageStorage.DEBUG ~= true then
        return false
    end

    local saveDir = self:getSavegameDirectory()
    if saveDir == nil then
        gsDiag("saveHook", "smoke test create result exists=false (savegameDirectory nil)")
        return false
    end

    local testPath = saveDir .. "garageStorage_savehook_test.txt"
    gsDiag("saveHook", "smoke test create start path=" .. tostring(testPath))

    local f = io.open(testPath, "w")
    if f ~= nil then
        f:write("GarageStorage save hook smoke test\n")
        f:close()
    end

    local ok = fileExists(testPath)
    gsDiag("saveHook", "smoke test create result exists=" .. tostring(ok))
    return ok
end

function GarageStorage:installSavegameHooks()
    gsDiag("saveHook", "installSavegameHooks start")

    local mission = g_currentMission or self.mission
    if mission == nil then
        gsError("saveHook", "[WARN] no savegame hook target found (mission nil)")
        return false
    end

    if mission.__gsSaveHooksInstalled then
        gsDiag("saveHook", "Savegame hooks already installed on g_currentMission")
        self.saveHooksInstalled = true
        return true
    end

    local appendSaveToXMLOk = false
    if mission.saveToXMLFile ~= nil then
        mission.saveToXMLFile = Utils.appendedFunction(mission.saveToXMLFile, function(_, xmlFile, key, usedModNames)
            if g_garageStorage ~= nil then
                g_garageStorage:onMissionSaveToXMLFile(xmlFile, key, usedModNames)
            end
        end)
        appendSaveToXMLOk = true
    end
    gsDiag("saveHook", "append g_currentMission.saveToXMLFile " .. (appendSaveToXMLOk and "success" or "fail"))

    local appendSaveSavegameOk = false
    if mission.saveSavegame ~= nil then
        mission.saveSavegame = Utils.appendedFunction(mission.saveSavegame, function(...)
            if g_garageStorage ~= nil then
                g_garageStorage:executeSavePipeline("saveSavegame")
            end
        end)
        appendSaveSavegameOk = true
    end
    gsDiag("saveHook", "append g_currentMission.saveSavegame " .. (appendSaveSavegameOk and "success" or "fail"))

    mission.__gsSaveHooksInstalled = appendSaveToXMLOk or appendSaveSavegameOk
    self.saveHooksInstalled = mission.__gsSaveHooksInstalled

    if self.saveHooksInstalled then
        gsDiag("saveHook", "Savegame hooks installed on g_currentMission")
    else
        gsError("saveHook", "[WARN] no savegame hook target found")
    end

    return self.saveHooksInstalled
end

function GarageStorage:onMissionSaveToXMLFile(...)
    self:saveToXMLFile(...)
end

function GarageStorage:loadFromXMLFile(xmlFile, key)
    if xmlFile == nil or key == nil then
        return
    end

    local value = getXMLString(xmlFile, key .. ".garageStorage#savegameUniqueId")
    if value ~= nil and value ~= "" then
        self.persistentCareerId = value
        gsDiag("anchor", "loadFromXMLFile restored savegameUniqueId=" .. tostring(value))
    end
end


function GarageStorage:getDeferredStateDir()
    local root = self:getModSettingsStorageRoot()
    if root == nil then
        return nil
    end
    return gsEnsureDir(root .. "_deferred/")
end

function GarageStorage:getDeferredIdentityPath()
    local dir = self:getDeferredStateDir()
    if dir == nil then
        return nil
    end
    local idx = tostring(self:getCurrentSavegameIndex() or "unknown")
    return dir .. "savegame_" .. idx .. ".xml"
end

function GarageStorage:saveDeferredIdentity(uniqueId)

    if not self:isServer() then
        return false
    end
    local path = self:getDeferredIdentityPath()
    local savegameIndex = tostring(self:getCurrentSavegameIndex() or "unknown")
    gsDiag("persistent", "deferred identity save start path=" .. tostring(path) .. " uniqueId=" .. tostring(uniqueId))

    if path == nil or uniqueId == nil or uniqueId == "" then
        gsError("persistent", "deferred identity save fail: invalid arguments")
        return false
    end

    local xmlFile = nil
    if createXMLFile ~= nil and saveXMLFile ~= nil then
        xmlFile = createXMLFile("GarageStorageDeferred", path, "garageStorageDeferred")
    end

    if xmlFile == nil then
        gsError("persistent", "deferred identity save fail: createXMLFile failed path=" .. tostring(path))
        return false
    end

    setXMLString(xmlFile, "garageStorageDeferred.identity#savegameUniqueId", tostring(uniqueId))
    setXMLString(xmlFile, "garageStorageDeferred.identity#savegameIndex", savegameIndex)
    saveXMLFile(xmlFile)
    delete(xmlFile)

    local exists = fileExists(path)
    if not exists then
        gsError("persistent", "deferred identity save fail: file not found after write path=" .. tostring(path))
        return false
    end

    local verifyId = self:loadDeferredIdentity(path, true)
    if verifyId == nil or verifyId == "" then
        gsError("persistent", "deferred identity save fail: verify read failed path=" .. tostring(path))
        return false
    end

    gsDiag("persistent", "deferred identity save success exists=true uniqueId=" .. tostring(verifyId))
    return true
end

function GarageStorage:loadDeferredIdentity(overridePath, silent)
    local path = overridePath or self:getDeferredIdentityPath()
    if not silent then
        gsDiag("persistent", "loadDeferredIdentity start path=" .. tostring(path))
    end

    if path == nil or not fileExists(path) then
        if not silent then
            gsDiag("persistent", "loadDeferredIdentity missing path=" .. tostring(path))
        end
        return nil
    end

    local xmlFile = loadXMLFile("GarageStorageDeferredRead", path)
    if xmlFile == nil or xmlFile == 0 then
        if not silent then
            gsError("persistent", "loadDeferredIdentity failed to open path=" .. tostring(path))
        end
        return nil
    end

    local id = getXMLString(xmlFile, "garageStorageDeferred.identity#savegameUniqueId")
    delete(xmlFile)

    if id ~= nil and id ~= "" then
        if not silent then
            gsDiag("persistent", "loadDeferredIdentity success uniqueId=" .. tostring(id))
        end
        return id
    end

    if not silent then
        gsDiag("persistent", "loadDeferredIdentity no uniqueId in file")
    end
    return nil
end

function GarageStorage:prepareDeferredPersistentSnapshot(uniqueId)

    if not self:isServer() then
        return false
    end
    if uniqueId == nil or uniqueId == "" then
        return false
    end

    local persistentDir = self:getPersistentStorageDir(uniqueId)
    if persistentDir == nil then
        return false
    end

    gsDiag("persistent", "deferred snapshot prepare start dir=" .. tostring(persistentDir) .. " entries=" .. tostring(#self.storageDb.entries))

    for _, entry in ipairs(self.storageDb.entries) do
        if entry.vehicleFile ~= nil and entry.vehicleFile ~= "" and fileExists(entry.vehicleFile) then
            local newPath = string.format("%s%s.xml", persistentDir, tostring(entry.entryId or gsGenerateUniqueId()))
            if copyFile ~= nil then
                copyFile(entry.vehicleFile, newPath, false)
            end
            if fileExists(newPath) then
                entry.vehicleFile = newPath
            end
        end
    end

    local oldMode, oldAuth, oldDir, oldDb = self.storageMode, self.persistentAuthorized, self.activeStorageDir, self.storageDbPath
    self.storageMode = "persistent"
    self.persistentAuthorized = true
    self.activeStorageDir = persistentDir
    self.storageDbPath = self:getStorageDbPath()
    self:saveStorageDb(true)
    local ok = self.storageDbPath ~= nil and fileExists(self.storageDbPath)
    gsDiag("persistent", "deferred snapshot prepared persistentDb=" .. tostring(self.storageDbPath) .. " exists=" .. tostring(ok))

    self.storageMode, self.persistentAuthorized, self.activeStorageDir, self.storageDbPath = oldMode, oldAuth, oldDir, oldDb
    return ok
end

function GarageStorage:onWriteStream(streamId, connection)
    if not self:isServer() then
        return
    end

    local garageIds = {}
    for garageId, _ in pairs(self.garages) do table.insert(garageIds, garageId) end
    streamWriteInt32(streamId, #garageIds)
    for _, garageId in ipairs(garageIds) do
        local garage = self.garages[garageId]
        streamWriteInt32(streamId, garageId)
        streamWriteBool(streamId, garage ~= nil and garage.isOpen == true)
    end

    local entryCount = #self.storageDb.entries
    streamWriteInt32(streamId, entryCount)
    for _, entry in ipairs(self.storageDb.entries) do
        streamWriteInt32(streamId, entry.garageId or 0)
        streamWriteInt32(streamId, entry.farmId or 0)
        streamWriteString(streamId, tostring(entry.entryId or ""))
        streamWriteString(streamId, tostring(entry.uniqueId or ""))
        streamWriteString(streamId, tostring(entry.displayName or ""))
        streamWriteString(streamId, tostring(entry.imageFilename or ""))
    end
end

function GarageStorage:onReadStream(streamId, connection)
    if self:isServer() then
        return
    end

    local garageCount = streamReadInt32(streamId)
    for i = 1, garageCount do
        local garageId = streamReadInt32(streamId)
        local isOpen = streamReadBool(streamId)
        if self.garages[garageId] ~= nil then
            self.garages[garageId].isOpen = isOpen
            self:applyDoorState(self.garages[garageId], isOpen)
        end
    end

    self.storageDb.entries = {}
    self.streamEntriesReadOnly = true
    local entryCount = streamReadInt32(streamId)
    for i = 1, entryCount do
        table.insert(self.storageDb.entries, {
            garageId = streamReadInt32(streamId),
            farmId = streamReadInt32(streamId),
            entryId = streamReadString(streamId),
            uniqueId = streamReadString(streamId),
            displayName = streamReadString(streamId),
            imageFilename = streamReadString(streamId)
        })
    end
end

function GarageStorage:loadMap()
    gsDiag("diag", "mission load start")
    self.resolvedSavegameDirectory = nil
    ensureOnCreateAliases("loadMap")
    gsDiag("diag", "detected savegameDirectory=" .. tostring(self:getSavegameDirectory()))
    gsDiag("diag", "detected savegameIndex=" .. tostring(self:getCurrentSavegameIndex()))
    self:installSavegameHooks()
    self:initializeStorageMode()
    gsDiag("session", "selected session db path=" .. tostring(self:getSessionStorageDir() .. self:getSessionFilePrefix() .. "garageVehicles.xml"))
    gsDiag("persistent", "selected persistent db path=" .. tostring(self.persistentStorageDir ~= nil and (self.persistentStorageDir .. "garageVehicles.xml") or nil))
    self.storageDbPath = self:getStorageDbPath()

    if self.persistentAuthorized then
        self:loadStorageDb()
    else
        gsDiag("storageDb", "Persistent db load skipped because anchor is missing; starting empty session state")
        self.storageDb = { entries = {} }
        self.savedGarageStates = {}
        gsDiag("storageDb", "session state reset: entries=0 garageStates=0")
    end

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
    self:clearPreviewOverlays()

    for _, garage in pairs(self.garages) do
        if garage.vehicleTriggerNode ~= nil then
            removeTrigger(garage.vehicleTriggerNode)
        end
        if garage.playerTriggerNode ~= nil then
            removeTrigger(garage.playerTriggerNode)
        end
    end

    if self.doorOpenSample ~= nil then
        delete(self.doorOpenSample)
        self.doorOpenSample = nil
    end
    self.doorOpenSampleLoaded = false

    if self.doorCloseSample ~= nil then
        delete(self.doorCloseSample)
        self.doorCloseSample = nil
    end
    self.doorCloseSampleLoaded = false

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
    if self.resolvedSavegameDirectory ~= nil and self.resolvedSavegameDirectory ~= "" then
        return normalizeDirPath(self.resolvedSavegameDirectory)
    end

    local dir = nil
    local source = nil

    if g_currentMission ~= nil and g_currentMission.missionInfo ~= nil and g_currentMission.missionInfo.savegameDirectory ~= nil and g_currentMission.missionInfo.savegameDirectory ~= "" then
        dir = g_currentMission.missionInfo.savegameDirectory
        source = "missionInfo.savegameDirectory"
    end

    if dir == nil and g_currentMission ~= nil and g_currentMission.missionInfo ~= nil and g_currentMission.missionInfo.baseDirectory ~= nil and g_currentMission.missionInfo.baseDirectory ~= "" then
        local base = tostring(g_currentMission.missionInfo.baseDirectory)
        if string.find(string.lower(base), "savegame", 1, true) ~= nil then
            dir = base
            source = "missionInfo.baseDirectory"
        end
    end

    if dir == nil and g_currentMission ~= nil and g_currentMission.currentMissionInfo ~= nil and g_currentMission.currentMissionInfo.savegameDirectory ~= nil and g_currentMission.currentMissionInfo.savegameDirectory ~= "" then
        dir = g_currentMission.currentMissionInfo.savegameDirectory
        source = "currentMissionInfo.savegameDirectory"
    end

    if dir == nil and g_careerScreen ~= nil and g_careerScreen.savegameDirectory ~= nil and g_careerScreen.savegameDirectory ~= "" then
        dir = g_careerScreen.savegameDirectory
        source = "g_careerScreen.savegameDirectory"
    end

    if dir == nil and g_currentMission ~= nil and g_currentMission.savegameDirectory ~= nil and g_currentMission.savegameDirectory ~= "" then
        dir = g_currentMission.savegameDirectory
        source = "g_currentMission.savegameDirectory"
    end

    dir = normalizeDirPath(dir)
    self.resolvedSavegameDirectory = dir

    if dir ~= nil then
        gsDiag("diag", "savegameDirectory resolved from " .. tostring(source) .. "=" .. tostring(dir))
    else
        gsError("diag", "savegameDirectory unresolved from all known sources")
    end

    return dir
end

function GarageStorage:isTempSavegameDir(dir)
    local value = string.lower(tostring(dir or ""))
    return string.find(value, "tempsavegame", 1, true) ~= nil
end

function GarageStorage:getModSettingsStorageRoot()
    local modName = g_currentModName or GS_STATIC_MOD_NAME or "FS25_SvapaAgro"
    local root = string.format("%smodSettings/%s/garageStorage/", getUserProfileAppPath(), tostring(modName))
    return gsEnsureDir(root)
end

function GarageStorage:getAnchorPathInSavegame()
    local savegameDir = self:getSavegameDirectory()
    if savegameDir == nil then
        gsError("anchor", "getAnchorPathInSavegame failed: savegameDirectory unresolved")
        return nil
    end

    return savegameDir .. "garageStorageAnchor.xml"
end

function GarageStorage:readAnchorCareerId(anchorPath)
    local path = anchorPath or self:getAnchorPathInSavegame()
    gsDiag("anchor", "read anchor start path=" .. tostring(path))
    if path == nil or not fileExists(path) then
        gsDiag("anchor", "anchor missing path=" .. tostring(path))
        return nil
    end

    local xml = XMLFile.load("GarageStorageAnchorRead", path, "garageStorageAnchor")
    if xml == nil then
        gsError("anchor", "anchor read fail (xml nil) path=" .. tostring(path))
        return nil
    end

    local careerId = xml:getString("garageStorageAnchor.savegameUniqueId") or xml:getString("garageStorageAnchor#careerId")
    xml:delete()

    if careerId == nil or careerId == "" then
        gsDiag("anchor", "anchor read success but uniqueId empty")
        return nil
    end

    gsDiag("anchor", "anchor read success uniqueId=" .. tostring(careerId))
    return careerId
end

function GarageStorage:writeAnchorCareerId(careerId)
    return self:saveSavegameAnchor(careerId)
end

function GarageStorage:getPersistentStorageDir(careerId)
    if careerId == nil or careerId == "" then
        return nil
    end

    local root = self:getModSettingsStorageRoot()
    if root == nil then
        return nil
    end

    local careersDir = gsEnsureDir(root .. "careers/")
    local careerDir = gsEnsureDir(careersDir .. tostring(careerId) .. "/")
    return gsEnsureDir(careerDir .. "garageStorage/")
end

function GarageStorage:getSessionStorageDir()
    if self.sessionStorageDir ~= nil then
        gsEnsureDir(self.sessionStorageDir)
        return self.sessionStorageDir
    end

    local root = self:getModSettingsStorageRoot()
    if root == nil then
        return nil
    end

    -- keep temporary storage flat to avoid FS sandbox write issues
    self.sessionStorageDir = gsEnsureDir(root .. "_session/")
    return self.sessionStorageDir
end

function GarageStorage:getSessionFilePrefix()
    local idx = self:getCurrentSavegameIndex()
    local token = tostring(self.sessionUniqueId or gsGenerateUniqueId())
    return string.format("gs_%s_%s_", tostring(idx or "unknown"), token)
end

function GarageStorage:initializeStorageMode()
    local saveDir = self:getSavegameDirectory()
    if saveDir == nil then
        gsError("diag", "savegameDirectory unresolved during initializeStorageMode")
        self.activeStorageDir = self:getSessionStorageDir()
        self.storageMode = "session"
        self.persistentAuthorized = false
        self.storageDb = { entries = {} }
        self.savedGarageStates = {}
        return
    end

    self.savegameAnchorPath = self:getAnchorPathInSavegame()

    gsDiag("anchor", "resolved anchor path=" .. tostring(self.savegameAnchorPath))
    gsDiag("anchor", "anchor exists=" .. tostring(self.savegameAnchorPath ~= nil and fileExists(self.savegameAnchorPath)))
    local anchorCareerId = self:readAnchorCareerId(self.savegameAnchorPath)
    if anchorCareerId ~= nil then
        self.persistentCareerId = anchorCareerId
        self.persistentStorageDir = self:getPersistentStorageDir(anchorCareerId)

        if self.persistentStorageDir ~= nil then
            self.activeStorageDir = self.persistentStorageDir
            self.storageMode = "persistent"
            self.persistentAuthorized = true
            gsLog("storage", "Persistent mode for careerId=" .. tostring(anchorCareerId))
            return
        end
    end

    if (self.persistentCareerId == nil or self.persistentCareerId == "") then
        self.persistentCareerId = self:loadDeferredIdentity()
    end

    if self.persistentCareerId ~= nil and self.persistentCareerId ~= "" and not self:isTempSavegameDir(self:getSavegameDirectory()) then
        gsDiag("anchor", "anchor missing but savegameUniqueId restored from mission xml, trying to materialize anchor")
        self:saveSavegameAnchor(self.persistentCareerId)
        local retryId = self:readAnchorCareerId(self.savegameAnchorPath)
        if retryId ~= nil then
            self.persistentStorageDir = self:getPersistentStorageDir(retryId)
            if self.persistentStorageDir ~= nil then
                self.activeStorageDir = self.persistentStorageDir
                self.storageMode = "persistent"
                self.persistentAuthorized = true
                gsDiag("persistent", "persistent mode activated after anchor materialization")
                return
            end
        end
    end

    self.activeStorageDir = self:getSessionStorageDir()
    self.storageMode = "session"
    self.persistentAuthorized = false
    self.storageDb = { entries = {} }
    self.savedGarageStates = {}
    gsLog("storage", "Session-temporary mode (anchor not found)")
end

function GarageStorage:promoteSessionToPersistentStorage()

    if not self:isServer() then
        return false
    end
    gsDiag("persistent", "migrateSessionTempToPersistent start " .. self:getLogContext())
    if self.storageMode == "persistent" then
        gsDiag("persistent", "already persistent, migration skipped")
        return true
    end

    local careerId = self.persistentCareerId
    gsDiag("persistent", "migrate start entries=" .. tostring(#self.storageDb.entries))
    if careerId == nil or careerId == "" then
        careerId = gsGenerateUniqueId()
        self.persistentCareerId = careerId
    end

    gsDiag("saveHook", "initializeSavegameIdentity(createIfMissing=true) start")
    gsDiag("saveHook", "before migration session entries count=" .. tostring(#self.storageDb.entries) .. " sessionDbPath=" .. tostring(self.storageDbPath))
    local ready, deferred = self:ensurePersistentStorageReady()
    if not ready then
        if deferred then
            gsDiag("persistent", "anchor deferred due to temp save dir; migration deferred without failure")
            self:saveDeferredIdentity(self.persistentCareerId)
            self:prepareDeferredPersistentSnapshot(self.persistentCareerId)
            gsDiag("session", "cleanup skipped because migration deferred")
            return true
        end
        gsError("persistent", "persistent activation denied; migration aborted")
        return false
    end

    local persistentDir = self.persistentStorageDir
    if persistentDir == nil then
        gsError("persistent", "migration aborted: persistentStorageDir is nil after ensure")
        self.persistentAuthorized = false
        return false
    end

    self.persistentCareerId = self.persistentCareerId or careerId

    local oldDbPath = self.storageDbPath
    local oldDir = self.activeStorageDir

    self.activeStorageDir = persistentDir
    self.storageMode = "persistent"
    self.persistentAuthorized = true
    self.storageDbPath = self:getStorageDbPath()

    for _, entry in ipairs(self.storageDb.entries) do
        if entry.vehicleFile ~= nil and entry.vehicleFile ~= "" and fileExists(entry.vehicleFile) then
            local filename = entry.entryId or tostring(math.random(100000, 999999))
            local newPath = string.format("%s%s.xml", persistentDir, tostring(filename))
            if entry.vehicleFile ~= newPath then
                gsDiag("persistent", string.format("migrate file source=%s target=%s sourceExists=%s", tostring(entry.vehicleFile), tostring(newPath), tostring(fileExists(entry.vehicleFile))))
                if copyFile ~= nil then
                    copyFile(entry.vehicleFile, newPath, false)
                else
                    local source = io.open(entry.vehicleFile, "rb")
                    local target = io.open(newPath, "wb")
                    if source ~= nil and target ~= nil then
                        target:write(source:read("*all"))
                    end
                    if source ~= nil then source:close() end
                    if target ~= nil then target:close() end
                end
                entry.vehicleFile = newPath
                gsDiag("persistent", string.format("migrate file result targetExists=%s", tostring(fileExists(newPath))))
            end
        elseif entry.entryId ~= nil then
            entry.vehicleFile = string.format("%s%s.xml", persistentDir, tostring(entry.entryId))
        end
    end

    gsDiag("storageDb", "persistent db save start path=" .. tostring(self.storageDbPath))
    self:saveStorageDb(true)

    local persistentDbExists = self.storageDbPath ~= nil and fileExists(self.storageDbPath)
    gsDiag("storageDb", "persistent db save " .. (persistentDbExists and "success" or "fail") .. " exists=" .. tostring(persistentDbExists))

    if not persistentDbExists then
        gsError("persistent", "persistent db was not created; abort cleanup and keep session data")
        self.activeStorageDir = oldDir
        self.storageMode = "session"
        self.storageDbPath = oldDbPath
        self.persistentAuthorized = false
        return false
    end

    if oldDbPath ~= nil and oldDbPath ~= self.storageDbPath and fileExists(oldDbPath) then
        deleteFile(oldDbPath)
        gsDiag("session", "cleanup executed oldDbPath=" .. tostring(oldDbPath))
    else
        gsDiag("session", "cleanup skipped oldDbPath=" .. tostring(oldDbPath))
    end

    gsDiag("persistent", "migrateSessionTempToPersistent finish migratedEntries=" .. tostring(#self.storageDb.entries))
    gsLog("storage", "Session storage promoted to persistent: " .. tostring(self.persistentCareerId or careerId))
    return true
end

function GarageStorage:getStorageDbPath()
    local dir = self.activeStorageDir
    if dir == nil then
        dir = self:getSessionStorageDir()
        self.activeStorageDir = dir
    end

    if dir == nil then
        return nil
    end

    gsEnsureDir(dir)

    if self.storageMode == "session" then
        return dir .. self:getSessionFilePrefix() .. "garageVehicles.xml"
    end

    return dir .. "garageVehicles.xml"
end

function GarageStorage:getVehiclesStorageDir()
    local dir = self.activeStorageDir
    if dir == nil then
        dir = self:getSessionStorageDir()
        self.activeStorageDir = dir
    end

    if dir == nil then
        return nil
    end

    gsEnsureDir(dir)
    return dir
end

function GarageStorage:executeSavePipeline(triggerName)
    local now = g_time or 0
    if self.lastSavePipelineTimeMs ~= nil and (now - self.lastSavePipelineTimeMs) >= 0 and (now - self.lastSavePipelineTimeMs) < 500 then
        gsDiag("saveHook", "skip duplicate save pipeline trigger=" .. tostring(triggerName))
        return self.persistentAuthorized == true
    end
    self.lastSavePipelineTimeMs = now

    self.resolvedSavegameDirectory = nil
    gsDiag("saveHook", "ENTER GarageStorage appended save hook")
    gsDiag("saveHook", "trigger=" .. tostring(triggerName))
    gsDiag("saveHook", "resolved savegameDirectory=" .. tostring(self:getSavegameDirectory()))
    gsDiag("saveHook", "resolved savegameIndex=" .. tostring(self:getCurrentSavegameIndex()))
    gsDiag("saveHook", string.format("current mode=%s entries=%d garageStates=%d", tostring(self.storageMode), #self.storageDb.entries, (function(t) local c=0 for _ in pairs(t or {}) do c=c+1 end return c end)(self.savedGarageStates)))

    self:createSaveHookSmokeTestFile()
    gsDiag("saveHook", "session db path=" .. tostring(self:getStorageDbPath()))

    local ok = self:promoteSessionToPersistentStorage()
    local ready = self.persistentAuthorized == true and self.storageDbPath ~= nil
    gsDiag("saveHook", string.format("EXIT GarageStorage appended save hook ready=%s mode=%s", tostring(ready and ok), tostring(self.storageMode)))

    return ready and ok
end

function GarageStorage:saveToXMLFile(xmlFile, key, usedModNames)
    local ok = self:executeSavePipeline("saveToXMLFile")

    if xmlFile ~= nil and key ~= nil and self.persistentCareerId ~= nil and self.persistentCareerId ~= "" then
        setXMLString(xmlFile, key .. ".garageStorage#savegameUniqueId", tostring(self.persistentCareerId))
        gsDiag("anchor", "saveToXMLFile wrote savegameUniqueId into mission xml=" .. tostring(self.persistentCareerId))
    end

    return ok
end

function GarageStorage:loadStorageDb()

    if not self:isServer() then
        self.storageDb = { entries = {} }
        self.savedGarageStates = {}
        return
    end
    gsDiag("storageDb", "storage db load started " .. self:getLogContext())
    self.storageDb = { entries = {} }
    self.savedGarageStates = {}

    if not self.persistentAuthorized then
        gsLog("storageDb", "Persistent not authorized by anchor, skipping db load")
        return
    end

    if self.storageDbPath == nil then
        gsLog("storageDb", "No db path available yet")
        return
    end

    if not fileExists(self.storageDbPath) then
        gsLog("storageDb", "No db file yet: " .. tostring(self.storageDbPath))
        return
    end

    local xml = XMLFile.load("GarageStorageDb", self.storageDbPath, "garageStorage")
    if xml == nil then
        gsError("storageDb", "Failed to load db file")
        return
    end

    xml:iterate("garageStorage.entries.entry", function(index, key)
        local entry = {
            entryId = xml:getString(key .. "#entryId"),
            garageId = xml:getInt(key .. "#garageId") or 0,
            farmId = xml:getInt(key .. "#farmId") or 0,
            uniqueId = xml:getString(key .. "#uniqueId"),
            displayName = xml:getString(key .. "#displayName"),
            imageFilename = xml:getString(key .. "#imageFilename"),
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
    xml:iterate("garageStorage.garageStates.garage", function(_, key)
        local garageId = xml:getInt(key .. "#id")
        local isOpenRaw = xml:getString(key .. "#isOpen")
        if garageId ~= nil then
            self.savedGarageStates[garageId] = (isOpenRaw == "1" or isOpenRaw == "true")
        end
    end)


    xml:delete()
    self.lastLoadedEntryCount = #self.storageDb.entries
    gsDiag("storageDb", string.format("storage db load success, entries=%d garageStates=%d", #self.storageDb.entries, (function(t) local c=0 for _ in pairs(t) do c=c+1 end return c end)(self.savedGarageStates)))
end

function GarageStorage:saveStorageDb(forceWrite)

    if not self:isServer() then
        return false
    end
    forceWrite = forceWrite == true

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

    if self.storageDbPath == nil then
        gsError("storageDb", "Storage db path is nil")
        return
    end

    if self.storageMode == "persistent" and not forceWrite and #self.storageDb.entries == 0 and (self.lastLoadedEntryCount or 0) > 0 then
        gsError("storageDb", "Skip persistent db write entries=0 to prevent accidental wipe")
        return
    end

    local parentDir = gsGetParentDir(self.storageDbPath)
    if parentDir ~= nil then
        gsEnsureDir(parentDir)
    end

    gsDiag("storageDb", "db save start path=" .. tostring(self.storageDbPath) .. " " .. self:getLogContext())
    local file = io.open(self.storageDbPath, "w")
    if file == nil then
        gsError("storageDb", "Failed to open db file for write: " .. tostring(self.storageDbPath))
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
        if entry.imageFilename ~= nil then table.insert(attrs, string.format('imageFilename="%s"', xmlEscape(entry.imageFilename))) end
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

    file:write('  <garageStates>\n')
    for garageId, garage in pairs(self.garages) do
        local isOpen = garage ~= nil and garage.isOpen == true
        file:write(string.format('    <garage id="%s" isOpen="%s" />\n', xmlEscape(garageId), isOpen and "1" or "0"))
    end
    file:write('  </garageStates>\n')

    file:write('</garageStorage>\n')
    file:close()

    self.lastLoadedEntryCount = #self.storageDb.entries
    gsDiag("storageDb", string.format("db save success entries=%d path=%s exists=%s", #self.storageDb.entries, tostring(self.storageDbPath), tostring(fileExists(self.storageDbPath))))
end

function GarageStorage:loadGarageConfig(configFile)
    if not fileExists(configFile) then
        gsLog("loadGarageConfig", "No garages.xml found: " .. tostring(configFile))
        return
    end

    local xml = XMLFile.load("GarageConfig", configFile, "garages")
    if xml == nil then
        gsError("loadGarageConfig", "Could not open garages.xml")
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
    local savedState = self.savedGarageStates[id]
    if savedState ~= nil then
        garage.isOpen = savedState
    elseif garage.isOpen == nil then
        garage.isOpen = false
    end

    self.garages[id] = garage
    gsLog("addGarage", string.format("Garage %d registered", id))
end

function GarageStorage:setupGarageRuntime(garage)
    gsLog("setupGarage", string.format("setupGarageRuntime start garage.id=%s", tostring(garage ~= nil and garage.id)))

    if garage == nil then
        gsError("setupGarage", "setupGarageRuntime called with nil garage")
        return
    end

    if garage.nodeId == nil then
        gsError("setupGarage", string.format("Garage %s nodeId nil", tostring(garage.id)))
        return
    end

    gsLog("setupGarage", string.format("Setup garage %d node=%s name=%s", garage.id, tostring(garage.nodeId), tostring(getName(garage.nodeId))))

    garage.vehicleTriggerNode = findChildByName(garage.nodeId, "gs_vehicleTrigger")
    garage.playerTriggerNode = findChildByName(garage.nodeId, "gs_playerTrigger")

    gsLog("setupGarage", string.format(
        "Garage %s trigger lookup: playerNode=%s vehicleNode=%s",
        tostring(garage.id),
        tostring(garage.playerTriggerNode),
        tostring(garage.vehicleTriggerNode)
    ))

    if garage.playerTriggerNode == nil then
        gsError("setupGarage", string.format("Garage %s missing gs_playerTrigger", tostring(garage.id)))
    end

    if garage.vehicleTriggerNode == nil then
        gsError("setupGarage", string.format("Garage %s missing gs_vehicleTrigger", tostring(garage.id)))
    end

    local gatesNode = findChildByName(garage.nodeId, "gates")
    garage.doors = collectDirectChildren(gatesNode)
    garage.soundNode = findChildByName(garage.nodeId, "OpenSound")
    garage.lightNode = findChildByName(garage.nodeId, "LightGarage")
    if garage.soundNode ~= nil then
        gsLog("setupGarage", string.format("Garage %d sound node found: %s", garage.id, tostring(garage.soundNode)))
    else
        gsLog("setupGarage", string.format("Garage %d sound node not found, fallback to player position", garage.id))
    end

    if garage.lightNode ~= nil then
        gsLog("setupGarage", string.format("Garage %d light node found: %s", garage.id, tostring(garage.lightNode)))
    else
        gsLog("setupGarage", string.format("Garage %d light node not found", garage.id))
    end

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

        gsLog("setupGarage", string.format("Garage %d door '%s' openOffset=(%.1f, %.1f, %.1f)", garage.id, tostring(getName(doorNode)), rotXAttr, rotYAttr, rotZAttr))
    end

    if garage.vehicleTriggerNode ~= nil then
        self.triggerToGarageId[garage.vehicleTriggerNode] = garage.id
        gsLog("setupGarage", string.format("Garage %s addTrigger vehicle node=%s", tostring(garage.id), tostring(garage.vehicleTriggerNode)))
        addTrigger(garage.vehicleTriggerNode, "onVehicleTriggerCallback", self)
    end

    if garage.playerTriggerNode ~= nil then
        self.triggerToGarageId[garage.playerTriggerNode] = garage.id
        gsLog("setupGarage", string.format("Garage %s addTrigger player node=%s", tostring(garage.id), tostring(garage.playerTriggerNode)))
        addTrigger(garage.playerTriggerNode, "onPlayerTriggerCallback", self)
    end

    if garage.vehicleTriggerNode ~= nil then
        garage.spawnX, garage.spawnY, garage.spawnZ = getWorldTranslation(garage.vehicleTriggerNode)
        local _, ry, _ = getWorldRotation(garage.vehicleTriggerNode)
        garage.spawnRotY = math.deg(ry)
    end

    if garage ~= nil and garage.id ~= nil and self:hasStoredEntriesForGarageAnyFarm(garage.id) then
        garage.isOpen = false
        gsDiag("setup", "Garage has stored entries on load -> force closed visual/logical state")
    end

    self:applyDoorState(garage, garage.isOpen)
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
    if not self:isClient() then
        gsLog("playerTrigger", "skip callback: not client")
        return
    end

    gsLog("playerTrigger", string.format(
        "Callback trigger=%s garage? actor=%s shape=%s enter=%s leave=%s stay=%s",
        tostring(triggerId),
        tostring(otherActorId),
        tostring(otherShapeId),
        tostring(onEnter),
        tostring(onLeave),
        tostring(onStay)
    ))

    local garageId = self.triggerToGarageId[triggerId]
    if garageId == nil then
        gsLog("playerTrigger", string.format("exit: garageId nil for trigger=%s", tostring(triggerId)))
        return
    end

    gsLog("playerTrigger", string.format("resolved garageId=%s", tostring(garageId)))

    local isPlayer = self:isLocalPlayerTriggerHit(otherActorId, otherShapeId)
    gsLog("playerTrigger", string.format("isLocalPlayerTriggerHit=%s", tostring(isPlayer)))

    if not isPlayer then
        gsLog("playerTrigger", "exit: isPlayer=false")
        return
    end

    if onEnter or onStay then
        self.playerInsideGarageId = garageId
        gsLog("playerTrigger", string.format(
            "set playerInsideGarageId=%s (enter=%s stay=%s)",
            tostring(self.playerInsideGarageId),
            tostring(onEnter),
            tostring(onStay)
        ))
    elseif onLeave then
        if self.playerInsideGarageId == garageId then
            gsLog("playerTrigger", string.format("clear playerInsideGarageId from garage=%s", tostring(garageId)))
            self.playerInsideGarageId = nil
            self:removeToggleActionEvent()
        else
            gsLog("playerTrigger", string.format(
                "leave ignored: currentInside=%s leaveGarage=%s",
                tostring(self.playerInsideGarageId),
                tostring(garageId)
            ))
        end
    end
end

function GarageStorage:isLocalPlayerTriggerHit(otherActorId, otherShapeId)
    gsLog("playerDetect", string.format(
        "isLocalPlayerTriggerHit called actor=%s shape=%s",
        tostring(otherActorId),
        tostring(otherShapeId)
    ))

    local player = g_localPlayer
    if player == nil then
        gsLog("playerDetect", "isLocalPlayerTriggerHit: g_localPlayer == nil")
        return false
    end

    local playerRootNode = player.rootNode
    gsLog("playerDetect", string.format(
        "isLocalPlayerTriggerHit: localPlayer=%s rootNode=%s",
        tostring(player),
        tostring(playerRootNode)
    ))

    if g_currentMission == nil or g_currentMission.nodeToObject == nil then
        gsLog("playerDetect", "isLocalPlayerTriggerHit: g_currentMission/nodeToObject unavailable")
        return false
    end

    local function isMatchObject(obj)
        if obj == nil then
            return false, "obj=nil"
        end

        if obj == player then
            return true, "obj==g_localPlayer"
        end

        if playerRootNode ~= nil and obj.rootNode ~= nil and obj.rootNode == playerRootNode then
            return true, "obj.rootNode==localPlayer.rootNode"
        end

        if obj.player ~= nil and obj.player == player then
            return true, "obj.player==g_localPlayer"
        end

        if obj.owner ~= nil and obj.owner == player then
            return true, "obj.owner==g_localPlayer"
        end

        if obj.getRootVehicle ~= nil then
            local ok, rv = pcall(function()
                return obj:getRootVehicle()
            end)
            if ok and rv ~= nil then
                if rv == player then
                    return true, "obj:getRootVehicle()==g_localPlayer"
                end
                if playerRootNode ~= nil and rv.rootNode ~= nil and rv.rootNode == playerRootNode then
                    return true, "obj:getRootVehicle().rootNode==localPlayer.rootNode"
                end
                if rv.player ~= nil and rv.player == player then
                    return true, "obj:getRootVehicle().player==g_localPlayer"
                end
                if rv.owner ~= nil and rv.owner == player then
                    return true, "obj:getRootVehicle().owner==g_localPlayer"
                end
            end
        end

        if obj.character ~= nil and obj.character == player then
            return true, "obj.character==g_localPlayer"
        end

        if obj.controller ~= nil and obj.controller == player then
            return true, "obj.controller==g_localPlayer"
        end

        return false, "no relation"
    end

    local function matches(nodeId, sourceName)
        local current = nodeId
        while current ~= nil and current ~= 0 do
            local obj = g_currentMission.nodeToObject[current]
            gsLog("playerDetect", string.format(
                "traverse source=%s node=%s obj=%s",
                tostring(sourceName),
                tostring(current),
                tostring(obj)
            ))

            local okMatch, reason = isMatchObject(obj)
            if okMatch then
                gsLog("playerDetect", string.format(
                    "isLocalPlayerTriggerHit MATCH source=%s node=%s reason=%s",
                    tostring(sourceName),
                    tostring(current),
                    tostring(reason)
                ))
                return true
            end

            if getParent == nil then
                gsLog("playerDetect", "isLocalPlayerTriggerHit: getParent unavailable, stop traversal")
                break
            end
            current = getParent(current)
        end
        return false
    end

    local hit = matches(otherShapeId, "shape") or matches(otherActorId, "actor")
    if not hit then
        gsLog("playerDetect", "isLocalPlayerTriggerHit: no match")
    end

    return hit
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

function GarageStorage:hasStoredEntriesForGarageAnyFarm(garageId)
    for _, entry in ipairs(self.storageDb.entries) do
        if entry.garageId == garageId then
            return true
        end
    end

    return false
end

function GarageStorage:removeToggleActionEvent()
    if self.actionEventId ~= nil and g_inputBinding ~= nil then
        gsLog("actionDisplay", string.format("removeToggleActionEvent remove id=%s", tostring(self.actionEventId)))
        if g_inputBinding.setActionEventTextVisibility ~= nil then
            g_inputBinding:setActionEventTextVisibility(self.actionEventId, false)
            gsLog("actionDisplay", string.format("setActionEventTextVisibility id=%s visible=false", tostring(self.actionEventId)))
        end
        if g_inputBinding.setActionEventActive ~= nil then
            g_inputBinding:setActionEventActive(self.actionEventId, false)
            gsLog("actionDisplay", string.format("setActionEventActive id=%s active=false", tostring(self.actionEventId)))
        end
        g_inputBinding:removeActionEvent(self.actionEventId)
        self.actionEventId = nil
    else
        gsLog("action", string.format(
            "removeToggleActionEvent skipped id=%s inputBinding=%s",
            tostring(self.actionEventId),
            tostring(g_inputBinding)
        ))
    end
end

function GarageStorage:onActionToggleGarage(actionName, inputValue, callbackState, isAnalog)
    local farmId = self:getCurrentFarmId()
    gsLog("actionDisplay", string.format(
        "onActionToggleGarage called garageId=%s actionEventId=%s isServer=%s isClient=%s farmId=%s",
        tostring(self.playerInsideGarageId),
        tostring(self.actionEventId),
        tostring(self:isServer()),
        tostring(self:isClient()),
        tostring(farmId)
    ))

    if self.playerInsideGarageId ~= nil then
        if self:isClient() and g_currentMission ~= nil and g_currentMission.missionDynamicInfo ~= nil and g_currentMission.missionDynamicInfo.isMultiplayer and farmId == 0 then
            gsLog("actionDisplay", "onActionToggleGarage blocked: farmId == 0 in MP")
            return true
        end

        if self:isServer() then
            gsLog("actionDisplay", string.format("onActionToggleGarage local server toggle garage=%s", tostring(self.playerInsideGarageId)))
            self:toggleGarage(self.playerInsideGarageId)
        else
            gsLog("actionDisplay", string.format(
                "onActionToggleGarage send request to server garage=%s farmId=%s",
                tostring(self.playerInsideGarageId),
                tostring(farmId)
            ))
            GarageStorageToggleGarageRequestEvent.sendToServer(self.playerInsideGarageId, farmId)
        end
    else
        gsLog("actionDisplay", "onActionToggleGarage ignored: playerInsideGarageId nil")
    end

    return true
end

function GarageStorage:update(dt)
    self:updateDoorAnimations(dt)

    if not self.saveHooksInstalled then
        self.saveHookRetryTimer = (self.saveHookRetryTimer or 0) + (dt or 0)
        if self.saveHookRetryTimer >= 5000 then
            self.saveHookRetryTimer = 0
            self:installSavegameHooks()
        end
    end

    local garageId = self.playerInsideGarageId
    local hasValidFarmForAction = true
    if self:isClient() and g_currentMission ~= nil and g_currentMission.missionDynamicInfo ~= nil and g_currentMission.missionDynamicInfo.isMultiplayer then
        hasValidFarmForAction = self:getCurrentFarmId() ~= 0
    end

    gsLog("actionDisplay", string.format(
        "update interaction state: playerInsideGarageId=%s hasValidFarmForAction=%s actionEventId=%s",
        tostring(garageId),
        tostring(hasValidFarmForAction),
        tostring(self.actionEventId)
    ))

    if garageId == nil then
        gsLog("action", "update early exit: garageId == nil")
        self.hudGarageEntries = nil
        self:removeToggleActionEvent()
        return
    end

    if not hasValidFarmForAction then
        gsLog("action", "update early exit: not hasValidFarmForAction")
        self.hudGarageEntries = nil
        self:removeToggleActionEvent()
        return
    end

    local garage = self.garages[garageId]
    if garage == nil then
        gsLog("action", "update early exit: garage == nil")
        self.hudGarageEntries = nil
        self:removeToggleActionEvent()
        return
    end

    if g_inputBinding == nil then
        gsLog("action", "update early exit: g_inputBinding == nil")
        self.hudGarageEntries = nil
        self:removeToggleActionEvent()
        return
    end

    if self.actionEventId == nil then
        local _, eventId = g_inputBinding:registerActionEvent(InputAction.ACTIVATE_OBJECT, self, self.onActionToggleGarage, false, true, false, true, nil)
        self.actionEventId = eventId

        if self.actionEventId ~= nil then
            if g_inputBinding.setActionEventTextPriority ~= nil and GS_PRIO_HIGH ~= nil then
                g_inputBinding:setActionEventTextPriority(self.actionEventId, GS_PRIO_HIGH)
                gsLog("actionDisplay", string.format("setActionEventTextPriority id=%s prio=%s", tostring(self.actionEventId), tostring(GS_PRIO_HIGH)))
            elseif g_inputBinding.setActionEventTextPriority ~= nil and GS_PRIO_NORMAL ~= nil then
                g_inputBinding:setActionEventTextPriority(self.actionEventId, GS_PRIO_NORMAL)
                gsLog("actionDisplay", string.format("setActionEventTextPriority id=%s prio=%s", tostring(self.actionEventId), tostring(GS_PRIO_NORMAL)))
            end

            g_inputBinding:setActionEventTextVisibility(self.actionEventId, true)
            g_inputBinding:setActionEventActive(self.actionEventId, true)
            gsLog("actionDisplay", string.format("registered action event id=%s for garage=%s", tostring(self.actionEventId), tostring(garageId)))
        else
            gsError("action", "Failed to register action event")
        end
    end

    if self.actionEventId ~= nil then
        local actionText = self:getGarageActionText(garage)
        g_inputBinding:setActionEventText(self.actionEventId, actionText)
        g_inputBinding:setActionEventTextVisibility(self.actionEventId, true)
        g_inputBinding:setActionEventActive(self.actionEventId, hasValidFarmForAction)
        gsLog("actionDisplay", string.format(
            "action event display id=%s text='%s' active=%s visible=%s",
            tostring(self.actionEventId),
            tostring(actionText),
            tostring(hasValidFarmForAction),
            tostring(true)
        ))
    end

    self.hudGarageEntries = nil
    if garage ~= nil and not garage.isOpen then
        local entries = self:getStoredEntriesForGarage(garageId, self:getCurrentFarmId())
        if #entries > 0 then
            self.hudGarageEntries = entries
        end
    end
end

function GarageStorage:draw()
    if self.hudGarageEntries == nil or #self.hudGarageEntries == 0 then
        return
    end

    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_CENTER)
    renderText(0.5, 0.245, 0.018, string.format("Техника в гараже: %d", #self.hudGarageEntries))

    local preview = self.hudGarageEntries[1]
    if preview ~= nil and renderOverlay ~= nil then
        local overlayId = self:getPreviewOverlay(preview.imageFilename)
        if overlayId ~= nil and overlayId ~= 0 then
            renderOverlay(overlayId, 0.455, 0.26, 0.09, 0.09)
        end
    end

    local maxRows = #self.hudGarageEntries
    for i = 1, maxRows do
        local row = self.hudGarageEntries[i]
        local name = row.displayName or row.uniqueId or "Unknown"
        renderText(0.5, 0.225 - (i - 1) * 0.018, 0.015, string.format("• %s", tostring(name)))
    end

    setTextAlignment(RenderText.ALIGN_LEFT)
end

function GarageStorage:setDoorOpenFactor(garage, openFactor)
    if garage == nil or garage.doors == nil then
        return
    end

    local factor = math.max(0, math.min(1, tonumber(openFactor) or 0))
    for _, doorNode in ipairs(garage.doors) do
        local base = garage.doorBaseRot ~= nil and garage.doorBaseRot[doorNode] or nil
        local offset = garage.doorOpenOffset ~= nil and garage.doorOpenOffset[doorNode] or nil
        if base ~= nil then
            local ox = offset ~= nil and offset.x or 0
            local oy = offset ~= nil and offset.y or math.rad(garage.doorOpenAngle or 0)
            local oz = offset ~= nil and offset.z or 0
            setRotation(doorNode, base.x + ox * factor, base.y + oy * factor, base.z + oz * factor)
        end
    end
end

function GarageStorage:ensureDoorSampleLoaded(isOpening)
    local isOpenSound = isOpening == true

    local loadedFlagName = isOpenSound and "doorOpenSampleLoaded" or "doorCloseSampleLoaded"
    local sampleFieldName = isOpenSound and "doorOpenSample" or "doorCloseSample"

    if self[loadedFlagName] then
        return self[sampleFieldName] ~= nil
    end

    self[loadedFlagName] = true
    if createSample == nil or loadSample == nil or self.modDirectory == nil then
        return false
    end

    local fileName = isOpenSound and "garageDoorOpen.ogg" or "garageDoorClose.ogg"
    local fallbackFileName = "garageDoor.ogg"

    local soundPath = self.modDirectory .. "sounds/" .. fileName
    if not fileExists(soundPath) then
        soundPath = self.modDirectory .. "sounds/" .. fallbackFileName
    end

    if not fileExists(soundPath) then
        gsError("sound", "Door sound file not found: " .. tostring(soundPath))
        return false
    end

    local sampleName = isOpenSound and "garageDoorOpen" or "garageDoorClose"
    self[sampleFieldName] = createSample(sampleName)
    if self[sampleFieldName] == nil then
        return false
    end

    local loaded = loadSample(self[sampleFieldName], soundPath, false)
    if not loaded then
        delete(self[sampleFieldName])
        self[sampleFieldName] = nil
    end

    return loaded
end

function GarageStorage:playDoorMoveSound(garage, isOpening)
    if not self:ensureDoorSampleLoaded(isOpening) then
        return
    end

    local sample = isOpening and self.doorOpenSample or self.doorCloseSample
    if playSample ~= nil and sample ~= nil then
        local x, y, z = 0, 0, 0
        if garage ~= nil and garage.soundNode ~= nil then
            x, y, z = getWorldTranslation(garage.soundNode)
        elseif g_currentMission ~= nil and g_currentMission.player ~= nil and g_currentMission.player.rootNode ~= nil then
            x, y, z = getWorldTranslation(g_currentMission.player.rootNode)
        elseif g_localPlayer ~= nil and g_localPlayer.rootNode ~= nil then
            x, y, z = getWorldTranslation(g_localPlayer.rootNode)
        end

        if setSamplePosition ~= nil then
            pcall(setSamplePosition, sample, x, y, z)
        end
        pcall(playSample, sample, 1, 1, 0, 0, 0)
    end
end

function GarageStorage:startDoorAnimation(garage, targetOpen)
    if garage == nil or garage.id == nil then
        return
    end

    local fromFactor = targetOpen and 0 or 1
    local existing = self.activeDoorAnimations[garage.id]
    if existing ~= nil then
        fromFactor = existing.currentFactor or fromFactor
    else
        fromFactor = garage.isOpen and 1 or 0
    end

    self.activeDoorAnimations[garage.id] = {
        garage = garage,
        fromFactor = fromFactor,
        targetFactor = targetOpen and 1 or 0,
        durationMs = self.doorAnimationDurationMs,
        elapsedMs = 0,
        currentFactor = fromFactor
    }

    self:setGarageLightVisibility(garage, targetOpen)
    self:playDoorMoveSound(garage, targetOpen)
end

function GarageStorage:updateDoorAnimations(dt)
    if self.activeDoorAnimations == nil then
        return
    end

    for garageId, anim in pairs(self.activeDoorAnimations) do
        anim.elapsedMs = (anim.elapsedMs or 0) + (tonumber(dt) or 0)
        local durationMs = math.max(1, tonumber(anim.durationMs) or 1)
        local t = math.min(1, anim.elapsedMs / durationMs)
        local factor = (anim.fromFactor or 0) + ((anim.targetFactor or 0) - (anim.fromFactor or 0)) * t
        anim.currentFactor = factor

        self:setDoorOpenFactor(anim.garage, factor)

        if t >= 1 then
            self.activeDoorAnimations[garageId] = nil
        end
    end
end

function GarageStorage:setGarageLightVisibility(garage, isVisible)
    if garage == nil or garage.lightNode == nil then
        return
    end

    setVisibility(garage.lightNode, isVisible == true)
end

function GarageStorage:applyDoorState(garage, isOpen)
    if garage ~= nil and garage.id ~= nil then
        self.activeDoorAnimations[garage.id] = nil
    end
    self:setDoorOpenFactor(garage, isOpen and 1 or 0)
    self:setGarageLightVisibility(garage, isOpen == true)
end


function GarageStorage:getVehicleImageFilename(vehicle)
    if vehicle == nil or vehicle.configFileName == nil or g_storeManager == nil then
        return nil
    end

    local storeItem = g_storeManager:getItemByXMLFilename(vehicle.configFileName)
    if storeItem ~= nil and storeItem.imageFilename ~= nil and storeItem.imageFilename ~= "" then
        return storeItem.imageFilename
    end

    return nil
end

function GarageStorage:clearPreviewOverlays()
    if self.previewOverlays == nil then
        return
    end

    for _, overlayId in pairs(self.previewOverlays) do
        if overlayId ~= nil and overlayId ~= 0 then
            delete(overlayId)
        end
    end

    self.previewOverlays = {}
end

function GarageStorage:getPreviewOverlay(imageFilename)
    if imageFilename == nil or imageFilename == "" then
        return nil
    end

    if self.previewOverlays == nil then
        self.previewOverlays = {}
    end

    if self.previewOverlays[imageFilename] ~= nil then
        return self.previewOverlays[imageFilename]
    end

    if createImageOverlay == nil then
        return nil
    end

    local overlayId = createImageOverlay(imageFilename)
    if overlayId ~= nil and overlayId ~= 0 then
        self.previewOverlays[imageFilename] = overlayId
        return overlayId
    end

    return nil
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
    if not self:isServer() then
        gsDiag("network", "toggleGarage ignored on client; waiting for server sync")
        return
    end

    gsDiag("diag", "toggleGarage start garageId=" .. tostring(garageId) .. " currentState=" .. tostring(self.garages[garageId] ~= nil and self.garages[garageId].isOpen))
    local garage = self.garages[garageId]
    if garage == nil then
        gsError("toggleGarage", "Unknown garage id: " .. tostring(garageId))
        return
    end

    if garage.isOpen then
        self:closeGarage(garageId)
        self:startDoorAnimation(garage, false)
        garage.isOpen = false
    else
        self:openGarage(garageId)
        self:startDoorAnimation(garage, true)
        garage.isOpen = true
    end

    gsLog("toggleGarage", string.format("Garage %d new state open=%s", garageId, tostring(garage.isOpen)))

    if self:isServer() then
        GarageStorageStateSyncEvent.broadcast(self)
    end
end

function GarageStorage:toggleGarageForFarm(garageId, farmId, connection)
    if not self:isServer() then
        return
    end

    gsDiag("network", string.format(
        "toggleGarageForFarm enter garageId=%s farmId=%s connection=%s",
        tostring(garageId),
        tostring(farmId),
        tostring(connection)
    ))

    if not self:canFarmUseGarage(connection, garageId, farmId) then
        return
    end

    local garage = self.garages[garageId]
    if garage == nil then
        return
    end

    if garage.isOpen then
        self:closeGarage(garageId)
        self:startDoorAnimation(garage, false)
        garage.isOpen = false
    else
        self:openGarage(garageId, farmId)
        self:startDoorAnimation(garage, true)
        garage.isOpen = true
    end

    GarageStorageStateSyncEvent.broadcast(self)
end

function GarageStorage:consoleCloseGarage(garageId)
    local id = tonumber(garageId) or self.currentGarageId
    gsLog("console", string.format("gsGarageClose id=%s", tostring(id)))
    self:closeGarage(id)
    local garage = self.garages[id]
    if garage ~= nil then
        self:startDoorAnimation(garage, false)
        garage.isOpen = false
    end
end

function GarageStorage:consoleOpenGarage(garageId)
    local id = tonumber(garageId) or self.currentGarageId
    gsLog("console", string.format("gsGarageOpen id=%s", tostring(id)))
    self:openGarage(id)
    local garage = self.garages[id]
    if garage ~= nil then
        self:startDoorAnimation(garage, true)
        garage.isOpen = true
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

    local farmId = 0
    if vehicle ~= nil and vehicle.getOwnerFarmId ~= nil then
        farmId = vehicle:getOwnerFarmId() or 0
    end
    if vehicle ~= nil then
        farmId = vehicle.ownerFarmId or farmId
    end
    if farmId ~= nil and farmId ~= 0 then
        return farmId
    end

    if g_localPlayer ~= nil and g_localPlayer.getFarmId ~= nil then
        farmId = g_localPlayer:getFarmId() or farmId
    end

    return farmId
end

function GarageStorage:saveVehicleToFile(vehicle, entryId)

    if not self:isServer() then
        return false
    end
    local vehiclesDir = self:getVehiclesStorageDir()
    if vehiclesDir == nil then
        gsError("storeVehicle", "Vehicles storage directory is nil")
        return nil
    end

    gsEnsureDir(vehiclesDir)

    local baseName = tostring(entryId)
    if self.storageMode == "session" then
        baseName = self:getSessionFilePrefix() .. "vehicle_" .. tostring(entryId)
    end

    local vehicleFilePath = string.format("%s%s.xml", vehiclesDir, baseName)
    gsDiag("storeVehicle", "selected vehicle xml target path=" .. tostring(vehicleFilePath))

    local parentDir = gsGetParentDir(vehicleFilePath)
    if parentDir ~= nil then
        gsEnsureDir(parentDir)
    end

    local xml = XMLFile.create("GarageStoredVehicleWrite", vehicleFilePath, "vehicles", Vehicle.xmlSchemaSavegame)
    if xml == nil then
        gsError("storeVehicle", "Could not create vehicle xml file")
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
        gsError("storeVehicle", "vehicle xml save fail path=" .. tostring(vehicleFilePath) .. " " .. self:getLogContext())
        return nil
    end

    gsDiag("storeVehicle", "vehicle xml save success path=" .. tostring(vehicleFilePath) .. " exists=" .. tostring(fileExists(vehicleFilePath)))
    return vehicleFilePath
end

function GarageStorage:storeVehicle(vehicle, garageId, farmId)
    if vehicle == nil then
        return false
    end

    local entryId = string.format("%d_%d_%s", garageId, farmId, tostring(vehicle.uniqueId))
    gsDiag("storeVehicle", string.format("storeVehicle start uniqueId=%s config=%s garageId=%s farmId=%s entryId=%s mode=%s", tostring(vehicle.uniqueId), tostring(vehicle.configFileName), tostring(garageId), tostring(farmId), tostring(entryId), tostring(self.storageMode)))

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
    gsDiag("storeVehicle", "selected vehicle xml target path=" .. tostring(vehicleFile))
    if vehicleFile == nil then
        gsError("storeVehicle", "Failed to save vehicle xml file")
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
        imageFilename = self:getVehicleImageFilename(vehicle),
        vehicleFile = vehicleFile,
        posX = px,
        posY = py,
        posZ = pz,
        rotX = rx,
        rotY = ry,
        rotZ = rz
    }

    table.insert(self.storageDb.entries, entry)
    gsDiag("storeVehicle", "db entry add/update success entryId=" .. tostring(entryId))
    self:saveStorageDb()

    local okDelete = pcall(function() vehicle:delete() end)
    gsDiag("storeVehicle", "vehicle delete from world success=" .. tostring(okDelete))
    gsLog("storeVehicle", string.format("Stored and removed vehicle %s", tostring(vehicle.uniqueId)))
    return true
end

function GarageStorage:closeGarage(garageId)
    gsDiag("closeGarage", "closeGarage started garageId=" .. tostring(garageId) .. " mode=" .. tostring(self.storageMode))
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

    gsDiag("closeGarage", string.format("vehicles found inside garage trigger count=%d", #toStore))

    for _, vehicle in ipairs(toStore) do
        local farmId = self:getFarmIdFromVehicle(vehicle)
        if self:storeVehicle(vehicle, garageId, farmId) then
            stored = stored + 1
            garage.vehiclesInTrigger[vehicle] = nil
        else
            gsError("closeGarage", string.format("Failed to store vehicle %s", tostring(vehicle.uniqueId)))
        end
    end

    gsLog("closeGarage", string.format("Garage %d closed. Stored: %d", garageId, stored))
end

function GarageStorage:spawnStoredEntry(entry, garage)
    gsDiag("spawn", "spawnStoredEntry start entryId=" .. tostring(entry ~= nil and entry.entryId) .. " vehicleFile=" .. tostring(entry ~= nil and entry.vehicleFile))
    local vehicleFile = entry.vehicleFile
    if vehicleFile == nil or vehicleFile == "" or not fileExists(vehicleFile) then
        gsError("openGarage", "Stored vehicle xml file is missing: " .. tostring(vehicleFile))
        return false
    end

    local xml = XMLFile.load("GarageStoredVehicle", vehicleFile, Vehicle.xmlSchemaSavegame)
    if xml == nil then
        gsError("openGarage", "Cannot load stored vehicle xml: " .. tostring(vehicleFile))
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
            self:saveStorageDb(true)

            if a.vehicleFile ~= nil and fileExists(a.vehicleFile) then
                deleteFile(a.vehicleFile)
            end

            gsDiag("spawn", "spawnStoredEntry success entryId=" .. tostring(a.entryId))
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
                    self:saveStorageDb(true)

                    if a.vehicleFile ~= nil and fileExists(a.vehicleFile) then
                        deleteFile(a.vehicleFile)
                    end

                    return
                end
            end

            gsError("spawn", "spawnStoredEntry fail entryId=" .. tostring(a.entryId) .. " state=" .. tostring(vehicleLoadState) .. " file=" .. tostring(a.vehicleFile) .. " " .. self:getLogContext())
        end

    end

    g_asyncTaskManager:addTask(function()
        g_currentMission.vehicleSystem:loadFromXMLFile(xml, onLoaded, nil, args, false, false)
    end)

    return true
end

function GarageStorage:openGarage(garageId, farmIdOverride)
    gsDiag("openGarage", "openGarage started garageId=" .. tostring(garageId) .. " mode=" .. tostring(self.storageMode) .. " db=" .. tostring(self.storageDbPath))
    local garage = self.garages[garageId]
    if garage == nil then
        return
    end

    local farmId = farmIdOverride or self:getCurrentFarmId()

    local selected = {}
    local seenEntryIds = {}
    for _, entry in ipairs(self.storageDb.entries) do
        if entry.garageId == garageId and entry.farmId == farmId and entry.entryId ~= nil and not seenEntryIds[entry.entryId] then
            if g_currentMission ~= nil and g_currentMission.vehicleSystem ~= nil and entry.uniqueId ~= nil and g_currentMission.vehicleSystem:getVehicleByUniqueId(entry.uniqueId) ~= nil then
                gsDiag("openGarage", "vehicle already exists in world, skip spawn for entryId=" .. tostring(entry.entryId))
            else
                seenEntryIds[entry.entryId] = true
                table.insert(selected, entry)
            end
        end
    end
    gsDiag("openGarage", string.format("openGarage selected entries count=%d", #selected))

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
