
SvapaToggleSystem = SvapaToggleSystem or {}
SvapaToggleSystem.MOD_NAME = g_currentModName
SvapaToggleSystem.MOD_DIR = g_currentModDirectory
SvapaToggleSystem.STATE_STORE_KEY = "g_svapaToggleStateStore"

local ST_DEBUG_ENABLED = false

local ST_LOG_PREFIX = "[SvapaToggleManager]"
local ST_MOD_DIR = SvapaToggleSystem.MOD_DIR or g_currentModDirectory or ""
local ST_GUI_XML = (ST_MOD_DIR ~= "" and (ST_MOD_DIR:gsub('\\','/')) or "") .. "scripts/ToggleSystem/gui/SvapaToggleGUI.xml"
local ST_DEFAULT_FEATURES_XML = (ST_MOD_DIR ~= "" and (ST_MOD_DIR:gsub('\\','/')) or "") .. "scripts/ToggleSystem/config/scriptToggleFeatures.xml"

local function stLog(message, ...)
    local template = tostring(message or "")
    local ok, formatted = pcall(string.format, template, ...)
    print(string.format("%s %s", ST_LOG_PREFIX, ok and formatted or template))
end

local function stWarn(message, ...)
    local template = tostring(message or "")
    local ok, formatted = pcall(string.format, template, ...)
    print(string.format("%s [WARN] %s", ST_LOG_PREFIX, ok and formatted or template))
end

local function stDbg(message, ...)
    if not ST_DEBUG_ENABLED then
        return
    end

    local template = tostring(message or "")
    local ok, formatted = pcall(string.format, template, ...)
    print(string.format("%s [DEBUG] %s", ST_LOG_PREFIX, ok and formatted or template))
end

local function stNormalizeDir(dir)
    if dir == nil or dir == "" then
        return ""
    end

    dir = tostring(dir):gsub("\\", "/")
    if dir:sub(-1) ~= "/" then
        dir = dir .. "/"
    end
    return dir
end

local function stGetMapDir()
    if g_currentMission ~= nil and g_currentMission.baseDirectory ~= nil then
        return stNormalizeDir(g_currentMission.baseDirectory)
    end
    return ""
end

local function stResolveModDir()
    if ST_MOD_DIR ~= nil and ST_MOD_DIR ~= "" then
        return stNormalizeDir(ST_MOD_DIR)
    end
    if SvapaToggleSystem.MOD_DIR ~= nil and SvapaToggleSystem.MOD_DIR ~= "" then
        return stNormalizeDir(SvapaToggleSystem.MOD_DIR)
    end
    if g_currentModDirectory ~= nil and g_currentModDirectory ~= "" then
        return stNormalizeDir(g_currentModDirectory)
    end
    return ""
end

local function stIsAbsolutePath(path)
    if path == nil or path == "" then
        return false
    end

    local normalized = tostring(path):gsub("\\", "/")
    return normalized:match("^[A-Za-z]:/") ~= nil or normalized:sub(1, 1) == "/" or normalized:sub(1, 2) == "//"
end

local function stSafeReplace(value, pattern, replacement)
    if value == nil then
        return nil
    end
    return tostring(value):gsub(pattern, function()
        return tostring(replacement or "")
    end)
end

local function stResolveConfigPath(rawPath, baseDir)
    if rawPath == nil or rawPath == "" then
        return nil
    end

    local result = tostring(rawPath)
    result = stSafeReplace(result, "%$moddir%$", stResolveModDir())
    result = stSafeReplace(result, "%$mapdir%$", stGetMapDir())

    if stIsAbsolutePath(result) then
        return result
    end

    return Utils.getFilename(result, baseDir or stResolveModDir())
end

local function stSplitPath(path)
    local result = {}
    if path == nil or path == "" then
        return result
    end
    for part in tostring(path):gmatch("[^%.]+") do
        table.insert(result, part)
    end
    return result
end

local function stResolveGlobalObject(path)
    if path == nil or path == "" then
        return nil
    end

    local current = _G
    for _, part in ipairs(stSplitPath(path)) do
        if type(current) ~= "table" then
            return nil
        end
        current = current[part]
        if current == nil then
            return nil
        end
    end

    return current
end

