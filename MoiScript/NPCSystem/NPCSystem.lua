NPCSystem = {}
local NPCSystem_mt = Class(NPCSystem)

NPCSystem.INTERACTION_TYPES = {
    INTERNAL_DIALOG = "internalDialog",
    EXTERNAL_GUI = "externalGui",
    EXTERNAL_ACTION = "externalAction",
    INFO_ONLY = "infoOnly",
    CONFIRM_ACTION = "confirmAction",
    MISSION_HUB = "missionHub",
    DISABLED = "disabled"
}

NPCSystem.ROLES = {
    FOREMAN = "foreman",
    CLERK = "clerk",
    MANAGER = "manager",
    HELPER = "helper",
    STORYTELLER = "storyteller",
    MISSION_GIVER = "missionGiver",
    GENERIC = "generic"
}

NPCSystem.DEBUG_PREFIX = "[NPCSystem]"
NPCSystem.DEFAULT_CONFIG_XML_PATH = "map/config/npcs.xml"

function NPCSystem.new(mission, modDirectory, modName)
    local self = setmetatable({}, NPCSystem_mt)

    self.mission = mission
    self.modDirectory = modDirectory
    self.modName = modName

    self.npcs = {}
    self.externalActions = {}
    self.externalGuis = {}
    self.dialogDefinitions = {}

    self.dialogController = nil
    self.debugEnabled = true

    return self
end

function NPCSystem:debugLog(message)
    if self.debugEnabled then
        Logging.info("%s %s", NPCSystem.DEBUG_PREFIX, tostring(message))
    end
end

function NPCSystem:init()
    self:registerDefaultDialogDefinitions()
end

function NPCSystem:registerDefaultDialogDefinitions()
    self.dialogDefinitions.foremanMain = {
        title = "$l10n_npc_foreman_title",
        greeting = "$l10n_npc_foreman_greeting",
        body = "$l10n_npc_foreman_description",
        mode = "menu",
        buttons = {
            {actionId = "constructionStatus", text = "$l10n_npc_btn_status"},
            {actionId = "constructionStart", text = "$l10n_npc_btn_start"},
            {actionId = "close", text = "$l10n_button_back"}
        }
    }

    self.dialogDefinitions.foremanMaterialsMissing = {
        title = "$l10n_npc_foreman_title",
        greeting = "$l10n_npc_foreman_greeting",
        body = "$l10n_npc_foreman_materials_missing",
        mode = "info",
        nextAction = "close"
    }

    self.dialogDefinitions.foremanReadyToStart = {
        title = "$l10n_npc_foreman_title",
        greeting = "$l10n_npc_foreman_greeting",
        body = "$l10n_npc_foreman_ready",
        mode = "confirm",
        nextAction = "constructionStart"
    }

    self.dialogDefinitions.clerkMain = {
        title = "$l10n_npc_clerk_title",
        greeting = "$l10n_npc_clerk_greeting",
        body = "$l10n_npc_clerk_description",
        mode = "menu",
        buttons = {
            {actionId = "openExternalGui", text = "$l10n_npc_btn_open"},
            {actionId = "close", text = "$l10n_button_back"}
        }
    }

    self.dialogDefinitions.reputationInfo = {
        title = "$l10n_npc_reputation_title",
        greeting = "$l10n_npc_reputation_greeting",
        body = "$l10n_npc_reputation_body",
        mode = "info"
    }

    self.dialogDefinitions.genericInfo = {
        title = "$l10n_npc_generic_title",
        greeting = "$l10n_npc_generic_greeting",
        body = "$l10n_npc_generic_body",
        mode = "info"
    }

    self.dialogDefinitions.missionHubPlaceholder = {
        title = "$l10n_npc_mission_hub_title",
        greeting = "$l10n_npc_mission_hub_greeting",
        body = "$l10n_npc_mission_hub_placeholder",
        mode = "menu",
        buttons = {
            {actionId = "showMissionList", text = "$l10n_npc_btn_missions"},
            {actionId = "close", text = "$l10n_button_back"}
        }
    }
end

function NPCSystem:setDialogController(dialogController)
    self.dialogController = dialogController
end

