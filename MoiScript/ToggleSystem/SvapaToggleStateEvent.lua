SvapaToggleStateEvent = {}
local SvapaToggleStateEvent_mt = Class(SvapaToggleStateEvent, Event)
InitEventClass(SvapaToggleStateEvent, "SvapaToggleStateEvent")

function SvapaToggleStateEvent.emptyNew()
    return Event.new(SvapaToggleStateEvent_mt)
end

function SvapaToggleStateEvent.new(toggleId, value)
    local self = SvapaToggleStateEvent.emptyNew()
    self.toggleId = tostring(toggleId or "")
    self.value = value == true
    return self
end

function SvapaToggleStateEvent:readStream(streamId, connection)
    self.toggleId = streamReadString(streamId)
    self.value = streamReadBool(streamId)
    self:run(connection)
end

function SvapaToggleStateEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.toggleId)
    streamWriteBool(streamId, self.value == true)
end

function SvapaToggleStateEvent:run(connection)
    local mission = g_currentMission
    if mission ~= nil and mission.svapaToggleManager ~= nil and self.toggleId ~= nil and self.toggleId ~= "" then
        mission.svapaToggleManager:setToggleValue(self.toggleId, self.value)
    end

    if connection ~= nil and not connection:getIsServer() and g_server ~= nil then
        g_server:broadcastEvent(SvapaToggleStateEvent.new(self.toggleId, self.value), nil, connection, nil)
    end
end

function SvapaToggleStateEvent.send(toggleId, value)
    if g_server ~= nil then
        local mission = g_currentMission
        if mission ~= nil and mission.svapaToggleManager ~= nil then
            mission.svapaToggleManager:setToggleValue(toggleId, value)
        end
        g_server:broadcastEvent(SvapaToggleStateEvent.new(toggleId, value), nil, nil, nil)
        return
    end

    if g_client ~= nil and g_client:getServerConnection() ~= nil then
        g_client:getServerConnection():sendEvent(SvapaToggleStateEvent.new(toggleId, value))
    end
end
