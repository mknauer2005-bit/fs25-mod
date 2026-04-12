UniversalDisplay = {}
UniversalDisplay.MOD_NAME = g_currentModName
UniversalDisplay.MOD_DIR = g_currentModDirectory

local UD_STATIC_MOD_NAME = g_currentModName
local UD_LOG_PREFIX = "[UniversalDisplay]"
local UD_MOD_DIR = UniversalDisplay.MOD_DIR or g_currentModDirectory or ""
local UD_DEBUG = false

local function udFormatLogMessage(message, ...)
    local template = tostring(message or "")
    local argsCount = select("#", ...)
    if argsCount == 0 then
        return template
    end

    local ok, formatted = pcall(string.format, template, ...)
    if ok then
        return formatted
    end

    return template
end

local function udLog(message, ...)
    if not UD_DEBUG then
        return
    end

    print(string.format("%s [DEBUG] %s", UD_LOG_PREFIX, udFormatLogMessage(message, ...)))
end

local function udWarn(message, ...)
    print(string.format("%s [WARN] %s", UD_LOG_PREFIX, udFormatLogMessage(message, ...)))
end

local function udError(message, ...)
    print(string.format("%s [ERROR] %s", UD_LOG_PREFIX, udFormatLogMessage(message, ...)))
end

local udIsValidNode

local function udSafeRemoveTrigger(triggerNode)
    if triggerNode == nil or triggerNode == 0 or not udIsValidNode(triggerNode) then
        return
    end

    local ok, err = pcall(removeTrigger, triggerNode)
    if not ok then
        udWarn("udSafeRemoveTrigger failed for node=%s: %s", tostring(triggerNode), tostring(err))
    end
end

local function udNormalizeDir(dir)
    if dir == nil or dir == "" then
        return ""
    end

    if dir:sub(-1) ~= "/" and dir:sub(-1) ~= "\\" then
        dir = dir .. "/"
    end

    return dir
end

local function udResolveModDir()
    if UD_MOD_DIR ~= nil and UD_MOD_DIR ~= "" then
        return udNormalizeDir(UD_MOD_DIR)
    end

    if UniversalDisplay.MOD_DIR ~= nil and UniversalDisplay.MOD_DIR ~= "" then
        return udNormalizeDir(UniversalDisplay.MOD_DIR)
    end

    if g_currentModDirectory ~= nil and g_currentModDirectory ~= "" then
        return udNormalizeDir(g_currentModDirectory)
    end

    return ""
end



local function udParseColor3(rawValue, fallback)
    if rawValue == nil or rawValue == "" then
        return fallback
    end

    local result = {}
    for token in tostring(rawValue):gmatch("[^%s,;]+") do
        local value = tonumber(token)
        if value ~= nil then
            table.insert(result, value)
        end
        if #result >= 3 then
            break
        end
    end

    if #result < 3 then
        return fallback
    end

    return result
end

local function udExposeGlobal(name, value)
    _G[name] = value

    local rootEnv = getfenv ~= nil and getfenv(0) or nil
    if rootEnv ~= nil then
        rootEnv[name] = value
    end
end

local function udTryGetText(key)
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

local function udResolveActionText(rawText)
    local fallback = udTryGetText("action_activateObject") or udTryGetText("action_open") or "Show statistics"

    if rawText == nil or rawText == "" then
        return fallback
    end

    if type(rawText) ~= "string" then
        return tostring(rawText)
    end

    if rawText:sub(1, 6) == "$l10n_" then
        local key = rawText:sub(7)
        return udTryGetText(key) or fallback
    end

    if rawText:match("^[%a_][%w_%.%-]*$") ~= nil then
        local translated = udTryGetText(rawText)
        if translated ~= nil and translated ~= "" then
            return translated
        end
    end

    return rawText
end

udIsValidNode = function(nodeId)
    if nodeId == nil or nodeId == 0 then
        return false
    end

    if entityExists ~= nil then
        local ok, exists = pcall(entityExists, nodeId)
        if ok then
            return exists == true
        end
    end

    return true
end

local function udNodeName(nodeId)
    if nodeId == nil or nodeId == 0 or getName == nil or not udIsValidNode(nodeId) then
        return "nil"
    end

    local ok, name = pcall(getName, nodeId)
    if ok and name ~= nil and name ~= "" then
        return tostring(name)
    end

    return tostring(nodeId)
end

local function udFindChildByName(nodeId, wantedName)
    if nodeId == nil or nodeId == 0 or wantedName == nil or wantedName == "" or not udIsValidNode(nodeId) then
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
        local found = udFindChildByName(child, wantedName)
        if found ~= nil then
            return found
        end
    end

    return nil
