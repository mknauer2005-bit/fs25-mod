GasStationExtendedPriceFS25 = {}
GasStationExtendedPriceFS25.modName = g_currentModName
GasStationExtendedPriceFS25.modDirectory = g_currentModDirectory

local LOG_PREFIX = "[GasStationExtendedPriceFS25]"
local LOG_ENABLED = false

g_gasStationExtendedPriceFS25OnCreateData = g_gasStationExtendedPriceFS25OnCreateData or {}

local DEFAULTS = {
    minFuelPrice = 0.95,
    maxFuelPrice = 1.55,
    startFuelPrice = 1.10,
    changePercentPerHour = 0.08,
}

local function log(stage, msg)
    if not LOG_ENABLED then
        return
    end

    print(string.format("%s[%s] %s", LOG_PREFIX, tostring(stage or "-"), tostring(msg or "")))
end

local function toNumber(v, fallback)
    local n = tonumber(v)
    if n == nil then
        return fallback
    end
    return n
end

local function clamp(v, minV, maxV)
    if v < minV then return minV end
    if v > maxV then return maxV end
    return v
end

function GasStationExtendedPriceFS25_onCreate(nodeId)
    table.insert(g_gasStationExtendedPriceFS25OnCreateData, {
        nodeId = nodeId,
        minFuelPrice = toNumber(getUserAttribute(nodeId, "minFuelPrice"), DEFAULTS.minFuelPrice),
        maxFuelPrice = toNumber(getUserAttribute(nodeId, "maxFuelPrice"), DEFAULTS.maxFuelPrice),
        startFuelPrice = toNumber(getUserAttribute(nodeId, "startFuelPrice"), DEFAULTS.startFuelPrice),
        changePercentPerHour = toNumber(getUserAttribute(nodeId, "changePercentPerHour"), DEFAULTS.changePercentPerHour),
    })

    log("onCreate", string.format("queued nodeId=%s", tostring(nodeId)))
end

local function registerOnCreateAliases()
    local modName = g_currentModName or GasStationExtendedPriceFS25.modName

    if modName ~= nil and modName ~= "" then
        _G[modName] = _G[modName] or {}
        _G[modName].GasStationExtendedPriceFS25_onCreate = GasStationExtendedPriceFS25_onCreate
    end

    _G.GasStationExtendedPriceFS25_onCreate = GasStationExtendedPriceFS25_onCreate
    _G.modOnCreate = _G.modOnCreate or {}
    _G.modOnCreate.GasStationExtendedPriceFS25_onCreate = GasStationExtendedPriceFS25_onCreate
end

registerOnCreateAliases()

local PriceRuntime = {}
PriceRuntime.__index = PriceRuntime

function PriceRuntime.new()
    local self = setmetatable({}, PriceRuntime)
    self.initialized = false
    self.minFuelPrice = DEFAULTS.minFuelPrice
    self.maxFuelPrice = DEFAULTS.maxFuelPrice
    self.fuelPrice = DEFAULTS.startFuelPrice
    self.changePercentPerHour = DEFAULTS.changePercentPerHour
    self.msAccumulator = 0
    self.stepIntervalMs = 60 * 1000 -- раз в игровую минуту
    return self
end

function PriceRuntime:applyConfig()
    local cfg = g_gasStationExtendedPriceFS25OnCreateData[1]
    if cfg ~= nil then
        self.minFuelPrice = toNumber(cfg.minFuelPrice, self.minFuelPrice)
        self.maxFuelPrice = toNumber(cfg.maxFuelPrice, self.maxFuelPrice)
        if self.minFuelPrice > self.maxFuelPrice then
            self.minFuelPrice, self.maxFuelPrice = self.maxFuelPrice, self.minFuelPrice
        end

        self.changePercentPerHour = math.max(toNumber(cfg.changePercentPerHour, self.changePercentPerHour), 0)
        self.fuelPrice = clamp(toNumber(cfg.startFuelPrice, self.fuelPrice), self.minFuelPrice, self.maxFuelPrice)
    else
        self.fuelPrice = clamp(self.fuelPrice, self.minFuelPrice, self.maxFuelPrice)
    end
end

function PriceRuntime:setFuelPrice(price)
    self.fuelPrice = clamp(toNumber(price, self.fuelPrice), self.minFuelPrice, self.maxFuelPrice)
    if g_currentMission ~= nil then
        g_currentMission.gasStationFuelPrice = self.fuelPrice
    end
    log("price", string.format("set %.4f", self.fuelPrice))
end

function PriceRuntime:stepPrice()
    local span = self.maxFuelPrice - self.minFuelPrice
    if span <= 0 then
        self:setFuelPrice(self.minFuelPrice)
        return
    end

    -- переводим лимит per-hour к шагу per-minute
    local maxStepHour = span * self.changePercentPerHour
    local maxStepMinute = maxStepHour / 60
    local delta = (math.random() * 2 - 1) * maxStepMinute

    self:setFuelPrice(self.fuelPrice + delta)
end

function PriceRuntime:loadMap(name)
    registerOnCreateAliases()
    self:applyConfig()
    self:setFuelPrice(self.fuelPrice)
    self.msAccumulator = 0
    self.initialized = true
    log("loadMap", "initialized")
end

function PriceRuntime:update(dt)
    if not self.initialized or g_currentMission == nil then
        return
    end

    self.msAccumulator = self.msAccumulator + dt
    if self.msAccumulator < self.stepIntervalMs then
        return
    end

    self.msAccumulator = 0
    self:stepPrice()
end

function PriceRuntime:deleteMap()
    self.initialized = false
    self.msAccumulator = 0
    g_gasStationExtendedPriceFS25OnCreateData = {}
end

if g_gasStationExtendedPriceFS25Runtime == nil then
    g_gasStationExtendedPriceFS25Runtime = PriceRuntime.new()
    addModEventListener(g_gasStationExtendedPriceFS25Runtime)
end
