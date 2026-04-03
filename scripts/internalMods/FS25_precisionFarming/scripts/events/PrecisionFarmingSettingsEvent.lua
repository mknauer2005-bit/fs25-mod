-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.


---Event while settings have been updated on server or client side
-- @category Events
PrecisionFarmingSettingsEvent = {}
local PrecisionFarmingSettingsEvent_mt = Class(PrecisionFarmingSettingsEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function PrecisionFarmingSettingsEvent.emptyNew()
    local self = Event.new(PrecisionFarmingSettingsEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
function PrecisionFarmingSettingsEvent.new(setting)
    local self = PrecisionFarmingSettingsEvent.emptyNew()
    self.setting = setting
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function PrecisionFarmingSettingsEvent:readStream(streamId, connection)
    local precisionFarmingSettings = g_precisionFarming.precisionFarmingSettings

    local index = streamReadUIntN(streamId, precisionFarmingSettings.settingIndexNumBits)
    local state = streamReadBool(streamId)
    self.setting = precisionFarmingSettings.settings[index]
    self.setting.state = state

    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function PrecisionFarmingSettingsEvent:writeStream(streamId, connection)
    local precisionFarmingSettings = g_precisionFarming.precisionFarmingSettings

    streamWriteUIntN(streamId, self.setting.index, precisionFarmingSettings.settingIndexNumBits)
    streamWriteBool(streamId, self.setting.state == true) -- only supports booleans for now
end


---Run action on receiving side
-- @param Connection connection connection
function PrecisionFarmingSettingsEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, nil)
    end

    local precisionFarmingSettings = g_precisionFarming.precisionFarmingSettings
    precisionFarmingSettings:onSettingChanged(self.setting, true)
end


---Broadcast event from server to all clients, if called on client call function on server and broadcast it to all clients
-- @param table object object
-- @param boolean noEventSend no event send
function PrecisionFarmingSettingsEvent.sendEvent(setting, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(PrecisionFarmingSettingsEvent.new(setting), nil, nil, nil)
        else
            g_client:getServerConnection():sendEvent(PrecisionFarmingSettingsEvent.new(setting))
        end
    end
end
