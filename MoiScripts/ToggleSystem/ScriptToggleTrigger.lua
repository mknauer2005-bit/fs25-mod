ScriptToggleMenuTrigger = {}
local ScriptToggleMenuTrigger_mt = Class(ScriptToggleMenuTrigger)

local SVAPA_TOGGLE_DEBUG = true
local STS_TRIGGER_MOD_NAME = g_currentModName
local STS_TRIGGER_MOD_DIR = g_currentModDirectory

ScriptToggleMenuTriggerRegistry = {
    byRootNode = {},
    list = {}
}

local function debugConcat(...)
    local values = {...}
    local parts = {}

    for i = 1, #values do
        parts[i] = tostring(values[i])
    end

    return table.concat(parts, " ")
end

local function debugPrint(...)
    if SVAPA_TOGGLE_DEBUG then
        print("[SVAPA_TOGGLE] " .. debugConcat(...))
    end
end

local function debugWarning(...)
    if SVAPA_TOGGLE_DEBUG then
        print("[SVAPA_TOGGLE][WARN] " .. debugConcat(...))
    end
end

local function normalizeDir(dir)
    if dir == nil then
        return nil
    end

    local value = tostring(dir)
    if value == "" then
        return nil
    end

    local lastChar = value:sub(-1)
    if lastChar ~= "/" and lastChar ~= "\\" then
        value = value .. "/"
    end

    return value
end

local function resolveModDir()
    local current = normalizeDir(g_currentModDirectory)
    if current ~= nil then
        STS_TRIGGER_MOD_DIR = current
    end

    debugPrint("Trigger resolveModDir modName=", STS_TRIGGER_MOD_NAME)
    debugPrint("Trigger resolveModDir result=", STS_TRIGGER_MOD_DIR)

    return STS_TRIGGER_MOD_DIR
end

local function getUserAttributeValue(nodeId, attrName)
    local value = getUserAttribute(nodeId, attrName)
    if value == nil then
        return nil
    end

    return value
end

local function isPlayerActor(otherId, otherShapeId)
    local mission = g_currentMission
    if mission == nil then
        return false
    end

    local localPlayer = g_localPlayer
    local missionPlayer = mission.player

    local function matchesPlayer(playerObj)
        if playerObj == nil then
            return false
        end

        if playerObj.rootNode ~= nil and (otherId == playerObj.rootNode or otherShapeId == playerObj.rootNode) then
            return true
        end

        if playerObj.graphicsRootNode ~= nil and (otherId == playerObj.graphicsRootNode or otherShapeId == playerObj.graphicsRootNode) then
            return true
        end

        if playerObj.cameraNode ~= nil and (otherId == playerObj.cameraNode or otherShapeId == playerObj.cameraNode) then
            return true
        end

        return false
    end

    return matchesPlayer(localPlayer) or matchesPlayer(missionPlayer)
end

local function findChildNodeByName(nodeId, wantedName)
    if nodeId == nil or wantedName == nil then
        return nil
    end

    local childCount = getNumOfChildren(nodeId)
    for i = 0, childCount - 1 do
        local child = getChildAt(nodeId, i)
        if getName(child) == wantedName then
            return child
        end

        local nested = findChildNodeByName(child, wantedName)
        if nested ~= nil then
            return nested
        end
    end

    return nil
end

local function findFirstTriggerChild(nodeId)
    local childCount = getNumOfChildren(nodeId)
    for i = 0, childCount - 1 do
        local child = getChildAt(nodeId, i)
        local childName = string.lower(getName(child) or "")

        if string.find(childName, "trigger", 1, true) ~= nil then
            return child
        end

        local nested = findFirstTriggerChild(child)
        if nested ~= nil then
            return nested
        end
    end

    return nil
end

local function registryAdd(trigger)
    ScriptToggleMenuTriggerRegistry.byRootNode[trigger.rootNode] = trigger
    table.insert(ScriptToggleMenuTriggerRegistry.list, trigger)
end

local function registryRemove(trigger)
    ScriptToggleMenuTriggerRegistry.byRootNode[trigger.rootNode] = nil
    for i = #ScriptToggleMenuTriggerRegistry.list, 1, -1 do
        if ScriptToggleMenuTriggerRegistry.list[i] == trigger then
            table.remove(ScriptToggleMenuTriggerRegistry.list, i)
            break
        end
    end
end

function ScriptToggleMenuTrigger:onCreate(id)
    if g_currentMission == nil then
        return
    end

    if ScriptToggleMenuTriggerRegistry.byRootNode[id] ~= nil then
        debugWarning("Skipping duplicate onCreate for root node", id)
        return
    end

    local trigger = ScriptToggleMenuTrigger.new(id)
    if trigger ~= nil then
        g_currentMission:addNonUpdateable(trigger)
        registryAdd(trigger)
        debugPrint("Trigger created via onCreate. rootNode=", id, "triggerNode=", trigger.triggerNode)
    end
end

function ScriptToggleMenuTrigger_onCreate(id)
    ScriptToggleMenuTrigger:onCreate(id)
end

