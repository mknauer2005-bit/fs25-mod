SvapaToggleSystem = SvapaToggleSystem or {}
SvapaToggleSystem.MOD_NAME = g_currentModName
SvapaToggleSystem.MOD_DIR = g_currentModDirectory

local ST_LOG_PREFIX = "[SvapaToggleManager]"
local ST_MOD_DIR = SvapaToggleSystem.MOD_DIR or g_currentModDirectory or ""
local ST_GUI_XML = (ST_MOD_DIR ~= "" and (ST_MOD_DIR:gsub('\\','/')) or "") .. "scripts/ToggleSystem/gui/SvapaToggleGUI.xml"

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

g_scriptToggleMenuOnCreateData = g_scriptToggleMenuOnCreateData or {}

function ScriptToggleMenuTrigger_onCreate(nodeId)
    local rawConfigPath = getUserAttribute(nodeId, "toggleConfig")
    local actionTextRaw = getUserAttribute(nodeId, "actionText")
    local actionText = stResolveActionText(actionTextRaw)
    local triggerNode = stFindTriggerNode(nodeId)

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
    self.toggleFeatureStates = {}
    self.toggleFeatures = {}
    self.stateFileName = "svapaToggleStates.xml"
    self.pendingRuntimeApply = true
    self.lastRuntimeApplySuccess = false
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
    self.toggleFeatureStates = {}

    local stateFilePath = self:getStateFilePath()
    if stateFilePath == nil or stateFilePath == "" or fileExists == nil or not fileExists(stateFilePath) then
        return false
    end

    local xmlFile = loadXMLFile("svapaToggleStatesXML", stateFilePath)
    if xmlFile == nil or xmlFile == 0 then
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
            self.toggleFeatureStates[tostring(id)] = value == true
        end

        index = index + 1
    end

    delete(xmlFile)
    return true
end

function SvapaToggleManager:saveToggleStateFile()
    local stateFilePath = self:getStateFilePath()
    if stateFilePath == nil or stateFilePath == "" then
        stWarn("Save skipped: savegame directory is unavailable")
        return false
    end

    local xmlFile = createXMLFile("svapaToggleStatesXML", stateFilePath, "toggleStates")
    if xmlFile == nil or xmlFile == 0 then
        stWarn("Could not create toggle state file '%s'", tostring(stateFilePath))
        return false
    end

    local index = 0
    for _, feature in ipairs(self.toggleFeatures or {}) do
        local key = string.format("toggleStates.state(%d)", index)
        setXMLString(xmlFile, key .. "#id", tostring(feature.id))
        setXMLBool(xmlFile, key .. "#value", self:getToggleValue(feature.id, feature.defaultValue))
        index = index + 1
    end

    saveXMLFile(xmlFile)
    delete(xmlFile)

    self.pendingRuntimeApply = true
    self:applyToggleTargets()

    return true
end

function SvapaToggleManager:loadFeatures(configPath)
    local resolvedConfigPath = stResolveConfigPath(configPath, stResolveModDir())
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

        if id ~= nil and id ~= "" then
            table.insert(loaded, {
                id = tostring(id),
                description = tostring(description),
                defaultValue = defaultValue,
                targetObject = targetObject ~= nil and tostring(targetObject) or nil,
                targetPath = targetPath ~= nil and tostring(targetPath) or nil
            })
        end

        index = index + 1
    end

    delete(xmlFile)
    self.toggleFeatures = loaded
    return true
end

function SvapaToggleManager:getToggleValue(toggleId, defaultValue)
    local value = self.toggleFeatureStates[tostring(toggleId)]
    if value == nil then
        return defaultValue == true
    end
    return value == true
end

function SvapaToggleManager:setToggleValue(toggleId, value)
    self.toggleFeatureStates[tostring(toggleId)] = value == true
    self.pendingRuntimeApply = true
end

function SvapaToggleManager:getFeatureById(toggleId)
    for _, feature in ipairs(self.toggleFeatures or {}) do
        if tostring(feature.id) == tostring(toggleId) then
            return feature
        end
    end
    return nil
end

function SvapaToggleManager:isToggleEnabled(toggleId, defaultValue)
    local feature = self:getFeatureById(toggleId)
    if feature ~= nil then
        return self:getToggleValue(feature.id, feature.defaultValue)
    end
    return self:getToggleValue(toggleId, defaultValue)
end

function SvapaToggleManager:applyFeatureToRuntime(feature)
    if feature == nil or feature.targetObject == nil or feature.targetObject == "" or feature.targetPath == nil or feature.targetPath == "" then
        return true
    end

    local rootObject = stResolveGlobalObject(feature.targetObject)
    if rootObject == nil then
        return false
    end

    local parent, fieldName = stResolveParentAndField(rootObject, feature.targetPath)
    if parent == nil or fieldName == nil then
        return false
    end

    parent[fieldName] = self:getToggleValue(feature.id, feature.defaultValue)
    return true
end

function SvapaToggleManager:applyToggleTargets()
    local allResolved = true

    for _, feature in ipairs(self.toggleFeatures or {}) do
        local ok = self:applyFeatureToRuntime(feature)
        if not ok then
            allResolved = false
        end
    end

    self.lastRuntimeApplySuccess = allResolved
    self.pendingRuntimeApply = not allResolved
    return allResolved
end

function SvapaToggleManager:update(dt)
    if self.pendingRuntimeApply then
        self:applyToggleTargets()
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
        table.insert(result, {
            id = feature.id,
            description = feature.description,
            value = self:getToggleValue(feature.id, feature.defaultValue),
            defaultValue = feature.defaultValue
        })
    end

    return result
end

function SvapaToggleManager:openGUI(trigger)
    if trigger == nil then
        return
    end

    if not trigger:ensureConfigLoaded() then
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
    self:loadToggleStateFile()
    self.pendingRuntimeApply = true

    for _, data in ipairs(g_scriptToggleMenuOnCreateData) do
        if data.nodeId ~= nil and self.toggleTriggerByNode[data.nodeId] == nil then
            self:addTrigger(data.rootNode, data.nodeId, data.toggleConfig, data.actionText)
        end
    end

    self:discoverTriggersFromScene()
    self:applyToggleTargets()
end

function SvapaToggleManager:loadMapFinished()
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

    self.pendingRuntimeApply = true
    self:applyToggleTargets()
end

function SvapaToggleManager:addTrigger(rootNode, triggerNode, rawConfigPath, actionText)
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
    return self.playerInside == true
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
    if not stIsPlayerActor(otherActorId, otherShapeId) then
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

function SvapaToggleSystem.getToggleValue(toggleId, defaultValue)
    local manager = SvapaToggleSystem.getManager()
    if manager ~= nil then
        return manager:isToggleEnabled(toggleId, defaultValue)
    end
    return defaultValue == true
end

SvapaToggleSystem.getIsEnabled = SvapaToggleSystem.getToggleValue
SvapaToggleSystem.isEnabled = SvapaToggleSystem.getToggleValue
SvapaToggleSystem.getFeatureState = SvapaToggleSystem.getToggleValue
SvapaToggleSystem.getValue = SvapaToggleSystem.getToggleValue

stInstallMissionHooks()