function NPCSystem:loadNPCConfig(xmlFilename)
    local xmlFile = XMLFile.loadIfExists("NPCConfig", xmlFilename)
    if xmlFile == nil then
        self:debugLog(string.format("Could not load NPC config '%s'", tostring(xmlFilename)))
        return false
    end

    local i = 0
    while true do
        local key = string.format("npcs.npc(%d)", i)
        if not xmlFile:hasProperty(key .. "#id") then
            break
        end

        local npcData = {
            id = xmlFile:getString(key .. "#id"),
            npcName = xmlFile:getString(key .. "#npcName", "NPC"),
            uniqueId = xmlFile:getString(key .. "#uniqueId", ""),
            type = xmlFile:getString(key .. "#type", NPCSystem.ROLES.GENERIC),
            interactionType = xmlFile:getString(key .. "#interactionType", NPCSystem.INTERACTION_TYPES.INFO_ONLY),
            title = xmlFile:getString(key .. "#title", ""),
            greeting = xmlFile:getString(key .. "#greeting", ""),
            description = xmlFile:getString(key .. "#description", ""),
            triggerNode = xmlFile:getString(key .. "#triggerNode", ""),
            interactionRadius = xmlFile:getFloat(key .. "#interactionRadius", 2.0),
            isEnabled = xmlFile:getBool(key .. "#isEnabled", true),
            buildingId = xmlFile:getString(key .. "#buildingId", ""),
            productionId = xmlFile:getString(key .. "#productionId", ""),
            farmlandId = xmlFile:getString(key .. "#farmlandId", ""),
            externalActionId = xmlFile:getString(key .. "#externalActionId", ""),
            externalGuiId = xmlFile:getString(key .. "#externalGuiId", ""),
            internalDialogId = xmlFile:getString(key .. "#internalDialogId", "genericInfo"),
            state = xmlFile:getString(key .. "#state", "idle"),
            missionId = xmlFile:getString(key .. "#missionId", ""),
            missionState = xmlFile:getString(key .. "#missionState", "inactive"),
            missionPayload = xmlFile:getString(key .. "#missionPayload", ""),
            siteState = xmlFile:getString(key .. "#siteState", "idle"),
            requiredMaterialsReady = xmlFile:getBool(key .. "#requiredMaterialsReady", false),
            constructionRunning = xmlFile:getBool(key .. "#constructionRunning", false),
            constructionFinished = xmlFile:getBool(key .. "#constructionFinished", false),
            lastInteractionTime = 0,
            flags = {}
        }

        self:registerNPC(npcData)
        i = i + 1
    end

    xmlFile:delete()
    self:debugLog(string.format("Loaded %d NPC entries", i))

    return true
end

function NPCSystem:registerNPC(data)
    if data == nil or data.id == nil or data.id == "" then
        self:debugLog("registerNPC called with invalid data")
        return false
    end

    self.npcs[data.id] = data
    return true
end

function NPCSystem:unregisterNPC(npcId)
    self.npcs[npcId] = nil
end

function NPCSystem:getNPCById(npcId)
    return self.npcs[npcId]
end

function NPCSystem:getMissionAndPlayer()
    local mission = self.mission ~= nil and self.mission or g_currentMission
    if mission == nil then
        return nil, nil
    end

    return mission, mission.player
end

function NPCSystem:resolveNPCTriggerNode(npc)
    if npc == nil or npc.triggerNode == nil or npc.triggerNode == "" then
        return nil
    end

    local nodeId = tonumber(npc.triggerNode)
    if nodeId ~= nil and nodeId ~= 0 then
        return nodeId
    end

    -- TODO: Map-specific string trigger bindings should be resolved externally and written back to npc.triggerNode.
    return nil
end

function NPCSystem:getNearestNPC()
    local mission, player = self:getMissionAndPlayer()
    if mission == nil or player == nil or player.rootNode == nil then
        return nil
    end

    local px, _, pz = getWorldTranslation(player.rootNode)
    local bestDistanceSq = math.huge
    local bestNpc = nil

    for _, npc in pairs(self.npcs) do
        if npc.isEnabled and npc.interactionType ~= NPCSystem.INTERACTION_TYPES.DISABLED then
            local triggerNode = self:resolveNPCTriggerNode(npc)
            if triggerNode ~= nil then
                local nx, _, nz = getWorldTranslation(triggerNode)
                local dx = nx - px
                local dz = nz - pz
                local distanceSq = dx * dx + dz * dz
                local radiusSq = npc.interactionRadius * npc.interactionRadius

                if distanceSq <= radiusSq and distanceSq < bestDistanceSq then
                    bestDistanceSq = distanceSq
                    bestNpc = npc
                end
            end
        end
    end

    return bestNpc
