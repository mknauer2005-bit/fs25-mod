ScriptToggleManager = {}
local ScriptToggleManager_mt = Class(ScriptToggleManager)

local SVAPA_TOGGLE_DEBUG = true

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

local STS_MOD_NAME = g_currentModName
local STS_MOD_DIR = normalizeDir(g_currentModDirectory)

local function resolveModDir()
    local current = normalizeDir(g_currentModDirectory)
    if current ~= nil then
        STS_MOD_DIR = current
    end

    debugPrint("resolveModDir modName=", STS_MOD_NAME)
    debugPrint("resolveModDir result=", STS_MOD_DIR)

    if STS_MOD_DIR == nil then
        debugWarning("resolveModDir failed: g_currentModDirectory is nil")
    end

    return STS_MOD_DIR
end

ScriptToggleManager.SAVE_FILE_NAME = "svapaScriptToggles.xml"
ScriptToggleManager.SAVE_ROOT_KEY = "scriptToggles"
ScriptToggleManager.FEATURES_CONFIG_REL_PATH = "scripts/ToggleSystem/config/scriptToggleFeatures.xml"

ScriptToggleManager.PRESET_VANILLA = "vanilla"
ScriptToggleManager.PRESET_FULL = "full"
ScriptToggleManager.PRESET_CUSTOM = "custom"

function ScriptToggleManager.new(mission, customMt)
    local self = setmetatable({}, customMt or ScriptToggleManager_mt)

    self.mission = mission
    self.isServer = mission:getIsServer()
    self.isClient = mission:getIsClient()

    self.features = {}
    self.featureOrder = {}
    self.callbacks = {}

    self.currentPreset = ScriptToggleManager.PRESET_FULL
    self.settingsExist = false
    self.pendingOpenReason = nil

    self:loadFeaturesFromConfig()

    debugPrint("Manager created. isServer=", self.isServer, "isClient=", self.isClient)

    return self
end

function ScriptToggleManager:registerFeature(featureName, defaultEnabled, descriptionTextKey)
    if self.features[featureName] ~= nil then
        debugWarning("registerFeature ignored, already registered:", featureName)
        return
    end

    self.features[featureName] = {
        name = featureName,
        enabled = defaultEnabled == true,
        default = defaultEnabled == true,
        defaultEnabled = defaultEnabled == true,
        descriptionTextKey = descriptionTextKey or "ui_svapa_toggle_unknown_desc"
    }

    table.insert(self.featureOrder, featureName)
    self:updatePresetFromCurrentState()

    debugPrint("Feature registered:", featureName, "defaultEnabled=", defaultEnabled == true)
end

function ScriptToggleManager:loadFeaturesFromConfig()
    local baseDir = resolveModDir()
    local configPath = nil

    if baseDir ~= nil then
        configPath = baseDir .. ScriptToggleManager.FEATURES_CONFIG_REL_PATH
    end

    debugPrint("resolveModDir result=", baseDir)
    debugPrint("Loading feature config. path=", configPath)

    if configPath == nil then
        debugWarning("Feature config path is nil. No features loaded.")
        return
    end

    local xmlFile = loadXMLFile("svapaScriptToggleFeatures", configPath)
    if xmlFile == nil or xmlFile == 0 then
        debugWarning("Failed to load feature config XML:", configPath)
        return
    end

    local index = 0
    local loadedCount = 0

    while true do
        local key = string.format("svapaScriptToggleSystem.features.feature(%d)", index)
        if not hasXMLProperty(xmlFile, key) then
            break
        end

        local featureName = getXMLString(xmlFile, key .. "#name")
        local defaultEnabled = Utils.getNoNil(getXMLBool(xmlFile, key .. "#default"), false)
        local description = Utils.getNoNil(getXMLString(xmlFile, key .. "#description"), "ui_svapa_toggle_unknown_desc")

        if featureName ~= nil and featureName ~= "" then
            self:registerFeature(featureName, defaultEnabled, description)
            loadedCount = loadedCount + 1
            debugPrint("Config feature loaded. name=", featureName, "default=", defaultEnabled, "description=", description)
        else
            debugWarning("Skipping feature with empty name at index", index)
        end

        index = index + 1
    end

    delete(xmlFile)
    debugPrint("Feature config loaded. count=", loadedCount)
