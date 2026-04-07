GasStationExtendedFS25 = {}
GasStationExtendedFS25.modName = g_currentModName
GasStationExtendedFS25.modDirectory = g_currentModDirectory

local LOG_PREFIX = "[GasStationExtendedFS25]"
local LOG_ENABLED = false

g_gasStationExtendedFS25OnCreateData = g_gasStationExtendedFS25OnCreateData or {}

local function gsLog(stage, message)
    if not LOG_ENABLED then
        return
    end

    print(string.format("%s[%s] %s", LOG_PREFIX, tostring(stage or "-"), tostring(message or "")))
end

local function toNumber(v, fallback)
    local n = tonumber(v)
    if n == nil then
        return fallback
    end
    return n
end

local function toBool(v, fallback)
    if v == nil then
        return fallback
    end

    local s = tostring(v):lower()
    if s == "1" or s == "true" or s == "yes" then
        return true
    end
    if s == "0" or s == "false" or s == "no" then
        return false
    end
    return fallback
end

local function findChildByNameRecursive(nodeId, wanted)
    if nodeId == nil or nodeId == 0 or wanted == nil or wanted == "" then
        return nil
    end

    if getName(nodeId) == wanted then
        return nodeId
    end

    local childCount = getNumOfChildren(nodeId)
    for i = 0, childCount - 1 do
        local child = getChildAt(nodeId, i)
        local found = findChildByNameRecursive(child, wanted)
        if found ~= nil then
            return found
        end
    end

    return nil
end

local function resolveVehicleFromNode(otherId)
    if g_currentMission == nil or g_currentMission.nodeToVehicle == nil then
        return nil
    end

    local node = otherId
    while node ~= nil and node ~= 0 do
        local vehicle = g_currentMission.nodeToVehicle[node]
        if vehicle ~= nil then
            return vehicle
        end

        if getParent == nil then
            break
        end

        node = getParent(node)
    end

    return nil
end

local function getGlobalFuelPrice()
    if g_currentMission ~= nil then
        return toNumber(g_currentMission.gasStationFuelPrice, 1.1)
    end
    return 1.1
end

function GasStationExtendedFS25_onCreate(nodeId)
    table.insert(g_gasStationExtendedFS25OnCreateData, {
        nodeId = nodeId,
        triggerNodeName = getUserAttribute(nodeId, "triggerNode"),
        saveId = getUserAttribute(nodeId, "saveId") or ("gasStation_" .. tostring(nodeId)),
        fillLitersPerSecond = toNumber(getUserAttribute(nodeId, "fillLitersPerSecond"), 10),
        priceMultiplier = toNumber(getUserAttribute(nodeId, "priceMultiplier"), 1.0),
        trailerCan = toBool(getUserAttribute(nodeId, "trailerCan"), true),
        trailerOnly = toBool(getUserAttribute(nodeId, "trailerOnly"), false),
    })

    gsLog("onCreate", "queued nodeId=" .. tostring(nodeId))
end

local function registerOnCreateAliases()
    local modName = g_currentModName or GasStationExtendedFS25.modName

    if modName ~= nil and modName ~= "" then
        _G[modName] = _G[modName] or {}
        _G[modName].GasStationExtendedFS25_onCreate = GasStationExtendedFS25_onCreate
    end

    _G.GasStationExtendedFS25_onCreate = GasStationExtendedFS25_onCreate
    _G.modOnCreate = _G.modOnCreate or {}
    _G.modOnCreate.GasStationExtendedFS25_onCreate = GasStationExtendedFS25_onCreate
end

registerOnCreateAliases()

local Station = {}
Station.__index = Station

function Station.new(data)
    local self = setmetatable({}, Station)

    self.nodeId = data.nodeId
    self.triggerNodeId = self.nodeId
    self.saveId = data.saveId
    self.fillLitersPerSecond = data.fillLitersPerSecond
    self.priceMultiplier = data.priceMultiplier
    self.trailerCan = data.trailerCan
    self.trailerOnly = data.trailerOnly

    self.vehiclesTriggerCount = {}

    if data.triggerNodeName ~= nil and data.triggerNodeName ~= "" then
        local triggerNode = findChildByNameRecursive(self.nodeId, data.triggerNodeName)
        if triggerNode ~= nil then
            self.triggerNodeId = triggerNode
        else
            gsLog("station", string.format("triggerNode '%s' not found for %s", tostring(data.triggerNodeName), tostring(self.saveId)))
        end
    end

    if self.triggerNodeId ~= nil and self.triggerNodeId ~= 0 then
        addTrigger(self.triggerNodeId, "triggerCallback", self)
        gsLog("station", string.format("trigger registered station=%s triggerNode=%s", tostring(self.saveId), tostring(self.triggerNodeId)))
    end

    return self
end