end

function NPCSystem:canInteractWithNPC(npcId)
    local npc = self:getNPCById(npcId)
    if npc == nil or not npc.isEnabled then
        return false
    end

    return npc.interactionType ~= NPCSystem.INTERACTION_TYPES.DISABLED
end

function NPCSystem:interactWithNPC(npcId)
    if not self:canInteractWithNPC(npcId) then
        return false
    end

    local mission = self.mission ~= nil and self.mission or g_currentMission
    local npc = self:getNPCById(npcId)
    npc.lastInteractionTime = mission ~= nil and mission.environment.currentDayTime or 0

    if npc.interactionType == NPCSystem.INTERACTION_TYPES.INTERNAL_DIALOG
        or npc.interactionType == NPCSystem.INTERACTION_TYPES.MISSION_HUB
        or npc.interactionType == NPCSystem.INTERACTION_TYPES.INFO_ONLY
        or npc.interactionType == NPCSystem.INTERACTION_TYPES.CONFIRM_ACTION then
        return self:openInternalDialog(npcId)
    elseif npc.interactionType == NPCSystem.INTERACTION_TYPES.EXTERNAL_GUI then
        return self:openExternalGui(npcId)
    elseif npc.interactionType == NPCSystem.INTERACTION_TYPES.EXTERNAL_ACTION then
        return self:executeExternalAction(npcId)
    end

    return false
end

function NPCSystem:openInternalDialog(npcId)
    local payload = self:buildDialogPayload(npcId)
    if payload == nil or self.dialogController == nil then
        return false
    end

    self.dialogController:showDialog(payload)
    return true
end

function NPCSystem:invokeRegistryEntry(registry, id, npc, context)
    local entry = registry[id]
    if entry == nil then
        return false
    end

    if entry.target ~= nil then
        entry.callback(entry.target, npc, context)
    else
        entry.callback(npc, context)
    end

    return true
end

function NPCSystem:openExternalGui(npcId)
    local npc = self:getNPCById(npcId)
    if npc == nil or npc.externalGuiId == "" then
        return false
    end

    local context = self:buildExternalContext(npcId, nil)
    if not self:invokeRegistryEntry(self.externalGuis, npc.externalGuiId, npc, context) then
        self:debugLog(string.format("External GUI '%s' is not registered", npc.externalGuiId))
        return false
    end

    return true
end

function NPCSystem:executeExternalAction(npcId)
    local npc = self:getNPCById(npcId)
    if npc == nil or npc.externalActionId == "" then
        return false
    end

    local context = self:buildExternalContext(npcId, nil)
    if not self:invokeRegistryEntry(self.externalActions, npc.externalActionId, npc, context) then
        self:debugLog(string.format("External action '%s' is not registered", npc.externalActionId))
        return false
    end

    return true
end

function NPCSystem:registerExternalAction(actionId, callback, target)
    if actionId == nil or actionId == "" or callback == nil then
        return false
    end

    self.externalActions[actionId] = {callback = callback, target = target}
    return true
end

function NPCSystem:unregisterExternalAction(actionId)
    self.externalActions[actionId] = nil
end

function NPCSystem:registerExternalGui(guiId, callback, target)
    if guiId == nil or guiId == "" or callback == nil then
        return false
    end

    self.externalGuis[guiId] = {callback = callback, target = target}
    return true
end

function NPCSystem:unregisterExternalGui(guiId)
    self.externalGuis[guiId] = nil
end

