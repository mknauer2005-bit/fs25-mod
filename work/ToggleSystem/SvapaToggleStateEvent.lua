SvapaToggleStateEvent = {}
local SvapaToggleStateEvent_mt = Class(SvapaToggleStateEvent, Event)
InitEventClass(SvapaToggleStateEvent, "SvapaToggleStateEvent")

function SvapaToggleStateEvent.emptyNew()
    return Event.new(SvapaToggleStateEvent_mt)
end

function SvapaToggleStateEvent.new(toggleId, value, isSyncRequest, saveOnly)
    local self = SvapaToggleStateEvent.emptyNew()
    self.toggleId = tostring(toggleId or "")
    self.value = value == true
    self.isSyncRequest = isSyncRequest == true
    self.saveOnly = saveOnly == true
    return self
end

function SvapaToggleStateEvent:readStream(streamId, connection)
    self.toggleId = streamReadString(streamId)
    self.value = streamReadBool(streamId)
    self.isSyncRequest = streamReadBool(streamId)
    self.saveOnly = streamReadBool(streamId)
    self:run(connection)
end

function SvapaToggleStateEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.toggleId)
    streamWriteBool(streamId, self.value == true)
    streamWriteBool(streamId, self.isSyncRequest == true)
    streamWriteBool(streamId, self.saveOnly == true)
end

function SvapaToggleStateEvent:run(connection)
    local mission = g_currentMission
    local manager = mission ~= nil and mission.svapaToggleManager or nil
    if manager == nil then
        return
    end

    if g_server ~= nil then
        if connection ~= nil and not connection:getIsServer() then
            if self.saveOnly == true then
                if connection.getIsServerAdmin == nil or not connection:getIsServerAdmin() then
                    return
                end

                manager:saveToggleStateFile()
                manager:sendAllStates()
                return
            end

            if self.isSyncRequest == true then
                manager:sendAllStatesToConnection(connection)
                return
            end

            if connection.getIsServerAdmin == nil or not connection:getIsServerAdmin() then
                return
            end
        end

        if self.saveOnly == true then
            manager:saveToggleStateFile()
            manager:sendAllStates()
            return
        end

        if self.toggleId ~= nil and self.toggleId ~= "" then
            manager:setToggleValue(self.toggleId, self.value)
            manager:applyToggleTargets()
            manager:saveToggleStateFile()
            manager:sendAllStates()
        end
        return
    end

    if self.toggleId ~= nil and self.toggleId ~= "" then
        manager:applyReplicatedToggleValue(self.toggleId, self.value)
    end
end

function SvapaToggleStateEvent.send(toggleId, value)
    if g_server ~= nil then
        SvapaToggleStateEvent.new(toggleId, value, false, false):run(nil)
        return
    end

    if g_client ~= nil and g_client:getServerConnection() ~= nil then
        g_client:getServerConnection():sendEvent(SvapaToggleStateEvent.new(toggleId, value, false, false))
    end
end

function SvapaToggleStateEvent.sendSyncRequest(saveOnly)
    if g_server ~= nil then
        if saveOnly == true then
            SvapaToggleStateEvent.new("", false, false, true):run(nil)
        end
        return
    end

    if g_client ~= nil and g_client:getServerConnection() ~= nil then
        g_client:getServerConnection():sendEvent(SvapaToggleStateEvent.new("", false, true, saveOnly == true))
    end
end