end

function ScriptToggleManager:getIsFeatureEnabled(featureName)
    local feature = self.features[featureName]
    return feature ~= nil and feature.enabled == true
end

function ScriptToggleManager:setFeatureEnabled(featureName, isEnabled, noEventSend)
    local feature = self.features[featureName]
    if feature == nil then
        debugWarning("setFeatureEnabled unknown feature:", featureName)
        return false
    end

    local enabled = isEnabled == true
    if feature.enabled == enabled then
        return false
    end

    feature.enabled = enabled
    self:updatePresetFromCurrentState()

    debugPrint("Feature changed:", featureName, "enabled=", enabled, "preset=", self.currentPreset)

    if self.isServer and not noEventSend then
        ScriptToggleStateEvent.sendServerUpdate(nil, self:getFeatureStates(), self.currentPreset)
    end

    self:notifyCallbacks(featureName, enabled)
    return true
end

function ScriptToggleManager:setFeatureStates(featureStates, noEventSend)
    local dirty = false

    if featureStates ~= nil then
        for featureName, enabled in pairs(featureStates) do
            local feature = self.features[featureName]
            if feature ~= nil then
                local nextEnabled = enabled == true
                if feature.enabled ~= nextEnabled then
                    feature.enabled = nextEnabled
                    self:notifyCallbacks(featureName, nextEnabled)
                    debugPrint("Feature changed via setFeatureStates:", featureName, "enabled=", nextEnabled)
                    dirty = true
                end
            else
                debugWarning("setFeatureStates skipped unknown feature:", featureName)
            end
        end
    end

    if dirty then
        self:updatePresetFromCurrentState()

        if self.isServer and not noEventSend then
            ScriptToggleStateEvent.sendServerUpdate(nil, self:getFeatureStates(), self.currentPreset)
        end
    end

    return dirty
end

function ScriptToggleManager:setFeatureStatesAndPreset(featureStates, preset, noEventSend)
    local dirty = self:setFeatureStates(featureStates, true)

    if preset ~= nil then
        if preset ~= ScriptToggleManager.PRESET_VANILLA and preset ~= ScriptToggleManager.PRESET_FULL and preset ~= ScriptToggleManager.PRESET_CUSTOM then
            debugWarning("Preset from payload is invalid, ignoring:", preset)
        elseif self.currentPreset ~= preset then
            self.currentPreset = preset
            debugPrint("Preset changed from payload:", preset)
            dirty = true
        end
    end

    local oldPreset = self.currentPreset
    self:updatePresetFromCurrentState()
    if oldPreset ~= self.currentPreset then
        debugPrint("Preset recomputed from feature state:", self.currentPreset)
        dirty = true
    end

    if preset ~= nil and preset ~= ScriptToggleManager.PRESET_CUSTOM and preset ~= self.currentPreset then
        debugWarning("Preset/state mismatch detected. Computed preset kept:", self.currentPreset)
    end

    if dirty and self.isServer and not noEventSend then
        ScriptToggleStateEvent.sendServerUpdate(nil, self:getFeatureStates(), self.currentPreset)
    end

    return dirty
end

function ScriptToggleManager:applyPreset(presetName, noEventSend)
    if presetName ~= ScriptToggleManager.PRESET_VANILLA and presetName ~= ScriptToggleManager.PRESET_FULL and presetName ~= ScriptToggleManager.PRESET_CUSTOM then
        debugWarning("applyPreset invalid preset:", presetName)
        return false
    end

    if presetName == ScriptToggleManager.PRESET_CUSTOM then
        if self.currentPreset ~= ScriptToggleManager.PRESET_CUSTOM then
            self.currentPreset = ScriptToggleManager.PRESET_CUSTOM
            debugPrint("Preset switched to custom")
            return true
        end

        return false
    end

    local targetValue = presetName == ScriptToggleManager.PRESET_FULL
    local dirty = false

    for _, featureName in ipairs(self.featureOrder) do
        local feature = self.features[featureName]
        if feature.enabled ~= targetValue then
            feature.enabled = targetValue
            self:notifyCallbacks(featureName, targetValue)
            dirty = true
        end
    end

    if dirty or self.currentPreset ~= presetName then
        self.currentPreset = presetName
        debugPrint("Preset applied:", presetName, "allEnabled=", targetValue)

        if self.isServer and not noEventSend then
            ScriptToggleStateEvent.sendServerUpdate(nil, self:getFeatureStates(), self.currentPreset)
        end

        return true
    end

    return false