local function stResolveParentAndField(rootObject, fieldPath)
    if rootObject == nil or fieldPath == nil or fieldPath == "" then
        return nil, nil
    end

    local parts = stSplitPath(fieldPath)
    if #parts == 0 then
        return nil, nil
    end

    local current = rootObject
    for i = 1, #parts - 1 do
        if type(current) ~= "table" then
            return nil, nil
        end
        current = current[parts[i]]
        if current == nil then
            return nil, nil
        end
    end

    return current, parts[#parts]
end

local function stTryGetText(key)
    if g_i18n == nil or key == nil or key == "" then
        return nil
    end

    local ok, text = pcall(function()
        return g_i18n:getText(key)
    end)

    if ok and text ~= nil and text ~= "" then
        return text
    end
    return nil
end

local function stResolveActionText(rawText)
    local fallback = stTryGetText("action_activateObject") or "Open toggle menu"

    if rawText == nil or rawText == "" then
        return fallback
    end

    if type(rawText) ~= "string" then
        return tostring(rawText)
    end

    if rawText:sub(1, 6) == "$l10n_" then
        return stTryGetText(rawText:sub(7)) or fallback
    end

    if rawText:match("^[%a_][%w_%.%-]*$") ~= nil then
        local translated = stTryGetText(rawText)
        if translated ~= nil and translated ~= "" then
            return translated
        end
    end

    return rawText
end

local function stNodeName(nodeId)
    if nodeId == nil or nodeId == 0 or getName == nil then
        return "nil"
    end

    local ok, name = pcall(getName, nodeId)
    if ok and name ~= nil and name ~= "" then
        return tostring(name)
    end

    return tostring(nodeId)
end

local function stFindChildByName(nodeId, wantedName)
    if nodeId == nil or nodeId == 0 or wantedName == nil or wantedName == "" then
        return nil
    end

    if getName ~= nil and getName(nodeId) == wantedName then
        return nodeId
    end

    if getNumOfChildren == nil or getChildAt == nil then
        return nil
    end

    local childCount = getNumOfChildren(nodeId)
    for i = 0, childCount - 1 do
        local child = getChildAt(nodeId, i)
        local found = stFindChildByName(child, wantedName)
        if found ~= nil then
            return found
        end
    end

    return nil
end

local function stNodeLooksLikeTrigger(nodeId)
    if nodeId == nil or nodeId == 0 then
        return false
    end

    local name = string.lower(stNodeName(nodeId))
    if name == "scripttogglemenutrigger" or name == "playertigger" or name == "playertrigger" or name == "interactiontrigger" then
        return true
    end
    return string.find(name, "trigger", 1, true) ~= nil
        or string.find(name, "interaction", 1, true) ~= nil
        or string.find(name, "col", 1, true) ~= nil
end

local function stFindTriggerNode(rootNode)
    if rootNode == nil or rootNode == 0 then
        return nil
    end

    local exactNames = {
        "svapaToggleTrigger",
        "toggleTrigger",
        "playerTrigger",
        "interactionTrigger",
        "gs_playerTrigger"
    }

    for _, wantedName in ipairs(exactNames) do
        local found = stFindChildByName(rootNode, wantedName)
        if found ~= nil then
            return found
        end
    end

    if stNodeLooksLikeTrigger(rootNode) then
        return rootNode
    end

    if getNumOfChildren == nil or getChildAt == nil then
        return rootNode
    end

    local queue = {rootNode}
    local qIndex = 1
    while qIndex <= #queue do
        local current = queue[qIndex]
        qIndex = qIndex + 1

        if current ~= rootNode and stNodeLooksLikeTrigger(current) then
            return current
        end

        local count = getNumOfChildren(current)
        for i = 0, count - 1 do
            table.insert(queue, getChildAt(current, i))
        end
    end

    return rootNode
end

local function stResolveNodeObject(nodeId)
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

local function stIsPlayerActor(otherActorId, otherShapeId)
    local mission = g_currentMission
    if mission == nil then
        return false
    end

    local player = mission.player
    local localPlayer = g_localPlayer

    if player ~= nil and (otherActorId == player.rootNode or otherShapeId == player.rootNode) then
        return true
    end
    if localPlayer ~= nil and (otherActorId == localPlayer.rootNode or otherShapeId == localPlayer.rootNode) then
        return true
    end

    local objectFromShape = stResolveNodeObject(otherShapeId)
    local objectFromActor = stResolveNodeObject(otherActorId)

    return objectFromShape == player or objectFromShape == localPlayer or objectFromActor == player or objectFromActor == localPlayer
end

local function stSafeRemoveTrigger(triggerNode)
    if triggerNode == nil or triggerNode == 0 then
        return
    end
    if entityExists ~= nil and not entityExists(triggerNode) then
        return
    end
    pcall(removeTrigger, triggerNode)
end

local function stExposeGlobal(name, value)
    _G[name] = value
    local rootEnv = getfenv ~= nil and getfenv(0) or nil
    if rootEnv ~= nil then
        rootEnv[name] = value
    end
end

local function stGetSharedToggleStateStore()
    _G[SvapaToggleSystem.STATE_STORE_KEY] = _G[SvapaToggleSystem.STATE_STORE_KEY] or {}
    return _G[SvapaToggleSystem.STATE_STORE_KEY]
end

local function stClearTable(tbl)
    if tbl == nil then
        return
    end
    for key in pairs(tbl) do
        tbl[key] = nil
    end
end

local function stMapLegacyToggleId(toggleId)
    local legacyMap = {
        ["randomEvents.enabled"] = "randomTheftEvents.enabled",
        ["randomEvents.startupMissingVehicle"] = "randomTheftEvents.startupMissingVehicle.enabled",
        ["randomEvents.fuel"] = "randomTheftEvents.events.fuel.enabled",
        ["randomEvents.seeds"] = "randomTheftEvents.events.seeds.enabled",
        ["randomEvents.fertilizer"] = "randomTheftEvents.events.fertilizer.enabled",
        ["randomEvents.drought"] = "randomTheftEvents.globalEvents.drought.enabled",
        ["randomEvents.flood"] = "randomTheftEvents.globalEvents.flood.enabled"
    }

    return legacyMap[tostring(toggleId)] or toggleId
end

local function stResolveToggleIdForLookup(manager, toggleId)
    local mappedId = tostring(stMapLegacyToggleId(toggleId))
    local stateStore = stGetSharedToggleStateStore()

    local function hasState(id)
        if manager ~= nil and manager.toggleFeatureStates ~= nil and manager.toggleFeatureStates[id] ~= nil then
            return true
        end
        return stateStore[id] ~= nil
    end

    local function hasFeature(id)
        if manager ~= nil and manager.getFeatureById ~= nil then
            return manager:getFeatureById(id) ~= nil
        end
        return false
    end

    if hasState(mappedId) or hasFeature(mappedId) then
        return mappedId
    end

    if not string.match(mappedId, "%.enabled$") then
        local enabledId = mappedId .. ".enabled"
        if hasState(enabledId) or hasFeature(enabledId) then
            return enabledId
        end
    end

    return mappedId
end

g_scriptToggleMenuOnCreateData = g_scriptToggleMenuOnCreateData or {}

function ScriptToggleMenuTrigger_onCreate(nodeId)
    local rawConfigPath = getUserAttribute(nodeId, "toggleConfig")
    local actionTextRaw = getUserAttribute(nodeId, "actionText")
    local actionText = stResolveActionText(actionTextRaw)
    local triggerNode = stFindTriggerNode(nodeId)

    stDbg("onCreate root=%s trigger=%s config=%s actionText=%s", tostring(nodeId), tostring(triggerNode), tostring(rawConfigPath), tostring(actionText))

    table.insert(g_scriptToggleMenuOnCreateData, {
        rootNode = nodeId,
        nodeId = triggerNode,
        toggleConfig = rawConfigPath,
        actionText = actionText
    })
end

local function stRegisterOnCreateAliases()
    local modName = g_currentModName or SvapaToggleSystem.MOD_NAME

    if modName ~= nil and modName ~= "" then
        _G[modName] = _G[modName] or {}
        _G[modName].ScriptToggleMenuTrigger_onCreate = ScriptToggleMenuTrigger_onCreate
    end

    _G.modOnCreate = _G.modOnCreate or {}
    _G.modOnCreate.ScriptToggleMenuTrigger_onCreate = ScriptToggleMenuTrigger_onCreate
    stExposeGlobal("ScriptToggleMenuTrigger_onCreate", ScriptToggleMenuTrigger_onCreate)
end

stRegisterOnCreateAliases()

SvapaToggleManager = {}
local SvapaToggleManager_mt = Class(SvapaToggleManager)

function SvapaToggleManager.new(mission)
    local self = setmetatable({}, SvapaToggleManager_mt)
    self.mission = mission
    self.toggleTriggers = {}
    self.toggleTriggerByNode = {}
    self.playerToggleTrigger = nil
    self.guiLoaded = false
    self.guiInstance = nil
    self.toggleFeatureStates = stGetSharedToggleStateStore()
    self.toggleFeatures = {}
    self.stateFileName = "svapaToggleStates.xml"
    self.defaultConfigPath = ST_DEFAULT_FEATURES_XML
    self.pendingRuntimeApply = true
    self.lastRuntimeApplySuccess = false
    self.isControllerActive = false
    self.pendingStateFileWrite = false
    self.savegameHooksInstalled = false
    return self
end

function SvapaToggleManager:delete()
    for _, trigger in ipairs(self.toggleTriggers) do
        if trigger.isRegistered then
            g_currentMission.activatableObjectsSystem:removeActivatable(trigger.activatable)
            trigger.isRegistered = false
        end
        if trigger.triggerNode ~= nil then
            stSafeRemoveTrigger(trigger.triggerNode)
            trigger.triggerNode = nil
        end
    end

    self.toggleTriggers = {}
    self.toggleTriggerByNode = {}
    self.playerToggleTrigger = nil
end

function SvapaToggleManager:canPlayerEdit()
    if g_server ~= nil then
        return true
    end

    if g_client ~= nil and g_client.getServerConnection ~= nil then
        local connection = g_client:getServerConnection()
        if connection ~= nil and connection.getIsServerAdmin ~= nil then
            return connection:getIsServerAdmin()
        end
    end

    return false
end

function SvapaToggleManager:getSavegameDirectory()
    if self.mission ~= nil then
        if self.mission.missionInfo ~= nil and self.mission.missionInfo.savegameDirectory ~= nil and self.mission.missionInfo.savegameDirectory ~= "" then
            return stNormalizeDir(self.mission.missionInfo.savegameDirectory)
        end
        if self.mission.savegameDirectory ~= nil and self.mission.savegameDirectory ~= "" then
            return stNormalizeDir(self.mission.savegameDirectory)
        end
    end
    return ""
end

function SvapaToggleManager:getStateFilePath()
    local saveDir = self:getSavegameDirectory()
    if saveDir == "" then
        return nil
    end
    return saveDir .. self.stateFileName
end

function SvapaToggleManager:loadToggleStateFile()
    stClearTable(self.toggleFeatureStates)

    local stateFilePath = self:getStateFilePath()
    stDbg("loadToggleStateFile path=%s", tostring(stateFilePath))
    if stateFilePath == nil or stateFilePath == "" or fileExists == nil or not fileExists(stateFilePath) then
        self.isControllerActive = false
        stDbg("loadToggleStateFile skipped: file missing")
        return false
    end

    local xmlFile = loadXMLFile("svapaToggleStatesXML", stateFilePath)
    if xmlFile == nil or xmlFile == 0 then
        stWarn("loadToggleStateFile failed to open xml: %s", tostring(stateFilePath))
        return false
    end

    local index = 0
    while true do
        local key = string.format("toggleStates.state(%d)", index)
        if hasXMLProperty == nil or not hasXMLProperty(xmlFile, key) then
            break
        end

        local id = getXMLString(xmlFile, key .. "#id")
        local value = getXMLBool(xmlFile, key .. "#value")
        if id ~= nil and id ~= "" then
            local mappedId = stMapLegacyToggleId(id)
            self.toggleFeatureStates[tostring(mappedId)] = value == true
            stDbg("loadToggleStateFile state[%d] id=%s mappedId=%s value=%s", index, tostring(id), tostring(mappedId), tostring(value == true))
        end

        index = index + 1
    end

    delete(xmlFile)
    self.isControllerActive = true
    stDbg("loadToggleStateFile loadedCount=%d", index)
    return true
end

function SvapaToggleManager:ensureFeaturesLoadedForRuntime()
    if self.toggleFeatures ~= nil and #self.toggleFeatures > 0 then
        return true
    end

    stWarn("ensureFeaturesLoadedForRuntime called with empty feature list, trying to load")

    for _, trigger in ipairs(self.toggleTriggers or {}) do
        if trigger ~= nil and trigger.ensureConfigLoaded ~= nil then
            local ok, loaded = pcall(function()
                return trigger:ensureConfigLoaded()
            end)

            if ok and loaded == true and self.toggleFeatures ~= nil and #self.toggleFeatures > 0 then
                stDbg("ensureFeaturesLoadedForRuntime success featureCount=%d", #self.toggleFeatures)
                return true
            end
        end
    end

    if (self.toggleFeatures == nil or #self.toggleFeatures == 0) and self.defaultConfigPath ~= nil and self.defaultConfigPath ~= "" then
        local ok, loaded = pcall(function()
            return self:loadFeatures(self.defaultConfigPath)
        end)

        if ok and loaded == true and self.toggleFeatures ~= nil and #self.toggleFeatures > 0 then
            stWarn("ensureFeaturesLoadedForRuntime recovered using default config '%s', featureCount=%d", tostring(self.defaultConfigPath), #self.toggleFeatures)
            return true
        end
    end

    stWarn("ensureFeaturesLoadedForRuntime no features loaded after all attempts")
    return self.toggleFeatures ~= nil and #self.toggleFeatures > 0
end

function SvapaToggleManager:getFeatureById(toggleId)
    local mappedToggleId = stMapLegacyToggleId(toggleId)
    for _, feature in ipairs(self.toggleFeatures or {}) do
        if tostring(feature.id) == tostring(mappedToggleId) then
            return feature
        end
    end
    return nil
end

function SvapaToggleManager:getChildFeatures(parentId)
    local result = {}
    if parentId == nil or parentId == "" then
        return result
    end

    for _, feature in ipairs(self.toggleFeatures or {}) do
        if tostring(feature.parentId or "") == tostring(parentId) then
            table.insert(result, feature)
        end
    end

    return result
end

function SvapaToggleManager:getToggleValue(toggleId, defaultValue)
    local mappedToggleId = stMapLegacyToggleId(toggleId)
    local value = self.toggleFeatureStates[tostring(mappedToggleId)]
    if value == nil then
        local feature = self:getFeatureById(mappedToggleId)
        if feature ~= nil and feature.value ~= nil then
            value = feature.value == true
        end
    end
    if value == nil then
        return defaultValue == true
    end
    return value == true
end

function SvapaToggleManager:isFeatureForcedOff(feature)
    if feature == nil then
        return false
    end

    local parentId = feature.parentId
    while parentId ~= nil and parentId ~= "" do
        local parentFeature = self:getFeatureById(parentId)
        local parentDefault = parentFeature ~= nil and parentFeature.defaultValue or true
        local parentRawValue = self:getToggleValue(parentId, parentDefault)
        if parentRawValue ~= true then
            return true
        end

        if parentFeature == nil then
            break
        end
        parentId = parentFeature.parentId
    end

    return false
end

function SvapaToggleManager:getEffectiveToggleValue(toggleId, defaultValue)
    local feature = self:getFeatureById(toggleId)
    local rawValue = self:getToggleValue(toggleId, feature ~= nil and feature.defaultValue or defaultValue)

    if rawValue ~= true then
        return false
    end

    if feature ~= nil and self:isFeatureForcedOff(feature) then
        return false
    end

    return true
end

function SvapaToggleManager:setToggleValue(toggleId, value)
    if g_server == nil then
        stDbg("setToggleValue skipped on client for id=%s", tostring(toggleId))
        return false
    end

    local mappedToggleId = stMapLegacyToggleId(toggleId)
    local feature = self:getFeatureById(mappedToggleId)
    local boolValue = value == true
    local id = tostring(mappedToggleId)

    if feature ~= nil and feature.parentId ~= nil and feature.parentId ~= "" and self:isFeatureForcedOff(feature) then
        stDbg("setToggleValue id=%s blockedByParent=true requestedValue=%s rawValueKept=%s", id, tostring(boolValue), tostring(self:getToggleValue(id, feature.defaultValue)))
        return
    end

    self.toggleFeatureStates[id] = boolValue
    if feature ~= nil then
        feature.value = boolValue
    end
    self.pendingRuntimeApply = false
    stDbg("setToggleValue id=%s rawValue=%s", id, tostring(boolValue))
    return true
end

function SvapaToggleManager:applyReplicatedToggleValue(toggleId, value)
    local mappedToggleId = stMapLegacyToggleId(toggleId)
    local feature = self:getFeatureById(mappedToggleId)
    local boolValue = value == true
    local id = tostring(mappedToggleId)

    self.toggleFeatureStates[id] = boolValue
    if feature ~= nil then
        feature.value = boolValue
    end
    self.isControllerActive = true
    self.pendingRuntimeApply = false
    stDbg("applyReplicatedToggleValue id=%s value=%s", id, tostring(boolValue))
    return true
end

function SvapaToggleManager:saveToggleStateFile()
    if g_server == nil then
        stDbg("saveToggleStateFile skipped on client")
        return false
    end

    self:ensureFeaturesLoadedForRuntime()

    local stateFilePath = self:getStateFilePath()
    stDbg("saveToggleStateFile path=%s", tostring(stateFilePath))
    if stateFilePath == nil or stateFilePath == "" then
        stWarn("Save deferred: savegame directory is unavailable")
        self.pendingStateFileWrite = true
        self.isControllerActive = true
        self.pendingRuntimeApply = false
        self:applyToggleTargets()
        self:notifyExternalModulesAfterApply()
        return true
    end

    local xmlFile = createXMLFile("svapaToggleStatesXML", stateFilePath, "toggleStates")
    if xmlFile == nil or xmlFile == 0 then
        stWarn("Could not create toggle state file '%s'", tostring(stateFilePath))
        self.pendingStateFileWrite = true
        return false
    end

    local index = 0
    for _, feature in ipairs(self.toggleFeatures or {}) do
        local rawValue = self:getToggleValue(feature.id, feature.defaultValue)
        local effectiveValue = self:getEffectiveToggleValue(feature.id, feature.defaultValue)

        local key = string.format("toggleStates.state(%d)", index)
        setXMLString(xmlFile, key .. "#id", tostring(feature.id))
        setXMLBool(xmlFile, key .. "#value", effectiveValue)
        stDbg(
            "saveToggleStateFile state[%d] id=%s rawValue=%s effectiveValue=%s savedValue=%s",
            index,
            tostring(feature.id),
            tostring(rawValue),
            tostring(effectiveValue),
            tostring(effectiveValue)
        )
        index = index + 1
    end

    saveXMLFile(xmlFile)
    delete(xmlFile)

    self.isControllerActive = true
    self.pendingRuntimeApply = false
    self.pendingStateFileWrite = false
    self:applyToggleTargets()
    self:notifyExternalModulesAfterApply()

    stDbg("saveToggleStateFile savedCount=%d", index)
    return true
end

function SvapaToggleManager:loadFeatures(configPath)
    local resolvedConfigPath = stResolveConfigPath(configPath, stResolveModDir())
    stDbg("loadFeatures rawPath=%s resolvedPath=%s", tostring(configPath), tostring(resolvedConfigPath))
    if resolvedConfigPath == nil or resolvedConfigPath == "" then
        stWarn("Toggle config path is empty")
        self.toggleFeatures = {}
        return false
    end

    local xmlFile = loadXMLFile("svapaToggleFeaturesXML", resolvedConfigPath)
    if xmlFile == nil or xmlFile == 0 then
        stWarn("Could not load toggle config '%s'", tostring(resolvedConfigPath))
        self.toggleFeatures = {}
        return false
    end

    local loaded = {}
    local index = 0
    while true do
        local key = string.format("toggleFeatures.feature(%d)", index)
        if hasXMLProperty == nil or not hasXMLProperty(xmlFile, key) then
            break
        end

        local id = getXMLString(xmlFile, key .. "#id")
        local description = getXMLString(xmlFile, key .. "#description") or ""
        local defaultValue = getXMLBool(xmlFile, key .. "#default") == true
        local targetObject = getXMLString(xmlFile, key .. "#targetObject")
        local targetPath = getXMLString(xmlFile, key .. "#targetPath")
        local parentId = getXMLString(xmlFile, key .. "#parentId")

        if id ~= nil and id ~= "" then
            table.insert(loaded, {
                id = tostring(id),
                description = tostring(description),
                defaultValue = defaultValue,
                targetObject = targetObject ~= nil and tostring(targetObject) or nil,
                targetPath = targetPath ~= nil and tostring(targetPath) or nil,
                parentId = parentId ~= nil and tostring(parentId) or nil,
                value = nil
            })
            stDbg(
                "loadFeatures feature[%d] id=%s default=%s parentId=%s targetObject=%s targetPath=%s",
                index,
                tostring(id),
                tostring(defaultValue),
                tostring(parentId),
                tostring(targetObject),
                tostring(targetPath)
            )
        end

        index = index + 1
    end

    delete(xmlFile)
    self.toggleFeatures = loaded

    for _, feature in ipairs(self.toggleFeatures or {}) do
        local rawValue = self.toggleFeatureStates[tostring(feature.id)]
        if rawValue == nil then
            rawValue = feature.defaultValue == true
            self.toggleFeatureStates[tostring(feature.id)] = rawValue
        end
        feature.value = rawValue == true
    end

    stDbg("loadFeatures loadedCount=%d", #loaded)
    return true
end

function SvapaToggleManager:isToggleEnabled(toggleId, defaultValue)
    if self.isControllerActive ~= true then
        return defaultValue == true
    end

    self:ensureFeaturesLoadedForRuntime()
    return self:getEffectiveToggleValue(stMapLegacyToggleId(toggleId), defaultValue)
end

function SvapaToggleManager:applyFeatureToRuntime(feature)
    if feature == nil then
        stDbg("applyFeatureToRuntime skip: feature=nil")
        return true
    end

    if feature.targetObject == nil or feature.targetObject == "" or feature.targetPath == nil or feature.targetPath == "" then
        stDbg("applyFeatureToRuntime id=%s skip: no runtime target", tostring(feature.id))
        return true
    end

    local rootObject = stResolveGlobalObject(feature.targetObject)
    if rootObject == nil then
        stWarn("applyFeatureToRuntime id=%s targetObject=%s unresolved", tostring(feature.id), tostring(feature.targetObject))
        return false
    end

    local parent, fieldName = stResolveParentAndField(rootObject, feature.targetPath)
    if parent == nil or fieldName == nil then
        stWarn("applyFeatureToRuntime id=%s targetPath=%s unresolved", tostring(feature.id), tostring(feature.targetPath))
        return false
    end

    local value = self:getEffectiveToggleValue(feature.id, feature.defaultValue)
    local previous = parent[fieldName]
    parent[fieldName] = value
    stDbg("applyFeatureToRuntime id=%s target=%s.%s previous=%s new=%s", tostring(feature.id), tostring(feature.targetObject), tostring(feature.targetPath), tostring(previous), tostring(value))
    return true
end

function SvapaToggleManager:applyToggleTargets()
    if g_server == nil then
        stDbg("applyToggleTargets skipped on client")
        return true
    end

    if self.isControllerActive ~= true then
        stDbg("applyToggleTargets skipped: manager inactive until first save")
        self.lastRuntimeApplySuccess = true
        self.pendingRuntimeApply = false
        return true
    end

    local allResolved = true
    stDbg("applyToggleTargets start featureCount=%d", #(self.toggleFeatures or {}))

    for _, feature in ipairs(self.toggleFeatures or {}) do
        local ok = self:applyFeatureToRuntime(feature)
        if not ok then
            allResolved = false
        end
    end

    self.lastRuntimeApplySuccess = allResolved
    self.pendingRuntimeApply = not allResolved
    stDbg("applyToggleTargets done allResolved=%s pendingRuntimeApply=%s", tostring(allResolved), tostring(self.pendingRuntimeApply))
    return allResolved
end

function SvapaToggleManager:notifyExternalModulesAfterApply()
    if g_randomTheftEvents ~= nil and g_randomTheftEvents.applyExternalToggles ~= nil then
        local ok, err = pcall(function()
            g_randomTheftEvents:applyExternalToggles()
        end)

        if not ok then
            stWarn("notifyExternalModulesAfterApply failed for g_randomTheftEvents: %s", tostring(err))
        else
            stDbg("notifyExternalModulesAfterApply executed for g_randomTheftEvents")
        end
    end
end

function SvapaToggleManager:installSavegameHooks()
    if self.savegameHooksInstalled == true or g_currentMission == nil then
        return
    end

    local installed = false

    if type(g_currentMission.saveToXMLFile) == "function" then
        g_currentMission.saveToXMLFile = Utils.appendedFunction(g_currentMission.saveToXMLFile, function(...)
            self:saveToggleStateFile()
        end)
        installed = true
    end

    if type(g_currentMission.saveSavegame) == "function" then
        g_currentMission.saveSavegame = Utils.appendedFunction(g_currentMission.saveSavegame, function(...)
            self:saveToggleStateFile()
        end)
        installed = true
    end

    if installed then
        self.savegameHooksInstalled = true
        stDbg("Savegame hooks installed")
    else
        stWarn("No savegame hook target found for SvapaToggleManager")
    end
end

function SvapaToggleManager:sendAllStatesToConnection(connection)
    if g_server == nil or connection == nil then
        return
    end

    self:ensureFeaturesLoadedForRuntime()

    for _, feature in ipairs(self.toggleFeatures or {}) do
        local value = self:getEffectiveToggleValue(feature.id, feature.defaultValue)
        connection:sendEvent(SvapaToggleStateEvent.new(feature.id, value, false, false))
    end
end

function SvapaToggleManager:sendAllStates()
    if g_server == nil then
        return
    end

    self:ensureFeaturesLoadedForRuntime()

    for _, feature in ipairs(self.toggleFeatures or {}) do
        local value = self:getEffectiveToggleValue(feature.id, feature.defaultValue)
        g_server:broadcastEvent(SvapaToggleStateEvent.new(feature.id, value, false, false), nil, nil, nil)
    end
end

function SvapaToggleManager:update(dt)
    if self.pendingStateFileWrite == true then
        local stateFilePath = self:getStateFilePath()
        if stateFilePath ~= nil and stateFilePath ~= "" then
            stDbg("update detected savegame directory, flushing deferred toggle state save to %s", tostring(stateFilePath))
            self:saveToggleStateFile()
        end
    end
end

function SvapaToggleManager:getFeatureEntriesForTrigger(trigger)
    local result = {}
    if trigger == nil then
        return result
    end

    if not trigger:ensureConfigLoaded() then
        return result
    end

    for _, feature in ipairs(trigger.config.features or {}) do
        local isForcedOff = self:isFeatureForcedOff(feature)
        table.insert(result, {
            id = feature.id,
            description = feature.description,
            value = self:getEffectiveToggleValue(feature.id, feature.defaultValue),
            rawValue = self:getToggleValue(feature.id, feature.defaultValue),
            defaultValue = feature.defaultValue,
            parentId = feature.parentId,
            isDisabled = isForcedOff
        })
    end

    return result
end

function SvapaToggleManager:openGUI(trigger)
    if trigger == nil then
        stWarn("openGUI skipped: trigger=nil")
        return
    end
    stDbg("openGUI triggerNode=%s configPath=%s", tostring(trigger.triggerNode), tostring(trigger.configPath))

    if not trigger:ensureConfigLoaded() then
        return
    end

    if not self.canPlayerEdit or not self:canPlayerEdit() then
        return
    end

    if not self.guiLoaded then
        if SvapaToggleGUI == nil or SvapaToggleGUI.register == nil then
            stWarn("SvapaToggleGUI.register is not available")
            return
        end

        local ok, err = pcall(function()
            self.guiInstance = SvapaToggleGUI.register(ST_GUI_XML)
        end)

        if not ok or SvapaToggleGUI == nil or SvapaToggleGUI.instance == nil then
            stWarn("Failed to load GUI: %s", tostring(err))
            return
        end

        self.guiLoaded = true
    end

    SvapaToggleGUI.show(trigger)
    self.guiInstance = SvapaToggleGUI.instance
end

function SvapaToggleManager:scanToggleNodesRecursive(nodeId, result)
    if nodeId == nil or nodeId == 0 then
        return
    end

    local rawConfigPath = getUserAttribute ~= nil and getUserAttribute(nodeId, "toggleConfig") or nil
    if rawConfigPath ~= nil and rawConfigPath ~= "" then
        table.insert(result, {
            rootNode = nodeId,
            nodeId = stFindTriggerNode(nodeId),
            toggleConfig = rawConfigPath,
            actionText = getUserAttribute(nodeId, "actionText") or ""
        })
    end

    if getNumOfChildren == nil or getChildAt == nil then
        return
    end

    local childCount = getNumOfChildren(nodeId)
    for i = 0, childCount - 1 do
        self:scanToggleNodesRecursive(getChildAt(nodeId, i), result)
    end
end

function SvapaToggleManager:discoverTriggersFromScene()
    local found = {}
    local rootNode = getRootNode ~= nil and getRootNode() or nil
    if rootNode ~= nil then
        self:scanToggleNodesRecursive(rootNode, found)
    end

    for _, data in ipairs(found) do
        if data.rootNode ~= nil and self.toggleTriggerByNode[data.nodeId] == nil then
            self:addTrigger(data.rootNode, data.nodeId, data.toggleConfig, data.actionText)
        end
    end
end

function SvapaToggleManager:loadMap(mapNode, missionInfo, baseDirectory)
    stDbg("loadMap begin")
    self:loadToggleStateFile()
    self:installSavegameHooks()
    self.pendingRuntimeApply = false

    for _, data in ipairs(g_scriptToggleMenuOnCreateData) do
        if data.nodeId ~= nil and self.toggleTriggerByNode[data.nodeId] == nil then
            self:addTrigger(data.rootNode, data.nodeId, data.toggleConfig, data.actionText)
        end
    end

    self:discoverTriggersFromScene()
    self:ensureFeaturesLoadedForRuntime()
    stDbg("loadMap discoveredTriggers=%d onCreateQueued=%d featureCount=%d", #self.toggleTriggers, #g_scriptToggleMenuOnCreateData, #(self.toggleFeatures or {}))
    if self.isControllerActive == true then
        self:applyToggleTargets()
        self:notifyExternalModulesAfterApply()
    else
        stDbg("loadMap manager inactive: waiting for first manual save before controlling other mods")
    end
end

function SvapaToggleManager:loadMapFinished()
    stDbg("loadMapFinished begin guiLoaded=%s", tostring(self.guiLoaded))
    self:installSavegameHooks()
    if not self.guiLoaded then
        if SvapaToggleGUI ~= nil and SvapaToggleGUI.register ~= nil then
            local ok = pcall(function()
                self.guiInstance = SvapaToggleGUI.register(ST_GUI_XML)
            end)

            if ok and SvapaToggleGUI ~= nil and SvapaToggleGUI.instance ~= nil then
                self.guiLoaded = true
            end
        end
    end

    self:ensureFeaturesLoadedForRuntime()
    self.pendingRuntimeApply = false

    if g_server == nil and g_client ~= nil and g_client:getServerConnection() ~= nil then
        SvapaToggleStateEvent.sendSyncRequest(false)
    end

    if self.isControllerActive == true then
        self:applyToggleTargets()
        self:notifyExternalModulesAfterApply()
    end
end

function SvapaToggleManager:addTrigger(rootNode, triggerNode, rawConfigPath, actionText)
    stDbg("addTrigger root=%s trigger=%s rawConfig=%s actionText=%s", tostring(rootNode), tostring(triggerNode), tostring(rawConfigPath), tostring(actionText))
    if triggerNode == nil or triggerNode == 0 then
        stWarn("Cannot add toggle trigger: invalid node from root %s", tostring(rootNode))
        return nil
    end

    local configPath = stResolveConfigPath(rawConfigPath, stResolveModDir())
    local trigger = SvapaToggleTrigger.new(self, rootNode, triggerNode, configPath, actionText)
    table.insert(self.toggleTriggers, trigger)
    self.toggleTriggerByNode[triggerNode] = trigger

    local ok, err = pcall(function()
        addTrigger(triggerNode, "svapaToggleTriggerCallback", trigger)
    end)

    if not ok then
        stWarn("addTrigger FAILED for node=%s: %s", tostring(triggerNode), tostring(err))
    end

    return trigger
end

SvapaToggleActivatable = {}
local SvapaToggleActivatable_mt = Class(SvapaToggleActivatable)

function SvapaToggleActivatable.new(trigger)
    local self = setmetatable({}, SvapaToggleActivatable_mt)
    self.trigger = trigger
    self.activateText = trigger ~= nil and trigger:getActionText() or ""
    return self
end

function SvapaToggleActivatable:getIsActivatable()
    return self.trigger ~= nil and self.trigger:getIsActivatable()
end

function SvapaToggleActivatable:run()
    if self.trigger ~= nil then
        return self.trigger:onActivateObject()
    end
    return true
end

function SvapaToggleActivatable:getDistance(x, y, z)
    if self.trigger ~= nil and self.trigger.getDistance ~= nil then
        return self.trigger:getDistance(x, y, z)
    end
    return 0
end

function SvapaToggleActivatable:getText()
    return self.trigger ~= nil and self.trigger:getActionText() or ""
end

function SvapaToggleActivatable:getActivateText()
    return self.trigger ~= nil and self.trigger:getActionText() or self.activateText or ""
end

function SvapaToggleActivatable:updateActivateText()
    self.activateText = self.trigger ~= nil and self.trigger:getActionText() or ""
end

SvapaToggleTrigger = {}
local SvapaToggleTrigger_mt = Class(SvapaToggleTrigger)

function SvapaToggleTrigger.new(manager, rootNode, triggerNode, configPath, actionText)
    local self = setmetatable({}, SvapaToggleTrigger_mt)
    self.manager = manager
    self.rootNode = rootNode
    self.nodeId = rootNode
    self.triggerNode = triggerNode
    self.configPath = configPath
    self.actionText = stResolveActionText(actionText)
    self.activateText = self.actionText
    self.playerInside = false
    self.isRegistered = false
    self.activatable = SvapaToggleActivatable.new(self)
    self.config = nil
    return self
end

function SvapaToggleTrigger:loadConfig()
    if self.config ~= nil then
        return true
    end

    if self.configPath == nil or self.configPath == "" then
        stWarn("toggleConfig attribute is missing for toggle trigger node %s", tostring(self.nodeId))
        return false
    end

    local featuresLoaded = self.manager:loadFeatures(self.configPath)
    if not featuresLoaded then
        self.config = {features = {}}
        return false
    end

    self.config = {
        features = self.manager.toggleFeatures or {}
    }

    return true
end

function SvapaToggleTrigger:ensureConfigLoaded()
    if self.config ~= nil then
        return true
    end

    local ok, result = pcall(function()
        return self:loadConfig()
    end)

    return ok and result == true and self.config ~= nil
end

function SvapaToggleTrigger:getIsActivatable()
    local canEdit = true
    if self.manager ~= nil and self.manager.canPlayerEdit ~= nil then
        canEdit = self.manager:canPlayerEdit()
    end
    return self.playerInside == true and canEdit == true
end

function SvapaToggleTrigger:getDistance(x, y, z)
    return 0
end

function SvapaToggleTrigger:getActionText()
    return stResolveActionText(self.actionText or self.activateText)
end

function SvapaToggleTrigger:onActivateObject()
    if self.manager ~= nil then
        self.manager:openGUI(self)
    end
    return true
end

function SvapaToggleTrigger:registerActivatable()
    if not self.isRegistered and g_currentMission ~= nil and g_currentMission.activatableObjectsSystem ~= nil then
        self.activateText = self:getActionText()
        if self.activatable ~= nil then
            self.activatable.activateText = self.activateText
            if self.activatable.updateActivateText ~= nil then
                self.activatable:updateActivateText()
            end
        end
        g_currentMission.activatableObjectsSystem:addActivatable(self.activatable)
        self.isRegistered = true
    end
end

function SvapaToggleTrigger:unregisterActivatable()
    if self.isRegistered and g_currentMission ~= nil and g_currentMission.activatableObjectsSystem ~= nil then
        g_currentMission.activatableObjectsSystem:removeActivatable(self.activatable)
        self.isRegistered = false
    end
end

function SvapaToggleTrigger:svapaToggleTriggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
    local localPlayer = g_localPlayer
    if localPlayer == nil or localPlayer.rootNode == nil or otherActorId ~= localPlayer.rootNode then
        return
    end

    if onEnter then
        self.playerInside = true
        self:registerActivatable()
        if self.manager ~= nil then
            self.manager.playerToggleTrigger = self
        end
    elseif onLeave then
        self.playerInside = false
        self:unregisterActivatable()
        if self.manager ~= nil and self.manager.playerToggleTrigger == self then
            self.manager.playerToggleTrigger = nil
        end
    end
end

local function stEnsureOnCreateAliases(reason)
    local hasGlobal = type(_G["ScriptToggleMenuTrigger_onCreate"]) == "function"
    local hasModOnCreate = _G["modOnCreate"] ~= nil and type(_G["modOnCreate"].ScriptToggleMenuTrigger_onCreate) == "function"
    if not hasGlobal or not hasModOnCreate then
        stWarn("Missing ScriptToggleMenuTrigger_onCreate alias before %s, re-registering", tostring(reason))
    end
    stRegisterOnCreateAliases()
end

local function stLoadMission(mission)
    stEnsureOnCreateAliases("Mission00.load")
    if mission.svapaToggleManager == nil then
        mission.svapaToggleManager = SvapaToggleManager.new(mission)
        addModEventListener(mission.svapaToggleManager)
    end
end

local function stDeleteMission(mission)
    if mission ~= nil and mission.svapaToggleManager ~= nil then
        removeModEventListener(mission.svapaToggleManager)
        mission.svapaToggleManager:delete()
        mission.svapaToggleManager = nil
    end
end

function SvapaToggleManager:onPlayerConnectionFinishedLoading(connection)
    if g_server ~= nil and connection ~= nil then
        self:sendAllStatesToConnection(connection)
    end
end

local function stInstallMissionHooks()
    if SvapaToggleSystem._hooksInstalled then
        return
    end

    SvapaToggleSystem._hooksInstalled = true
    Mission00.load = Utils.prependedFunction(Mission00.load, stLoadMission)
    FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, stDeleteMission)
end

function SvapaToggleSystem.getManager()
    if g_currentMission ~= nil then
        return g_currentMission.svapaToggleManager
    end
    return nil
end

function SvapaToggleSystem.getToggleValue(selfOrToggleId, maybeToggleId, maybeDefaultValue)
    local toggleId = selfOrToggleId
    local defaultValue = maybeToggleId

    if type(selfOrToggleId) == "table" then
        toggleId = maybeToggleId
        defaultValue = maybeDefaultValue
    end

    local manager = SvapaToggleSystem.getManager()
    if manager ~= nil then
        local resolvedId = stResolveToggleIdForLookup(manager, toggleId)
        local managerValue = manager.toggleFeatureStates ~= nil and manager.toggleFeatureStates[tostring(resolvedId)] or nil
        if managerValue ~= nil then
            if manager.isControllerActive == true then
                return manager:getEffectiveToggleValue(resolvedId, managerValue == true)
            end
            return defaultValue == true
        end

        manager:ensureFeaturesLoadedForRuntime()
        return manager:isToggleEnabled(resolvedId, defaultValue)
    end

    local fallbackStateStore = stGetSharedToggleStateStore()
    local mappedToggleId = stResolveToggleIdForLookup(nil, toggleId)
    local fallbackValue = fallbackStateStore[tostring(mappedToggleId)]
    if fallbackValue ~= nil then
        return fallbackValue == true
    end

    return defaultValue == true
end

SvapaToggleSystem.getIsEnabled = SvapaToggleSystem.getToggleValue
SvapaToggleSystem.isEnabled = SvapaToggleSystem.getToggleValue
SvapaToggleSystem.getFeatureState = SvapaToggleSystem.getToggleValue
SvapaToggleSystem.getValue = SvapaToggleSystem.getToggleValue

_G.SvapaToggleBridge = SvapaToggleSystem
_G.g_svapaToggleBridge = SvapaToggleSystem
stDbg("bridge aliases registered: SvapaToggleBridge and g_svapaToggleBridge")

stInstallMissionHooks()