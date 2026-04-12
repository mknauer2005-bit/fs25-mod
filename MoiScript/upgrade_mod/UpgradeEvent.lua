UpgradeEvent = {}
local UpgradeEvent_mt = Class(UpgradeEvent, Event)
InitEventClass(UpgradeEvent, "UpgradeEvent")

function UpgradeEvent.emptyNew()
    return Event.new(UpgradeEvent_mt)
end

function UpgradeEvent.new(configPath, sourceUniqueId)
    local self = UpgradeEvent.emptyNew()
    self.configPath = configPath
    self.sourceUniqueId = sourceUniqueId
    return self
end

function UpgradeEvent:readStream(streamId, connection)
    self.configPath = streamReadString(streamId)
    self.sourceUniqueId = streamReadString(streamId)
    self:run(connection)
end

function UpgradeEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.configPath)
    streamWriteString(streamId, self.sourceUniqueId)
end

function UpgradeEvent:run(connection)
    if connection ~= nil and not connection:getIsServer() then
        local farmId = connection.farmId or FarmManager.SINGLEPLAYER_FARM_ID
        local success, reason = UpgradeSystem.applyUpgrade(self.configPath, self.sourceUniqueId, farmId, g_currentModName)
        if not success then
            Logging.warning("[UpgradeEvent] Upgrade failed for '%s' (%s)", tostring(self.sourceUniqueId), tostring(reason))
        end
    end
end

function UpgradeEvent.sendToServer(configPath, sourceUniqueId)
    if g_server ~= nil then
        local farmId = g_currentMission ~= nil and g_currentMission:getFarmId() or FarmManager.SINGLEPLAYER_FARM_ID
        return UpgradeSystem.applyUpgrade(configPath, sourceUniqueId, farmId, g_currentModName)
    end

    if g_client ~= nil and g_client:getServerConnection() ~= nil then
        g_client:getServerConnection():sendEvent(UpgradeEvent.new(configPath, sourceUniqueId))
        return true, nil
    end

    return false, "noConnection"
end