end

local function udNodeLooksLikeTrigger(nodeId)
    if nodeId == nil or nodeId == 0 then
        return false
    end

    local name = string.lower(udNodeName(nodeId))
    if name == "ut_playertrigger" or name == "playertrigger" or name == "interactiontrigger" or name == "gs_playertrigger" then
        return true
    end
    if string.find(name, "trigger", 1, true) ~= nil then
        return true
    end
    if string.find(name, "col", 1, true) ~= nil then
        return true
    end
    if string.find(name, "interaction", 1, true) ~= nil then
        return true
    end
    return false
end

local function udFindTriggerNode(rootNode)
    if rootNode == nil or rootNode == 0 or not udIsValidNode(rootNode) then
        return nil
    end

    local exactNames = {
        "ut_playerTrigger",
        "playerTrigger",
        "interactionTrigger",
        "gs_playerTrigger"
    }

    for _, wantedName in ipairs(exactNames) do
        local found = udFindChildByName(rootNode, wantedName)
        if found ~= nil then
            return found
        end
    end

    if udNodeLooksLikeTrigger(rootNode) then
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

        if current ~= rootNode and udNodeLooksLikeTrigger(current) then
            return current
        end

        if udIsValidNode(current) then
            local count = getNumOfChildren(current)
            for i = 0, count - 1 do
                local child = getChildAt(current, i)
                if udIsValidNode(child) then
                    table.insert(queue, child)
                end
            end
        end
    end

    return rootNode
end

g_universalDisplayOnCreateData = g_universalDisplayOnCreateData or {}

local function udGetMapDir()
    if g_currentMission ~= nil and g_currentMission.baseDirectory ~= nil then
        return udNormalizeDir(g_currentMission.baseDirectory)
    end

    return ""
end

local function udIsAbsolutePath(path)
    if path == nil or path == "" then
        return false
    end

    local normalized = tostring(path):gsub("\\", "/")
    if normalized:match("^[A-Za-z]:/") ~= nil then
        return true
    end

    if normalized:sub(1, 1) == "/" then
        return true
    end

    if normalized:sub(1, 2) == "//" then
        return true
    end

    return false
end

local function udSafeReplace(value, pattern, replacement)
    if value == nil then
        return nil
    end

    return tostring(value):gsub(pattern, function()
        return tostring(replacement or "")
    end)
end

local function udResolveConfigPath(rawPath, baseDir)
    if rawPath == nil or rawPath == "" then
        return nil
    end

    local result = tostring(rawPath)
    result = udSafeReplace(result, "%$moddir%$", udResolveModDir())
    result = udSafeReplace(result, "%$mapdir%$", udGetMapDir())

    if udIsAbsolutePath(result) then
        return result
    end

    local resolvedBaseDir = baseDir or udResolveModDir()
    local resolved = Utils.getFilename(result, resolvedBaseDir)
    return resolved
end

local function udResolveNodeObject(nodeId)
    if g_currentMission == nil or nodeId == nil or not udIsValidNode(nodeId) then
        return nil
    end

    local currentNode = nodeId
    while currentNode ~= nil and currentNode ~= 0 and udIsValidNode(currentNode) do
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

local function udIsPlayerActor(otherActorId, otherShapeId)
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

    local objectFromShape = udResolveNodeObject(otherShapeId)
    local objectFromActor = udResolveNodeObject(otherActorId)

    return objectFromShape == player or objectFromShape == localPlayer or objectFromActor == player or objectFromActor == localPlayer
end

local function udGetFarmId()
    if g_currentMission == nil then
        return AccessHandler.EVERYONE
    end

    if g_currentMission.missionDynamicInfo ~= nil and g_currentMission.missionDynamicInfo.isMultiplayer and g_localPlayer ~= nil then
        return g_localPlayer:getFarmId()
    end

    if g_currentMission.getFarmId ~= nil then
        local farmId = g_currentMission:getFarmId()
        if farmId ~= nil then
            return farmId
        end
    end

    return FarmManager.SINGLEPLAYER_FARM_ID or 1
end

local function udGetFarmlandProgressGate()
    local gate = rawget(_G, "FarmlandProgressGate")
    if gate ~= nil and type(gate.getMetricSnapshotForFarm) == "function" then
        return gate
    end

    return nil
end