function Station:delete()
    for vehicle, count in pairs(self.vehiclesTriggerCount) do
        if count ~= nil and count > 0 and vehicle ~= nil and vehicle.removeFuelFillTrigger ~= nil then
            vehicle:removeFuelFillTrigger(self)
        end
    end

    if self.triggerNodeId ~= nil and self.triggerNodeId ~= 0 then
        removeTrigger(self.triggerNodeId)
    end
end

function Station:isFuelTrailer(vehicle)
    return vehicle ~= nil and vehicle.fuelTrailerFillActivatable ~= nil
end

function Station:vehicleAllowed(vehicle)
    if vehicle == nil then
        return false
    end

    local isTrailer = self:isFuelTrailer(vehicle)

    if isTrailer and not self.trailerCan and not self.trailerOnly then
        return false
    end

    if (not isTrailer) and self.trailerOnly then
        return false
    end

    return vehicle.addFuelFillTrigger ~= nil and vehicle.removeFuelFillTrigger ~= nil
end

function Station:triggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
    local vehicle = resolveVehicleFromNode(otherId)
    if not self:vehicleAllowed(vehicle) then
        return
    end

    local count = self.vehiclesTriggerCount[vehicle] or 0

    if onEnter then
        self.vehiclesTriggerCount[vehicle] = 1
        if count == 0 then
            vehicle:addFuelFillTrigger(self)
        end
        gsLog("trigger", string.format("onEnter station=%s vehicle=%s", tostring(self.saveId), tostring(vehicle.configFileName or vehicle)))
    elseif onLeave then
        self.vehiclesTriggerCount[vehicle] = 0
        if count == 1 then
            self.vehiclesTriggerCount[vehicle] = nil
            vehicle:removeFuelFillTrigger(self)
        end
        gsLog("trigger", string.format("onLeave station=%s vehicle=%s", tostring(self.saveId), tostring(vehicle.configFileName or vehicle)))
    end
end

function Station:getIsActivatable(vehicle)
    if vehicle == nil then
        return false
    end

    if vehicle.setFuelFillLevel ~= nil then
        return true
    end

    if vehicle.allowFillType ~= nil and FillType ~= nil and FillType.DIESEL ~= nil then
        return vehicle:allowFillType(FillType.DIESEL, false)
    end

    return false
end

function Station:fillFuel(vehicle, delta)
    if vehicle == nil then
        return 0
    end

    local maxDelta = (self.fillLitersPerSecond or 10) * 0.001 * (g_currentDt or 16)
    delta = math.min(delta, maxDelta)
    if delta <= 0 then
        return 0
    end

    if vehicle.setFuelFillLevel ~= nil and vehicle.fuelFillLevel ~= nil then
        local before = vehicle.fuelFillLevel
        vehicle:setFuelFillLevel(before + delta)
        delta = math.max((vehicle.fuelFillLevel or before) - before, 0)
    elseif vehicle.getFillLevel ~= nil and vehicle.setFillLevel ~= nil and FillType ~= nil and FillType.DIESEL ~= nil then
        local before = vehicle:getFillLevel(FillType.DIESEL)
        vehicle:setFillLevel(before + delta, FillType.DIESEL)
        local after = vehicle:getFillLevel(FillType.DIESEL)
        delta = math.max(after - before, 0)
    else
        delta = 0
    end

    if delta <= 0 then
        return 0
    end

    local price = delta * getGlobalFuelPrice() * (self.priceMultiplier or 1)
    if g_currentMission ~= nil and price > 0 then
        if g_currentMission.addMoney ~= nil and g_currentMission.getFarmId ~= nil and MoneyType ~= nil and MoneyType.PURCHASE_FUEL ~= nil then
            g_currentMission:addMoney(-price, g_currentMission:getFarmId(), MoneyType.PURCHASE_FUEL, true, true)
        elseif g_currentMission.addMoneyChange ~= nil then
            g_currentMission:addMoneyChange(-price)
        end
    end

    return delta
end

local Runtime = {}
Runtime.__index = Runtime

function Runtime.new()
    local self = setmetatable({}, Runtime)
    self.stations = {}
    self.loaded = false
    return self
end

function Runtime:loadMap(mapName)
    registerOnCreateAliases()

    self.stations = {}
    for _, data in ipairs(g_gasStationExtendedFS25OnCreateData) do
        table.insert(self.stations, Station.new(data))
    end

    self.loaded = true
    gsLog("loadMap", "stations=" .. tostring(#self.stations))
end

function Runtime:deleteMap()
    for _, station in ipairs(self.stations) do
        station:delete()
    end

    self.stations = {}
    self.loaded = false
    g_gasStationExtendedFS25OnCreateData = {}
end

if g_gasStationExtendedFS25Runtime == nil then
    g_gasStationExtendedFS25Runtime = Runtime.new()
    addModEventListener(g_gasStationExtendedFS25Runtime)
end
