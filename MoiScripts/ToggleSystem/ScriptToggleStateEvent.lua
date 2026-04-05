ScriptToggleStateEvent = {}
local ScriptToggleStateEvent_mt = Class(ScriptToggleStateEvent, Event)
InitEventClass(ScriptToggleStateEvent, "ScriptToggleStateEvent")

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

ScriptToggleStateEvent.MODE_FULL_SYNC = 1
ScriptToggleStateEvent.MODE_CHANGE_REQUEST = 2
ScriptToggleStateEvent.MODE_SERVER_UPDATE = 3

function ScriptToggleStateEvent.emptyNew()
    return Event.new(ScriptToggleStateEvent_mt)
end

function ScriptToggleStateEvent.new(mode, featureStates, preset, settingsExist)
    local self = ScriptToggleStateEvent.emptyNew()

    self.mode = mode
    self.featureStates = featureStates or {}
    self.preset = preset
    self.settingsExist = settingsExist

    return self
end

function ScriptToggleStateEvent:writeStream(streamId, connection)
    streamWriteUIntN(streamId, self.mode, 2)

    local stateCount = table.size(self.featureStates)
    streamWriteUIntN(streamId, stateCount, 8)

    for featureName, enabled in pairs(self.featureStates) do
        streamWriteString(streamId, featureName)
        streamWriteBool(streamId, enabled == true)
    end

    streamWriteBool(streamId, self.preset ~= nil)
    if self.preset ~= nil then
        streamWriteString(streamId, self.preset)
    end

    streamWriteBool(streamId, self.settingsExist == true)
end

function ScriptToggleStateEvent:readStream(streamId, connection)
    self.mode = streamReadUIntN(streamId, 2)

    local stateCount = streamReadUIntN(streamId, 8)
    self.featureStates = {}

    for _ = 1, stateCount do
        local featureName = streamReadString(streamId)
        local enabled = streamReadBool(streamId)
        self.featureStates[featureName] = enabled
    end

    if streamReadBool(streamId) then
        self.preset = streamReadString(streamId)
    else
        self.preset = nil
    end

    self.settingsExist = streamReadBool(streamId)

    debugPrint("Event readStream mode=", self.mode, "stateCount=", stateCount)
    self:run(connection)
end

function ScriptToggleStateEvent:run(connection)
    local mission = g_currentMission
    local manager = mission ~= nil and mission.svapaScriptToggleManager or nil
    if manager == nil then
        debugWarning("Event run without manager")
        return
    end

    if self.mode == ScriptToggleStateEvent.MODE_CHANGE_REQUEST then
        debugPrint("Event mode CHANGE_REQUEST received. isServer=", manager.isServer)
        if connection:getIsServer() then
            return
        end

        if manager.isServer then
            -- FS22 reference pattern used here: client request -> server applies -> broadcast update
            debugPrint("FS22 reference pattern used here: request/apply/broadcast")
            local dirty = manager:setFeatureStatesAndPreset(self.featureStates, self.preset, true)
            if dirty then
                manager:saveSettings()
            elseif self.settingsExist == true then
                manager.settingsExist = true
            end

            ScriptToggleStateEvent.sendServerUpdate(nil, manager:getFeatureStates(), manager.currentPreset)
        end

        return
    end

    if self.mode == ScriptToggleStateEvent.MODE_FULL_SYNC or self.mode == ScriptToggleStateEvent.MODE_SERVER_UPDATE then
        debugPrint("Event mode sync/update received on client path. mode=", self.mode)
        if manager.isClient then
            manager:setFeatureStatesAndPreset(self.featureStates, self.preset, true)

            if self.settingsExist == true then
                manager.settingsExist = true
            end
        end
    end
end

function ScriptToggleStateEvent.sendChangeRequest(featureStates, preset)
    if g_server == nil then
        debugPrint("Sending CHANGE_REQUEST to server")
        g_client:getServerConnection():sendEvent(ScriptToggleStateEvent.new(ScriptToggleStateEvent.MODE_CHANGE_REQUEST, featureStates, preset, true))
    end
end

function ScriptToggleStateEvent.sendFullSync(connection, featureStates, preset, settingsExist)
    if connection ~= nil then
        debugPrint("Sending FULL_SYNC to connection")
        connection:sendEvent(ScriptToggleStateEvent.new(ScriptToggleStateEvent.MODE_FULL_SYNC, featureStates, preset, settingsExist))
    end
end

function ScriptToggleStateEvent.sendServerUpdate(connection, featureStates, preset)
    if g_server ~= nil then
        debugPrint("Sending SERVER_UPDATE broadcast")
        local event = ScriptToggleStateEvent.new(ScriptToggleStateEvent.MODE_SERVER_UPDATE, featureStates, preset, true)

        if connection ~= nil then
            connection:sendEvent(event)
        else
            g_server:broadcastEvent(event)
        end
    end
end
