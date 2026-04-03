-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.


---Event while settings have been updated on server or client side
-- @category Events
PrecisionFarmingSettingsInitialEvent = {}
local PrecisionFarmingSettingsInitialEvent_mt = Class(PrecisionFarmingSettingsInitialEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function PrecisionFarmingSettingsInitialEvent.emptyNew()
    local self = Event.new(PrecisionFarmingSettingsInitialEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
function PrecisionFarmingSettingsInitialEvent.new(settings)
    local self = PrecisionFarmingSettingsInitialEvent.emptyNew()
    self.settings = settings

    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function PrecisionFarmingSettingsInitialEvent:readStream(streamId, connection)
    local precisionFarmingSettings = g_precisionFarming.precisionFarmingSettings

    for _, setting in ipairs(precisionFarmingSettings.settings) do
        if setting.isServerSetting then
            setting.state = streamReadBool(streamId)
        end
    end

    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function PrecisionFarmingSettingsInitialEvent:writeStream(streamId, connection)
    local precisionFarmingSettings = g_precisionFarming.precisionFarmingSettings

    for _, setting in ipairs(precisionFarmingSettings.settings) do
        if setting.isServerSetting then
            streamWriteBool(streamId, setting.state == true)
        end
    end
end


---Run action on receiving side
-- @param Connection connection connection
function PrecisionFarmingSettingsInitialEvent:run(connection)
    local precisionFarmingSettings = g_precisionFarming.precisionFarmingSettings

    for _, setting in ipairs(precisionFarmingSettings.settings) do
        if setting.isServerSetting then
            precisionFarmingSettings:onSettingChanged(setting, true)
        end
    end
end