end

function ScriptToggleManager:getFeatureStates()
    local states = {}

    for _, featureName in ipairs(self.featureOrder) do
        states[featureName] = self.features[featureName].enabled == true
    end

    return states
end

function ScriptToggleManager:getFeaturesForUI()
    local list = {}

    for _, featureName in ipairs(self.featureOrder) do
        local feature = self.features[featureName]
        table.insert(list, {
            name = feature.name,
            enabled = feature.enabled,
            descriptionTextKey = feature.descriptionTextKey
        })
    end

    return list
end

function ScriptToggleManager:getSettingsForUI()
    return {
        openReason = self.pendingOpenReason or "manual",
        preset = self.currentPreset,
        features = self:getFeaturesForUI(),
        canCloseWithoutConfirm = self:getNeedsFirstTimeDialog() == false
    }
end

function ScriptToggleManager:registerStateChangedCallback(callbackTarget, callbackFunc)
    if callbackTarget == nil or callbackFunc == nil then
        return
    end

    table.insert(self.callbacks, { target = callbackTarget, func = callbackFunc })
end

function ScriptToggleManager:notifyCallbacks(featureName, enabled)
    debugPrint("notifyCallbacks feature=", featureName, "enabled=", enabled, "callbacks=", #self.callbacks)
    for _, callbackData in ipairs(self.callbacks) do
        callbackData.func(callbackData.target, featureName, enabled)
    end
end

function ScriptToggleManager:getSaveFilePath()
    local missionInfo = self.mission.missionInfo
    if missionInfo == nil or missionInfo.savegameDirectory == nil then
        return nil
    end

    return missionInfo.savegameDirectory .. "/" .. ScriptToggleManager.SAVE_FILE_NAME
end

function ScriptToggleManager:loadSettings()
    debugPrint("loadSettings begin")

    local path = self:getSaveFilePath()
    if path == nil then
        self.settingsExist = false
        debugWarning("loadSettings aborted: savegame path not available")
        return false
    end

    self.settingsExist = fileExists(path)
    debugPrint("loadSettings file path:", path)
    debugPrint("loadSettings file exists:", self.settingsExist)

    if not self.settingsExist then
        debugPrint("New career detected (no settings file)")
        debugPrint("loadSettings end. success=false")
        return false
    end

    debugPrint("Existing career detected (settings file present)")

    local xmlFile = XMLFile.load("svapaScriptToggles", path, ScriptToggleManager.xmlSchema)
    if xmlFile == nil then
        debugWarning("Settings file exists but XML failed to load. Keeping existing-career behavior.")
        debugPrint("loadSettings end. success=false")
        return false
    end

    local rootKey = ScriptToggleManager.SAVE_ROOT_KEY
    local initialized = xmlFile:getValue(rootKey .. "#initialized", true)

    local loadedStates = {}
    local index = 0

    while true do
        local featureKey = string.format("%s.features.feature(%d)", rootKey, index)
        local featureName = xmlFile:getValue(featureKey .. "#name")
        if featureName == nil then
            break
        end

        loadedStates[featureName] = xmlFile:getValue(featureKey .. "#enabled", true)
        index = index + 1
    end

    local loadedPreset = xmlFile:getValue(rootKey .. "#preset", ScriptToggleManager.PRESET_CUSTOM)
    xmlFile:delete()

    self:setFeatureStates(loadedStates, true)
    self:updatePresetFromCurrentState()

    if loadedPreset == ScriptToggleManager.PRESET_VANILLA or loadedPreset == ScriptToggleManager.PRESET_FULL or loadedPreset == ScriptToggleManager.PRESET_CUSTOM then
        self.currentPreset = loadedPreset
    else
        debugWarning("Unknown preset in save, fallback to computed preset:", loadedPreset)
    end

    self.settingsExist = self.settingsExist or initialized == true
    debugPrint("loadSettings complete. initialized=", initialized, "preset=", self.currentPreset)
    debugPrint("loadSettings end. success=true")
    return true
end

function ScriptToggleManager:saveSettings()
    if not self.isServer then
        return
    end

    debugPrint("saveSettings begin")

    local path = self:getSaveFilePath()
    if path == nil then
        debugWarning("saveSettings aborted: savegame path not available")
        return
    end

    debugPrint("saveSettings path:", path)

    local xmlFile = XMLFile.create("svapaScriptToggles", path, ScriptToggleManager.SAVE_ROOT_KEY)
    if xmlFile == nil then
        debugWarning("saveSettings failed: XMLFile.create returned nil")
        return
    end

    local rootKey = ScriptToggleManager.SAVE_ROOT_KEY
    xmlFile:setValue(rootKey .. "#initialized", true)
    xmlFile:setValue(rootKey .. "#preset", self.currentPreset)

    for index, featureName in ipairs(self.featureOrder) do
        local featureKey = string.format("%s.features.feature(%d)", rootKey, index - 1)
        xmlFile:setValue(featureKey .. "#name", featureName)
        xmlFile:setValue(featureKey .. "#enabled", self:getIsFeatureEnabled(featureName))
    end

    xmlFile:save()
    xmlFile:delete()

    self.settingsExist = true
    debugPrint("saveSettings completed")
    debugPrint("saveSettings end")
end

function ScriptToggleManager:getNeedsFirstTimeDialog()
    return self.settingsExist == false
end

function ScriptToggleManager:requestOpenScreen(openReason)
    if not self.isClient then
        return
    end

    debugPrint("requestOpenScreen reason=", openReason)

    if g_gui.currentGui ~= nil then
        self.pendingOpenReason = openReason or "manual"
        debugPrint("GUI busy; queueing open reason:", self.pendingOpenReason)
        return
    end

    local screen = g_gui.screenControllers["SvapaScriptToggleGUI"]
    if screen ~= nil then
        local reason = openReason or "manual"
        screen:setOpenReason(reason)
        self.pendingOpenReason = nil
        g_gui:showGui("SvapaScriptToggleGUI")
        debugPrint("GUI opened. reason=", reason)
    else
        debugWarning("GUI controller SvapaScriptToggleGUI not found")
    end
end

function ScriptToggleManager:update(dt)
    if self.pendingOpenReason ~= nil and g_gui.currentGui == nil then
        local reason = self.pendingOpenReason
        self.pendingOpenReason = nil
        self:requestOpenScreen(reason)
    end
end

function ScriptToggleManager:onPlayerSubmitSettings(featureStates, preset)
    debugPrint("onPlayerSubmitSettings called. preset=", preset, "isServer=", self.isServer)

    if self.isServer then
        local dirty = self:setFeatureStatesAndPreset(featureStates, preset, true)
        if dirty then
            ScriptToggleStateEvent.sendServerUpdate(nil, self:getFeatureStates(), self.currentPreset)
        end

        self:saveSettings()
        return
    end

    if self.isClient and g_server ~= nil then
        ScriptToggleStateEvent.sendChangeRequest(featureStates, preset)
    end
end

function ScriptToggleManager:onClientJoined(connection)
    if self.isServer then
        debugPrint("Client joined; sending full sync")
        ScriptToggleStateEvent.sendFullSync(connection, self:getFeatureStates(), self.currentPreset, self.settingsExist)
    end
end

function ScriptToggleManager:updatePresetFromCurrentState()
    local hasTrue = false
    local hasFalse = false

    for _, featureName in ipairs(self.featureOrder) do
        if self.features[featureName].enabled then
            hasTrue = true
        else
            hasFalse = true
        end

        if hasTrue and hasFalse then
            self.currentPreset = ScriptToggleManager.PRESET_CUSTOM
            return
        end
    end

    if hasTrue then
        self.currentPreset = ScriptToggleManager.PRESET_FULL
    else
        self.currentPreset = ScriptToggleManager.PRESET_VANILLA
    end
end

function ScriptToggleManager.initXMLSchema()
    ScriptToggleManager.xmlSchema = XMLSchema.new("svapaScriptToggles")

    local root = ScriptToggleManager.SAVE_ROOT_KEY
    ScriptToggleManager.xmlSchema:register(XMLValueType.BOOL, root .. "#initialized", "Toggle system initialized")
    ScriptToggleManager.xmlSchema:register(XMLValueType.STRING, root .. "#preset", "Selected preset")
    ScriptToggleManager.xmlSchema:register(XMLValueType.STRING, root .. ".features.feature(?)#name", "Feature name")
    ScriptToggleManager.xmlSchema:register(XMLValueType.BOOL, root .. ".features.feature(?)#enabled", "Feature enabled state")
end

ScriptToggleManager.initXMLSchema()

SvapaToggleIntegration = {}

function SvapaToggleIntegration.getIsEnabled(featureName)
    local mission = g_currentMission
    if mission == nil or mission.svapaScriptToggleManager == nil then
        return true
    end

    return mission.svapaScriptToggleManager:getIsFeatureEnabled(featureName)
end

function SvapaToggleIntegration.registerFeature(featureName, defaultEnabled, descriptionTextKey)
    local mission = g_currentMission
    if mission == nil or mission.svapaScriptToggleManager == nil then
        return false
    end

    mission.svapaScriptToggleManager:registerFeature(featureName, defaultEnabled, descriptionTextKey)
    return true
end

SvapaScriptToggleBootstrap = {}

function SvapaScriptToggleBootstrap:loadMap(name)
    g_currentMission.svapaScriptToggleManager = ScriptToggleManager.new(g_currentMission)

    if g_currentMission:getIsServer() then
        g_currentMission.svapaScriptToggleManager:loadSettings()
    end

    if g_currentMission:getIsClient() then
        local baseDir = resolveModDir()
        local guiRelativePath = "scripts/ToggleSystem/gui/ScriptToggleGUI.xml"
        local finalGuiXmlPath = nil

        if baseDir ~= nil then
            finalGuiXmlPath = baseDir .. guiRelativePath
        end

        debugPrint("resolveModDir result=", baseDir)
        debugPrint("GUI load finalGuiXmlPath=", finalGuiXmlPath)

        if finalGuiXmlPath == nil then
            debugWarning("Failed loading GUI/XML: invalid baseDir (nil), cannot build XML path")
        else
            local loaded, result = pcall(function()
                g_gui:loadGui(finalGuiXmlPath, "SvapaScriptToggleGUI", SvapaScriptToggleGUI)
            end)

            if not loaded then
                debugWarning("Failed loading GUI/XML:", result)
            else
                debugPrint("GUI/XML loaded")
            end
        end
    end

    if g_currentMission:getIsClient() and g_currentMission:getIsServer() and g_currentMission.svapaScriptToggleManager:getNeedsFirstTimeDialog() then
        g_currentMission.svapaScriptToggleManager.pendingOpenReason = "firstCareerStart"
        debugPrint("First career start detected -> queue GUI open")
    else
        debugPrint("Existing career -> no auto open")
    end
end

function SvapaScriptToggleBootstrap:update(dt)
    local manager = g_currentMission.svapaScriptToggleManager
    if manager ~= nil then
        manager:update(dt)
    end
end

function SvapaScriptToggleBootstrap:deleteMap()
    g_currentMission.svapaScriptToggleManager = nil
    debugPrint("Manager deleted on map unload")
end

function SvapaScriptToggleBootstrap:onConnectionFinishedLoading(connection)
    if g_currentMission ~= nil and g_currentMission:getIsServer() and g_currentMission.svapaScriptToggleManager ~= nil then
        g_currentMission.svapaScriptToggleManager:onClientJoined(connection)
    end
end

addModEventListener(SvapaScriptToggleBootstrap)