function NPCSystem:buildDialogPayload(npcId)
    local npc = self:getNPCById(npcId)
    if npc == nil then
        return nil
    end

    local dialogId = npc.internalDialogId ~= "" and npc.internalDialogId or "genericInfo"
    if npc.interactionType == NPCSystem.INTERACTION_TYPES.MISSION_HUB then
        dialogId = "missionHubPlaceholder"
    end

    local preset = self.dialogDefinitions[dialogId] or self.dialogDefinitions.genericInfo
    local mode = preset.mode or "info"

    if npc.interactionType == NPCSystem.INTERACTION_TYPES.INFO_ONLY then
        mode = "info"
    elseif npc.interactionType == NPCSystem.INTERACTION_TYPES.CONFIRM_ACTION then
        mode = "confirm"
    elseif npc.interactionType == NPCSystem.INTERACTION_TYPES.EXTERNAL_ACTION
        or npc.interactionType == NPCSystem.INTERACTION_TYPES.EXTERNAL_GUI then
        mode = "externalProxy"
    end

    return {
        npcId = npc.id,
        npcName = npc.npcName,
        npcType = npc.type,
        interactionType = npc.interactionType,
        title = npc.title ~= "" and npc.title or preset.title,
        greeting = npc.greeting ~= "" and npc.greeting or preset.greeting,
        body = npc.description ~= "" and npc.description or preset.body,
        description = npc.description,
        mode = mode,
        buttons = preset.buttons,
        nextAction = preset.nextAction,
        context = self:buildExternalContext(npcId, nil)
    }
end

function NPCSystem:onDialogAction(npcId, actionId, payload)
    local npc = self:getNPCById(npcId)
    if npc == nil then
        return false
    end

    if actionId == "close" then
        return true
    elseif actionId == "openExternalGui" then
        return self:openExternalGui(npcId)
    elseif actionId == "constructionStatus" then
        return self:openConstructionDialog(npcId)
    elseif actionId == "constructionStart" then
        return self:startConstructionFromDialog(npcId)
    elseif actionId == "confirmExternalAction" then
        return self:executeExternalAction(npcId)
    elseif actionId == "showMissionList" then
        -- TODO: Replace placeholder when mission system is implemented.
        return self:openInternalDialog(npcId)
    end

    if npc.externalActionId ~= "" then
        return self:executeExternalAction(npcId)
    end

    return false
end

function NPCSystem:getNPCState(npcId)
    local npc = self:getNPCById(npcId)
    return npc ~= nil and npc.state or nil
end

function NPCSystem:setNPCState(npcId, state)
    local npc = self:getNPCById(npcId)
    if npc == nil then
        return false
    end

    npc.state = state
    return true
end

function NPCSystem:buildExternalContext(npcId, customPayload)
    local npc = self:getNPCById(npcId)
    if npc == nil then
        return nil
    end

    return {
        npcId = npc.id,
        npcType = npc.type,
        buildingId = npc.buildingId,
        productionId = npc.productionId,
        farmlandId = npc.farmlandId,
        state = npc.state,
        siteState = npc.siteState,
        requiredMaterialsReady = npc.requiredMaterialsReady,
        constructionRunning = npc.constructionRunning,
        constructionFinished = npc.constructionFinished,
        missionId = npc.missionId,
        missionState = npc.missionState,
        missionPayload = npc.missionPayload,
        payload = customPayload
    }
end

function NPCSystem:canStartConstruction(npcId)
    local npc = self:getNPCById(npcId)
    if npc == nil then
        return false
    end

    if npc.constructionFinished or npc.constructionRunning then
        return false
    end

    -- TODO: Integrate with production/material system once map production bindings are available.
    return npc.requiredMaterialsReady
end

function NPCSystem:getConstructionStatus(npcId)
    local npc = self:getNPCById(npcId)
    if npc == nil then
        return nil
    end

    if npc.constructionFinished then
        return "finished"
    elseif npc.constructionRunning then
        return "running"
    elseif npc.requiredMaterialsReady then
        return "ready"
    end

    return "waitingMaterials"
end

function NPCSystem:openConstructionDialog(npcId)
    local status = self:getConstructionStatus(npcId)
    if status == nil then
        return false
    end

    local npc = self:getNPCById(npcId)
    if status == "ready" then
        npc.internalDialogId = "foremanReadyToStart"
    elseif status == "waitingMaterials" then
        npc.internalDialogId = "foremanMaterialsMissing"
    else
        npc.internalDialogId = "foremanMain"
    end

    return self:openInternalDialog(npcId)