local function udResolveDisplayNode(rootNode, nodeRef)
    if rootNode == nil or rootNode == 0 or nodeRef == nil or nodeRef == "" or not udIsValidNode(rootNode) then
        return nil
    end

    local exact = udFindChildByName(rootNode, nodeRef)
    if exact ~= nil then
        return exact
    end

    local normalized = tostring(nodeRef):gsub("\\", "/")
    local current = rootNode

    for segment in string.gmatch(normalized, "[^/]+") do
        local nextNode = nil
        if current ~= nil and udIsValidNode(current) and getNumOfChildren ~= nil and getChildAt ~= nil then
            local count = getNumOfChildren(current)
            for i = 0, count - 1 do
                local child = getChildAt(current, i)
                if udIsValidNode(child) and getName ~= nil and getName(child) == segment then
                    nextNode = child
                    break
                end
            end
        end

        if nextNode == nil then
            current = nil
            break
        end

        current = nextNode
    end

    return current
end

local function udDeleteXmlFile(xmlFile)
    if xmlFile == nil or xmlFile == 0 then
        return
    end

    if type(xmlFile) == "table" and xmlFile.delete ~= nil then
        xmlFile:delete()
    else
        delete(xmlFile)
    end
end

local function udGetLocalUserId()
    if g_localPlayer ~= nil and g_localPlayer.userId ~= nil then
        return g_localPlayer.userId
    end

    if g_currentMission ~= nil and g_currentMission.player ~= nil and g_currentMission.player.userId ~= nil then
        return g_currentMission.player.userId
    end

    return 0
end

local function udGetPlayerDataFromConnection(connection)
    if connection == nil or g_currentMission == nil then
        return nil, nil
    end

    local player = nil
    if g_currentMission.getPlayerByConnection ~= nil then
        player = g_currentMission:getPlayerByConnection(connection)
    end

    if player ~= nil then
        return player, player.farmId
    end

    if g_currentMission.userManager ~= nil and g_currentMission.userManager.getUserIdByConnection ~= nil and g_farmManager ~= nil and g_farmManager.getFarmByUserId ~= nil then
        local userId = g_currentMission.userManager:getUserIdByConnection(connection)
        if userId ~= nil then
            local farm = g_farmManager:getFarmByUserId(userId)
            if farm ~= nil then
                return nil, farm.farmId
            end
        end
    end

    return nil, nil
end

UniversalDisplayRequestEvent = {}
local UniversalDisplayRequestEvent_mt = Class(UniversalDisplayRequestEvent, Event)
InitEventClass(UniversalDisplayRequestEvent, "UniversalDisplayRequestEvent")

function UniversalDisplayRequestEvent.emptyNew()
    return Event.new(UniversalDisplayRequestEvent_mt)
end

function UniversalDisplayRequestEvent.new(displayId, clearDisplay)
    local self = UniversalDisplayRequestEvent.emptyNew()
    self.displayId = displayId or 0
    self.clearDisplay = clearDisplay == true
    return self
end

function UniversalDisplayRequestEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.displayId or 0)
    streamWriteBool(streamId, self.clearDisplay == true)
end

function UniversalDisplayRequestEvent:readStream(streamId, connection)
    self.displayId = streamReadInt32(streamId)
    self.clearDisplay = streamReadBool(streamId)
    self:run(connection)
end

function UniversalDisplayRequestEvent:run(connection)
    if connection == nil or connection:getIsServer() or g_currentMission == nil or g_currentMission.universalDisplayManager == nil then
        return
    end

    local manager = g_currentMission.universalDisplayManager
    local display = manager:getDisplayById(self.displayId)
    if display == nil then
        return
    end

    if self.clearDisplay then
        display:handleServerClearRequest(connection)
    else
        display:handleServerActivateRequest(connection)
    end
end

function UniversalDisplayRequestEvent.sendEvent(displayId, clearDisplay)
    if g_currentMission ~= nil and g_currentMission:getIsServer() and g_client == nil then
        local manager = g_currentMission.universalDisplayManager
        if manager ~= nil then
            local display = manager:getDisplayById(displayId)
            if display ~= nil then
                if clearDisplay == true then
                    display:handleServerClearRequest(nil)
                else
                    display:handleServerActivateRequest(nil)
                end
            end
        end
    elseif g_client ~= nil and g_client.getServerConnection ~= nil then
        g_client:getServerConnection():sendEvent(UniversalDisplayRequestEvent.new(displayId, clearDisplay))
    end
end

UniversalDisplaySyncEvent = {}
local UniversalDisplaySyncEvent_mt = Class(UniversalDisplaySyncEvent, Event)
InitEventClass(UniversalDisplaySyncEvent, "UniversalDisplaySyncEvent")

function UniversalDisplaySyncEvent.emptyNew()
    return Event.new(UniversalDisplaySyncEvent_mt)
end