local function registerOnCreateAliases()
    _G.ScriptToggleMenuTrigger_onCreate = ScriptToggleMenuTrigger_onCreate
    _G["ScriptToggleMenuTrigger.onCreate"] = ScriptToggleMenuTrigger_onCreate
    debugPrint("onCreate alias registered: ScriptToggleMenuTrigger_onCreate")
    debugPrint("onCreate alias registered: ScriptToggleMenuTrigger.onCreate")

    if _G.modOnCreate ~= nil and type(_G.modOnCreate) == "table" then
        _G.modOnCreate["ScriptToggleMenuTrigger_onCreate"] = ScriptToggleMenuTrigger_onCreate
        _G.modOnCreate["ScriptToggleMenuTrigger.onCreate"] = ScriptToggleMenuTrigger_onCreate
        debugPrint("modOnCreate alias registered: ScriptToggleMenuTrigger_onCreate")
        debugPrint("modOnCreate alias registered: ScriptToggleMenuTrigger.onCreate")
    end
end

function ScriptToggleMenuTrigger.new(rootNode)
    local self = setmetatable({}, ScriptToggleMenuTrigger_mt)

    self.rootNode = rootNode
    self.playerInside = false

    local configuredTriggerName = getUserAttributeValue(rootNode, "triggerNodeName")
    local triggerNode = nil
    if configuredTriggerName ~= nil and tostring(configuredTriggerName) ~= "" then
        triggerNode = findChildNodeByName(rootNode, tostring(configuredTriggerName))
    end

    if triggerNode == nil then
        triggerNode = findFirstTriggerChild(rootNode)
    end

    if triggerNode == nil then
        triggerNode = rootNode
        debugWarning("No explicit trigger child found. Falling back to rootNode", rootNode)
    end

    self.triggerNode = triggerNode

    local actionText = getUserAttributeValue(rootNode, "actionText")
    if actionText == nil or tostring(actionText) == "" then
        actionText = g_i18n:getText("action_openMenu")
    end

    self.activatable = ScriptToggleMenuTriggerActivatable.new(self, actionText)

    local ok, err = pcall(function()
        addTrigger(self.triggerNode, "triggerCallback", self)
    end)

    if not ok then
        debugWarning("Failed addTrigger for node", self.triggerNode, "error", err)
        return nil
    end

    debugPrint("Trigger registered. triggerNode=", self.triggerNode)
    return self
end

function ScriptToggleMenuTrigger:registerActivatable()
    if g_currentMission ~= nil and self.activatable ~= nil then
        g_currentMission.activatableObjectsSystem:addActivatable(self.activatable)
    end
end

function ScriptToggleMenuTrigger:unregisterActivatable()
    if g_currentMission ~= nil and self.activatable ~= nil then
        g_currentMission.activatableObjectsSystem:removeActivatable(self.activatable)
    end
end

function ScriptToggleMenuTrigger:delete()
    self:unregisterActivatable()

    if self.triggerNode ~= nil then
        removeTrigger(self.triggerNode)
        self.triggerNode = nil
    end

    registryRemove(self)
end

function ScriptToggleMenuTrigger:triggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
    debugPrint("triggerCallback called. triggerId=", triggerId, "otherId=", otherId, "otherShapeId=", otherShapeId, "onEnter=", onEnter, "onLeave=", onLeave)

    if not isPlayerActor(otherId, otherShapeId) then
        debugPrint("player ignored")
        return
    end

    if onEnter then
        self.playerInside = true
        self:registerActivatable()
        debugPrint("player accepted. activatable added")
    elseif onLeave then
        self.playerInside = false
        self:unregisterActivatable()
        debugPrint("player accepted. activatable removed")
    end
end

ScriptToggleMenuTriggerActivatable = {}
local ScriptToggleMenuTriggerActivatable_mt = Class(ScriptToggleMenuTriggerActivatable)

function ScriptToggleMenuTriggerActivatable.new(owner, activateText)
    local self = setmetatable({}, ScriptToggleMenuTriggerActivatable_mt)
    self.owner = owner
    self.activateText = activateText
    return self
end

function ScriptToggleMenuTriggerActivatable:getText()
    return self.activateText
end

function ScriptToggleMenuTriggerActivatable:getActivateText()
    return self.activateText
end

function ScriptToggleMenuTriggerActivatable:updateActivateText(newText)
    if newText ~= nil and newText ~= "" then
        self.activateText = newText
    end
end

function ScriptToggleMenuTriggerActivatable:getIsActivatable()
    return self.owner.playerInside and g_currentMission ~= nil and g_currentMission.svapaScriptToggleManager ~= nil
end

function ScriptToggleMenuTriggerActivatable:getDistance(x, y, z)
    return 0
end

function ScriptToggleMenuTriggerActivatable:run()
    debugPrint("activatable run invoked")
    if g_currentMission ~= nil and g_currentMission.svapaScriptToggleManager ~= nil then
        g_currentMission.svapaScriptToggleManager:requestOpenScreen("mapTrigger")
    end
end

ScriptToggleTriggerBootstrap = {}

function ScriptToggleTriggerBootstrap:deleteMap()
    for i = #ScriptToggleMenuTriggerRegistry.list, 1, -1 do
        local trigger = ScriptToggleMenuTriggerRegistry.list[i]
        if trigger ~= nil then
            trigger:delete()
        end
    end

    ScriptToggleMenuTriggerRegistry.byRootNode = {}
    ScriptToggleMenuTriggerRegistry.list = {}
end

resolveModDir()
registerOnCreateAliases()
addModEventListener(ScriptToggleTriggerBootstrap)