end

function NPCSystem:startConstructionFromDialog(npcId)
    if not self:canStartConstruction(npcId) then
        return false
    end

    local npc = self:getNPCById(npcId)
    npc.constructionRunning = true
    npc.siteState = "running"
    npc.state = "constructionRunning"

    -- TODO: Trigger real construction pipeline when production/building systems are integrated.
    return true
end

function NPCSystem:getAvailableMissions(npcId)
    -- TODO: Replace with mission provider integration.
    return {}
end

function NPCSystem:startMission(npcId, missionId)
    -- TODO: Replace with mission provider integration.
    local npc = self:getNPCById(npcId)
    if npc == nil then
        return false
    end

    npc.missionId = missionId
    npc.missionState = "active"
    return true
end

function NPCSystem:completeMission(npcId, missionId)
    -- TODO: Replace with mission provider integration.
    local npc = self:getNPCById(npcId)
    if npc == nil or npc.missionId ~= missionId then
        return false
    end

    npc.missionState = "completed"
    return true
end

function NPCSystem:failMission(npcId, missionId)
    -- TODO: Replace with mission provider integration.
    local npc = self:getNPCById(npcId)
    if npc == nil or npc.missionId ~= missionId then
        return false
    end

    npc.missionState = "failed"
    return true
end

function NPCSystem:saveToXMLFile(xmlFile, key, usedModNames)
    local i = 0
    for _, npc in pairs(self.npcs) do
        local npcKey = string.format("%s.npc(%d)", key, i)
        xmlFile:setString(npcKey .. "#id", npc.id)
        xmlFile:setString(npcKey .. "#state", npc.state)
        xmlFile:setString(npcKey .. "#siteState", npc.siteState)
        xmlFile:setBool(npcKey .. "#requiredMaterialsReady", npc.requiredMaterialsReady)
        xmlFile:setBool(npcKey .. "#constructionRunning", npc.constructionRunning)
        xmlFile:setBool(npcKey .. "#constructionFinished", npc.constructionFinished)
        xmlFile:setString(npcKey .. "#missionId", npc.missionId)
        xmlFile:setString(npcKey .. "#missionState", npc.missionState)
        xmlFile:setString(npcKey .. "#missionPayload", npc.missionPayload)
        xmlFile:setInt(npcKey .. "#lastInteractionTime", npc.lastInteractionTime)
        i = i + 1
    end

    if usedModNames ~= nil and self.modName ~= nil then
        usedModNames[self.modName] = true
    end
end

function NPCSystem:loadFromXMLFile(xmlFile, key)
    local i = 0
    while true do
        local npcKey = string.format("%s.npc(%d)", key, i)
        if not xmlFile:hasProperty(npcKey .. "#id") then
            break
        end

        local npcId = xmlFile:getString(npcKey .. "#id")
        local npc = self:getNPCById(npcId)

        if npc ~= nil then
            npc.state = xmlFile:getString(npcKey .. "#state", npc.state)
            npc.siteState = xmlFile:getString(npcKey .. "#siteState", npc.siteState)
            npc.requiredMaterialsReady = xmlFile:getBool(npcKey .. "#requiredMaterialsReady", npc.requiredMaterialsReady)
            npc.constructionRunning = xmlFile:getBool(npcKey .. "#constructionRunning", npc.constructionRunning)
            npc.constructionFinished = xmlFile:getBool(npcKey .. "#constructionFinished", npc.constructionFinished)
            npc.missionId = xmlFile:getString(npcKey .. "#missionId", npc.missionId)
            npc.missionState = xmlFile:getString(npcKey .. "#missionState", npc.missionState)
            npc.missionPayload = xmlFile:getString(npcKey .. "#missionPayload", npc.missionPayload)
            npc.lastInteractionTime = xmlFile:getInt(npcKey .. "#lastInteractionTime", npc.lastInteractionTime)
        end

        i = i + 1
    end
end

function NPCSystem:update(dt)
    -- TODO: Add per-NPC timed updates when required.
end

function NPCSystem:delete()
    self.npcs = {}
    self.externalActions = {}
    self.externalGuis = {}
    self.dialogDefinitions = {}
    self.dialogController = nil
end