function UniversalDisplaySyncEvent.new(displayId, clearDisplay, texts, farmId, ownerUserId)
    local self = UniversalDisplaySyncEvent.emptyNew()
    self.displayId = displayId or 0
    self.clearDisplay = clearDisplay == true
    self.texts = texts or {}
    self.farmId = farmId or 0
    self.ownerUserId = ownerUserId or 0
    return self
end

function UniversalDisplaySyncEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.displayId or 0)
    streamWriteBool(streamId, self.clearDisplay == true)
    streamWriteInt32(streamId, self.farmId or 0)
    streamWriteInt32(streamId, self.ownerUserId or 0)

    local count = math.min(#(self.texts or {}), 255)
    streamWriteUInt8(streamId, count)
    for i = 1, count do
        streamWriteString(streamId, tostring(self.texts[i] or ""))
    end
end

function UniversalDisplaySyncEvent:readStream(streamId, connection)
    self.displayId = streamReadInt32(streamId)
    self.clearDisplay = streamReadBool(streamId)
    self.farmId = streamReadInt32(streamId)
    self.ownerUserId = streamReadInt32(streamId)

    local count = streamReadUInt8(streamId)
    self.texts = {}
    for i = 1, count do
        self.texts[i] = streamReadString(streamId)
    end

    self:run(connection)
end

function UniversalDisplaySyncEvent:run(connection)
    if g_currentMission == nil or g_currentMission.universalDisplayManager == nil then
        return
    end

    local display = g_currentMission.universalDisplayManager:getDisplayById(self.displayId)
    if display == nil then
        return
    end

    if self.clearDisplay then
        display:applyDisplayTexts(nil, 0, 0)
    else
        display:applyDisplayTexts(self.texts or {}, self.farmId or 0, self.ownerUserId or 0)
    end
end

function UniversalDisplay_onCreate(nodeId)
    local rawConfigPath = getUserAttribute(nodeId, "displayConfig")
    local actionTextRaw = getUserAttribute(nodeId, "actionText")
    if actionTextRaw == nil or actionTextRaw == "" then
        actionTextRaw = "$l10n_action_showStatistics"
    end
    local actionText = udResolveActionText(actionTextRaw)
    local triggerNode = udFindTriggerNode(nodeId)

    table.insert(g_universalDisplayOnCreateData, {
        rootNode = nodeId,
        nodeId = triggerNode,
        displayConfig = rawConfigPath,
        actionText = actionText
    })
end

local function udRegisterOnCreateAliases()
    local modName = g_currentModName or UD_STATIC_MOD_NAME or UniversalDisplay.MOD_NAME

    if modName ~= nil and modName ~= "" then
        _G[modName] = _G[modName] or {}
        _G[modName].UniversalDisplay_onCreate = UniversalDisplay_onCreate
    end

    _G.modOnCreate = _G.modOnCreate or {}
    _G.modOnCreate.UniversalDisplay_onCreate = UniversalDisplay_onCreate

    UniversalDisplay.onCreate = UniversalDisplay_onCreate
    udExposeGlobal("UniversalDisplay_onCreate", UniversalDisplay_onCreate)
end

udRegisterOnCreateAliases()

UniversalDisplayManager = {}
local UniversalDisplayManager_mt = Class(UniversalDisplayManager)

function UniversalDisplayManager.new(mission)
    local self = setmetatable({}, UniversalDisplayManager_mt)

    self.mission = mission
    self.displays = {}
    self.displayByNode = {}
    self.displayById = {}
    self.nextDisplayId = 1
    self.playerDisplay = nil

    return self
end

function UniversalDisplayManager:delete()
    for _, display in ipairs(self.displays) do
        if display.isRegistered then
            g_currentMission.activatableObjectsSystem:removeActivatable(display.activatable)
            display.isRegistered = false
        end

        if display.triggerNode ~= nil then
            udSafeRemoveTrigger(display.triggerNode)
            display.triggerNode = nil
        end

        if display.config ~= nil and display.config.xmlFile ~= nil then
            udDeleteXmlFile(display.config.xmlFile)
            display.config.xmlFile = nil
        end

        if display.delete ~= nil then
            display:delete()
        end
    end

    self.displays = {}
    self.displayByNode = {}
    self.displayById = {}
    self.playerDisplay = nil
end

function UniversalDisplayManager:getDisplayById(displayId)
    if displayId == nil or displayId == 0 then
        return nil
    end

    return self.displayById[displayId]
end

function UniversalDisplayManager:scanDisplayNodesRecursive(nodeId, result)
    if nodeId == nil or nodeId == 0 or not udIsValidNode(nodeId) then
        return
    end

    local rawConfigPath = getUserAttribute ~= nil and getUserAttribute(nodeId, "displayConfig") or nil
    if rawConfigPath ~= nil and rawConfigPath ~= "" then
        local actionText = getUserAttribute(nodeId, "actionText") or "$l10n_action_showStatistics"
        table.insert(result, {
            rootNode = nodeId,
            nodeId = udFindTriggerNode(nodeId),
            displayConfig = rawConfigPath,
            actionText = actionText
        })
    end

    if getNumOfChildren == nil or getChildAt == nil then
        return
    end

    local childCount = getNumOfChildren(nodeId)
    for i = 0, childCount - 1 do
        local child = getChildAt(nodeId, i)
        if udIsValidNode(child) then
            self:scanDisplayNodesRecursive(child, result)
        end
    end
end

function UniversalDisplayManager:discoverDisplaysFromScene()
    local found = {}
    local rootNode = getRootNode ~= nil and getRootNode() or nil
    if rootNode ~= nil then
        self:scanDisplayNodesRecursive(rootNode, found)
    end

    for _, data in ipairs(found) do
        if data.rootNode ~= nil and self.displayByNode[data.nodeId] == nil then
            self:addDisplay(data.rootNode, data.nodeId, data.displayConfig, data.actionText)
        end
    end
end

function UniversalDisplayManager:loadMap(mapNode, missionInfo, baseDirectory)
    for _, data in ipairs(g_universalDisplayOnCreateData) do
        if data.nodeId ~= nil and self.displayByNode[data.nodeId] == nil then
            self:addDisplay(data.rootNode, data.nodeId, data.displayConfig, data.actionText)
        end
    end

    self:discoverDisplaysFromScene()
end

function UniversalDisplayManager:loadMapFinished()
end

function UniversalDisplayManager:addDisplay(rootNode, triggerNode, rawConfigPath, actionText)
    if triggerNode == nil or triggerNode == 0 or not udIsValidNode(triggerNode) or not udIsValidNode(rootNode) then
        udError("Cannot add display: invalid trigger node from root %s", tostring(rootNode))
        return nil
    end

    local configPath = udResolveConfigPath(rawConfigPath)
    local networkId = self.nextDisplayId
    self.nextDisplayId = self.nextDisplayId + 1

    local display = UniversalDisplayRuntime.new(self, rootNode, triggerNode, configPath, actionText, networkId)
    table.insert(self.displays, display)
    self.displayByNode[triggerNode] = display
    self.displayById[networkId] = display

    local ok, err = pcall(function()
        addTrigger(triggerNode, "universalDisplayTriggerCallback", display)
    end)

    if not ok then
        udError("addTrigger FAILED for node=%s: %s", tostring(triggerNode), tostring(err))
    end

    return display
end

function UniversalDisplayManager:onClientJoined(connection)
    if connection == nil then
        return
    end

    for _, display in ipairs(self.displays) do
        if display ~= nil and display.currentTexts ~= nil and #display.currentTexts > 0 then
            connection:sendEvent(UniversalDisplaySyncEvent.new(display.networkId, false, display.currentTexts, display.lastFarmId or 0, display.activeOwnerUserId or 0))
        end
    end
end

UniversalDisplayActivatable = {}
local UniversalDisplayActivatable_mt = Class(UniversalDisplayActivatable)

function UniversalDisplayActivatable.new(display)
    local self = setmetatable({}, UniversalDisplayActivatable_mt)
    self.display = display
    self.activateText = display ~= nil and display:getActionText() or ""
    return self
end

function UniversalDisplayActivatable:getIsActivatable()
    return self.display ~= nil and self.display:getIsActivatable()
end

function UniversalDisplayActivatable:run()
    if self.display ~= nil then
        return self.display:onActivateObject()
    end
    return true
end

function UniversalDisplayActivatable:getDistance(x, y, z)
    if self.display ~= nil and self.display.getDistance ~= nil then
        return self.display:getDistance(x, y, z)
    end
    return 0
end

function UniversalDisplayActivatable:getText()
    return self.display ~= nil and self.display:getActionText() or ""
end

function UniversalDisplayActivatable:getActivateText()
    return self.display ~= nil and self.display:getActionText() or self.activateText or ""
end

function UniversalDisplayActivatable:updateActivateText()
    self.activateText = self.display ~= nil and self.display:getActionText() or ""
end

UniversalDisplayRuntime = {}
local UniversalDisplayRuntime_mt = Class(UniversalDisplayRuntime)

function UniversalDisplayRuntime.new(manager, rootNode, triggerNode, configPath, actionText, networkId)
    local self = setmetatable({}, UniversalDisplayRuntime_mt)

    self.manager = manager
    self.rootNode = rootNode
    self.nodeId = rootNode
    self.triggerNode = triggerNode
    self.networkId = networkId or 0
    self.actionText = udResolveActionText(actionText)
    self.playerInside = false
    self.isRegistered = false
    self.isDeleting = false
    self.activateText = self.actionText
    self.activatable = UniversalDisplayActivatable.new(self)
    self.configPath = configPath
    self.config = nil
    self.lastFarmId = nil
    self.activeOwnerUserId = 0
    self.currentTexts = nil
    self.localOwnsActiveDisplay = false

    return self
end

function UniversalDisplayRuntime:delete()
    self.isDeleting = true
    self.playerInside = false
    self:unregisterActivatable()
    self:clearDisplays()

    if self.config ~= nil and self.config.displays ~= nil then
        for _, display in ipairs(self.config.displays) do
            if display.characterLine ~= nil and display.characterLine.rootNode ~= nil and delete ~= nil then
                delete(display.characterLine.rootNode)
            end
            display.characterLine = nil
        end
    end
end

function UniversalDisplayRuntime:loadConfig()
    if self.config ~= nil then
        return true
    end

    if self.isDeleting then
        return false
    end

    if self.configPath == nil then
        udError("displayConfig attribute is missing for display root node %s", tostring(self.nodeId))
        return false
    end

    if not udIsValidNode(self.rootNode) then
        udWarn("Skipping config load because root node is no longer valid for display '%s'", tostring(self.configPath))
        return false
    end

    local xmlFile = loadXMLFile("universalDisplayConfigXML", self.configPath)
    if xmlFile == nil or xmlFile == 0 then
        udError("Could not load display config '%s'", tostring(self.configPath))
        return false
    end

    local config = {
        xmlFile = xmlFile,
        displays = {}
    }

    local triggerNodeName = getXMLString(xmlFile, "universalDisplay#triggerNode")
    if triggerNodeName ~= nil and triggerNodeName ~= "" then
        local resolvedTriggerNode = udResolveDisplayNode(self.rootNode, triggerNodeName)
        if resolvedTriggerNode ~= nil then
            self.triggerNode = resolvedTriggerNode
        else
            udWarn("Configured trigger node '%s' was not found under root '%s'", tostring(triggerNodeName), tostring(udNodeName(self.rootNode)))
        end
    end

    local index = 0
    while true do
        local key = string.format("universalDisplay.display(%d)", index)
        if hasXMLProperty == nil or not hasXMLProperty(xmlFile, key) then
            break
        end

        local nodeRef = getXMLString(xmlFile, key .. "#node")
        local displayNode = udResolveDisplayNode(self.rootNode, nodeRef)

        if displayNode ~= nil then
            local fontName = string.upper(getXMLString(xmlFile, key .. "#font") or "DIGIT")
            local fontMaterial = g_materialManager ~= nil and g_materialManager:getFontMaterial(fontName, nil) or nil
            if fontMaterial ~= nil then
                local display = {}
                local alignmentStr = getXMLString(xmlFile, key .. "#alignment") or "RIGHT"
                local alignment = RenderText["ALIGN_" .. string.upper(alignmentStr)] or RenderText.ALIGN_RIGHT
                local size = getXMLFloat(xmlFile, key .. "#size") or 0.03
                local scaleX = getXMLFloat(xmlFile, key .. "#scaleX") or 1
                local scaleY = getXMLFloat(xmlFile, key .. "#scaleY") or 1
                local mask = getXMLString(xmlFile, key .. "#mask") or "000"
                local emissiveScale = getXMLFloat(xmlFile, key .. "#emissiveScale") or 0.2
                local color = getXMLString(xmlFile, key .. "#color")
                local hiddenColor = getXMLString(xmlFile, key .. "#hiddenColor")
                local colorValue = nil
                local hiddenColorValue = nil

                if color ~= nil and color ~= "" then
                    colorValue = udParseColor3(color, {0.9, 0.9, 0.9})
                else
                    colorValue = {0.9, 0.9, 0.9, 1}
                end

                if hiddenColor ~= nil and hiddenColor ~= "" then
                    hiddenColorValue = udParseColor3(hiddenColor, nil)
                end

                display.nodeRef = nodeRef
                display.displayNode = displayNode
                display.metricName = getXMLString(xmlFile, key .. "#metric")
                display.fieldName = getXMLString(xmlFile, key .. "#field") or "available"
                display.defaultText = getXMLString(xmlFile, key .. "#defaultText") or ""
                display.mask = mask
                display.formatStr, display.formatPrecision = Utils.maskToFormat(mask)
                display.characterLine = CharacterLine.new(displayNode, fontMaterial, mask:len())
                display.characterLine:setSizeAndScale(size, scaleX, scaleY)
                display.characterLine:setTextAlignment(alignment)
                display.characterLine:setColor(colorValue, hiddenColorValue, emissiveScale)
                display.characterLine:setText(display.defaultText)

                table.insert(config.displays, display)
            else
                udWarn("Font material '%s' not found for display node '%s'", tostring(fontName), tostring(nodeRef))
            end
        else
            udWarn("Display node '%s' not found under root '%s'", tostring(nodeRef), tostring(udNodeName(self.rootNode)))
        end

        index = index + 1
    end

    self.config = config
    return true
end

function UniversalDisplayRuntime:ensureConfigLoaded()
    if self.config ~= nil then
        return true
    end

    local ok, result = pcall(function()
        return self:loadConfig()
    end)

    if not ok then
        udError("ensureConfigLoaded failed for '%s': %s", tostring(self.configPath), tostring(result))
        return false
    end

    if result ~= true or self.config == nil then
        udError("ensureConfigLoaded could not prepare config for '%s'", tostring(self.configPath))
        return false
    end

    return true
end

function UniversalDisplayRuntime:getIsActivatable()
    return self.playerInside == true
end

function UniversalDisplayRuntime:getDistance(x, y, z)
    return 0
end

function UniversalDisplayRuntime:getActionText()
    return udResolveActionText(self.actionText or self.activateText)
end

function UniversalDisplayRuntime:formatDisplayValue(display, rawValue)
    local value = tonumber(rawValue) or 0

    if math.abs(value) < 0.00001 then
        return "0"
    end

    local precision = tonumber(display ~= nil and display.formatPrecision or 0) or 0
    local absValue = math.abs(value)
    local sign = value < 0 and "-" or ""

    if precision <= 0 then
        local rounded = math.floor(absValue + 0.5)
        return sign .. tostring(rounded)
    end

    local formatStr = "%." .. tostring(precision) .. "f"
    local formatted = string.format(formatStr, absValue)

    if string.find(formatted, ".", 1, true) ~= nil then
        formatted = formatted:gsub("0+$", ""):gsub("%.$", "")
    end

    if formatted == "" then
        formatted = "0"
    end

    return sign .. formatted
end

function UniversalDisplayRuntime:collectDisplayTextsForFarm(farmId)
    if self.config == nil or self.config.displays == nil then
        return nil
    end

    local gate = udGetFarmlandProgressGate()
    if gate == nil then
        udWarn("FarmlandProgressGate is not available, display cannot be refreshed")
        return nil
    end

    local texts = {}

    for index, display in ipairs(self.config.displays) do
        local textToShow = display.defaultText or ""
        if display.metricName ~= nil and display.metricName ~= "" then
            local snapshot = gate:getMetricSnapshotForFarm(farmId, display.metricName)
            if snapshot ~= nil then
                local fieldName = tostring(display.fieldName or "available")
                local rawValue = snapshot[fieldName]
                if rawValue == nil and fieldName == "value" then
                    rawValue = snapshot.earned
                end
                if rawValue ~= nil then
                    textToShow = self:formatDisplayValue(display, rawValue)
                end
            end
        end

        texts[index] = textToShow
    end

    return texts
end

function UniversalDisplayRuntime:applyDisplayTexts(texts, farmId, ownerUserId)
    if texts == nil then
        if self.config ~= nil and self.config.displays ~= nil then
            for _, display in ipairs(self.config.displays) do
                if display.characterLine ~= nil then
                    display.characterLine:setText(display.defaultText or "")
                end
            end
        end

        self.currentTexts = nil
        self.lastFarmId = nil
        self.activeOwnerUserId = 0
        self.localOwnsActiveDisplay = false
        return true
    end

    if not self:ensureConfigLoaded() then
        return false
    end

    if self.config == nil or self.config.displays == nil then
        return false
    end

    for index, display in ipairs(self.config.displays) do
        if display.characterLine ~= nil then
            display.characterLine:setText(tostring(texts[index] or display.defaultText or ""))
        end
    end

    self.currentTexts = texts
    self.lastFarmId = farmId or 0
    self.activeOwnerUserId = ownerUserId or 0
    self.localOwnsActiveDisplay = (self.activeOwnerUserId ~= 0 and self.activeOwnerUserId == udGetLocalUserId())

    return true
end

function UniversalDisplayRuntime:broadcastDisplayTexts(texts, farmId, ownerUserId)
    self:applyDisplayTexts(texts, farmId, ownerUserId)

    if g_server ~= nil then
        g_server:broadcastEvent(UniversalDisplaySyncEvent.new(self.networkId, false, texts, farmId, ownerUserId), false)
    end
end

function UniversalDisplayRuntime:broadcastClearDisplay()
    self:applyDisplayTexts(nil, 0, 0)

    if g_server ~= nil then
        g_server:broadcastEvent(UniversalDisplaySyncEvent.new(self.networkId, true, nil, 0, 0), false)
    end
end

function UniversalDisplayRuntime:handleServerActivateRequest(connection)
    if not self:ensureConfigLoaded() then
        return false
    end

    local farmId = nil
    local ownerUserId = 0

    if connection ~= nil then
        local player = nil
        player, farmId = udGetPlayerDataFromConnection(connection)
        if player ~= nil and player.userId ~= nil then
            ownerUserId = player.userId
        end
    else
        farmId = udGetFarmId()
        ownerUserId = udGetLocalUserId()
    end

    if farmId == nil or farmId == 0 then
        return false
    end

    local texts = self:collectDisplayTextsForFarm(farmId)
    if texts == nil then
        self:broadcastClearDisplay()
        return false
    end

    self:broadcastDisplayTexts(texts, farmId, ownerUserId)
    return true
end

function UniversalDisplayRuntime:handleServerClearRequest(connection)
    if connection ~= nil then
        local player = nil
        player = udGetPlayerDataFromConnection(connection)
        local requestUserId = player ~= nil and player.userId or 0
        if self.activeOwnerUserId ~= 0 and requestUserId ~= self.activeOwnerUserId then
            return false
        end
    end

    self:broadcastClearDisplay()
    return true
end

function UniversalDisplayRuntime:refreshForFarm(farmId)
    local texts = self:collectDisplayTextsForFarm(farmId)
    if texts == nil then
        self:applyDisplayTexts(nil, 0, 0)
        return false
    end

    return self:applyDisplayTexts(texts, farmId, udGetLocalUserId())
end

function UniversalDisplayRuntime:clearDisplays()
    self:applyDisplayTexts(nil, 0, 0)
end

function UniversalDisplayRuntime:onActivateObject()
    if not self:ensureConfigLoaded() then
        return true
    end

    UniversalDisplayRequestEvent.sendEvent(self.networkId, false)
    return true
end

function UniversalDisplayRuntime:registerActivatable()
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

function UniversalDisplayRuntime:unregisterActivatable()
    if self.isRegistered and g_currentMission ~= nil and g_currentMission.activatableObjectsSystem ~= nil then
        g_currentMission.activatableObjectsSystem:removeActivatable(self.activatable)
        self.isRegistered = false
    end
end

function UniversalDisplayRuntime:universalDisplayTriggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
    if not udIsPlayerActor(otherActorId, otherShapeId) then
        return
    end

    if onEnter then
        self.playerInside = true
        self:registerActivatable()
        if self.manager ~= nil then
            self.manager.playerDisplay = self
        end
    elseif onLeave then
        self.playerInside = false
        self:unregisterActivatable()
        if self.localOwnsActiveDisplay then
            UniversalDisplayRequestEvent.sendEvent(self.networkId, true)
        end
        if self.manager ~= nil and self.manager.playerDisplay == self then
            self.manager.playerDisplay = nil
        end
    end
end

local function udEnsureOnCreateAliases(reason)
    local hasGlobal = type(_G["UniversalDisplay_onCreate"]) == "function"
    local hasModOnCreate = _G["modOnCreate"] ~= nil and type(_G["modOnCreate"].UniversalDisplay_onCreate) == "function"

    if not hasGlobal or not hasModOnCreate then
        udWarn("Missing UniversalDisplay onCreate alias before %s, re-registering", tostring(reason))
    end

    udRegisterOnCreateAliases()
end

local function udLoadMission(mission)
    udEnsureOnCreateAliases("Mission00.load")

    if mission.universalDisplayManager == nil then
        mission.universalDisplayManager = UniversalDisplayManager.new(mission)
        addModEventListener(mission.universalDisplayManager)
    end
end

local function udDeleteMission(mission)
    if mission ~= nil and mission.universalDisplayManager ~= nil then
        removeModEventListener(mission.universalDisplayManager)
        mission.universalDisplayManager:delete()
        mission.universalDisplayManager = nil
    end
end

local function udInstallMissionHooks()
    if UniversalDisplay._hooksInstalled then
        return
    end
    UniversalDisplay._hooksInstalled = true

    Mission00.load = Utils.prependedFunction(Mission00.load, udLoadMission)
    FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, udDeleteMission)
end

udInstallMissionHooks()