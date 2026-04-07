local DEBUG = false
local ECONOMIC_EVENTS_ENABLED = false
local THIS_MOD_DIR = g_currentModDirectory
local THIS_MOD_NAME = g_currentModName

RandomTheftEventsDialogEvent = {}
local RandomTheftEventsDialogEvent_mt = Class(RandomTheftEventsDialogEvent, Event)
InitEventClass(RandomTheftEventsDialogEvent, "RandomTheftEventsDialogEvent")

function RandomTheftEventsDialogEvent.emptyNew()
    local self = Event.new(RandomTheftEventsDialogEvent_mt)
    return self
end

function RandomTheftEventsDialogEvent.new(message)
    local self = RandomTheftEventsDialogEvent.emptyNew()
    self.message = message or ""
    return self
end

function RandomTheftEventsDialogEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.message or "")
end

function RandomTheftEventsDialogEvent:readStream(streamId, connection)
    self.message = streamReadString(streamId)
    self:run(connection)
end

function RandomTheftEventsDialogEvent:run(connection)
    if g_server == nil and g_randomTheftEvents ~= nil then
        g_randomTheftEvents:showLocalMessage(self.message)
    end
end

function RandomTheftEventsDialogEvent.sendToClients(message)
    if g_server ~= nil then
        g_server:broadcastEvent(RandomTheftEventsDialogEvent.new(message), true)
    end
end

RandomTheftEvents = {}
local RandomTheftEvents_mt = Class(RandomTheftEvents)

function RandomTheftEvents.new(modDirectory)
    local self = setmetatable({}, RandomTheftEvents_mt)
    self.modDirectory = modDirectory or THIS_MOD_DIR
    self.modName = THIS_MOD_NAME
    self.configFile = self:resolveConfigPath()
    self.stateFileName = "randomTheftEventsState.xml"
    self.stateFilePath = nil

    self.enabled = true
    self.checkIntervalMinutes = 15
    self.useRealTime = true
    self.onlyWhenPlayerInSession = true
    self.minimumSessionMinutesBeforeEvents = 10
    self.messageEnabled = true
    self.randomSeed = 0
    self.debugLogging = false

    self.filters = {
        skipEnteredVehicles = true,
        skipActiveMotorizedVehicles = true,
        skipMovingVehicles = true,
        skipVehiclesWithAttachedImplementInUse = true,
        farmScoped = true
    }

    self.startup = {
        enabled = true,
        onExistingSave = true,
        onNewSave = false,
        oncePerLogin = true,
        minimumCooldownMinutes = 30,
        chancePercent = 100,
        allowFuel = true,
        allowSeeds = true,
        allowFertilizer = true
    }
    self.startupMissingVehicle = {
        enabled = false,
        chancePercent = 1,
        oncePerLogin = true,
        minimumCooldownMinutes = 30,
        message = "Пока вас не было, пропала одна единица техники.",
        minPeriod = 1,
        maxPeriod = 12,
        oncePerGameYear = false,
        maxTriggersPerGameYear = 0,
        cooldownPeriods = 0,
        lastTriggeredYear = -1,
        triggersThisYear = 0,
        lastTriggeredPeriod = -1000000
    }

    self.events = {
        fuel = {enabled=true, useStartupEvent=true, usePeriodicEvent=true, chancePercent=20, cooldownMinutes=120, cooldownPeriods=0, minHour=0, maxHour=24, minPeriod=1, maxPeriod=12, oncePerGameYear=false, maxTriggersPerGameYear=0, drainMode="percent", percent=50, minPercent=25, maxPercent=75, message="Пока вас не было, из техники слили топливо.", lastTriggerMinute=-1000000, lastTriggeredYear=-1, triggersThisYear=0, lastTriggeredPeriod=-1000000},
        seeds = {enabled=true, useStartupEvent=true, usePeriodicEvent=true, chancePercent=15, cooldownMinutes=120, cooldownPeriods=0, minHour=0, maxHour=24, minPeriod=1, maxPeriod=12, oncePerGameYear=false, maxTriggersPerGameYear=0, drainMode="percent", percent=50, minPercent=25, maxPercent=75, message="Пока вас не было, из техники украли семена.", lastTriggerMinute=-1000000, lastTriggeredYear=-1, triggersThisYear=0, lastTriggeredPeriod=-1000000},
        fertilizer = {enabled=true, useStartupEvent=true, usePeriodicEvent=true, chancePercent=15, cooldownMinutes=120, cooldownPeriods=0, minHour=0, maxHour=24, minPeriod=1, maxPeriod=12, oncePerGameYear=false, maxTriggersPerGameYear=0, drainMode="percent", percent=50, minPercent=25, maxPercent=75, message="Пока вас не было, из техники украли удобрения.", lastTriggerMinute=-1000000, lastTriggeredYear=-1, triggersThisYear=0, lastTriggeredPeriod=-1000000}
    }
    self.globalEvents = {
        drought = {enabled=false, chancePercent=5, useStartupEvent=true, usePeriodicEvent=true, cooldownMinutes=480, cooldownPeriods=0, minHour=0, maxHour=24, minPeriod=1, maxPeriod=12, oncePerLogin=true, oncePerGameYear=false, maxTriggersPerGameYear=0, minimumCooldownMinutes=30, exclusiveGroup="", message="Пока вас не было, засуха уничтожила посевы.", lastTriggerMinute=-1000000, lastStartupMinute=-1000000, sessionStartupHandled=false, lastTriggeredYear=-1, triggersThisYear=0, lastTriggeredPeriod=-1000000},
        flood = {enabled=false, chancePercent=5, useStartupEvent=true, usePeriodicEvent=true, cooldownMinutes=480, cooldownPeriods=0, minHour=0, maxHour=24, minPeriod=1, maxPeriod=12, oncePerLogin=true, oncePerGameYear=false, maxTriggersPerGameYear=0, minimumCooldownMinutes=30, exclusiveGroup="", message="Пока вас не было, наводнение уничтожило посевы.", lastTriggerMinute=-1000000, lastStartupMinute=-1000000, sessionStartupHandled=false, lastTriggeredYear=-1, triggersThisYear=0, lastTriggeredPeriod=-1000000}
    }
    self.economicEvents = {}
    self.activeEconomicModifiers = {}
    self._economyHooksInstalled = false

    self.elapsedSessionMinutes = 0
    self.checkTimerMinutes = 0
    self.totalMinutes = 0
    self.saveInitialized = false
    self.lastStartupMinute = -1000000
    self.lastStartupMissingVehicleMinute = -1000000
    self.sessionStartupHandled = false
    self.sessionStartupMissingVehicleHandled = false

    self.fillTypes = {fuel={}, seeds={}, fertilizer={}}
    self.globalEventLocks = {}
    self._lastSystemEnabledState = nil
    self.pendingStartupEvaluation = false
    self.pendingImmediatePeriodicCheck = false

    self.externalToggleCache = {
        system = true,
        startup = true,
        startupMissingVehicle = true,
        localBlock = true,
        globalBlock = true,
        economicBlock = true,
        localEvents = {},
        globalEvents = {},
        economicEvents = {}
    }
    return self
end

function RandomTheftEvents:log(msg)
    Logging.info("[RandomTheftEvents] %s", tostring(msg))
end

function RandomTheftEvents:dbg(msg)
    if DEBUG or self.debugLogging == true then
        Logging.info("[RandomTheftEvents][DEBUG] %s", tostring(msg))
    end
end

function RandomTheftEvents:getToggleBridge()
    local bridge = rawget(_G, "g_svapaToggleBridge") or rawget(_G, "SvapaToggleBridge")
    if bridge ~= nil and type(bridge.getIsEnabled) == "function" then
        self:dbg("toggle bridge found: " .. tostring(bridge))
        return bridge
    end
    self:dbg("toggle bridge missing")
    return nil
end

function RandomTheftEvents:isExternallyEnabled(toggleId, fallback)
    if toggleId == nil or toggleId == "" then
        self:dbg("toggle query skipped: empty toggleId fallback=" .. tostring(fallback == true))
        return fallback == true
    end

    local bridge = self:getToggleBridge()
    if bridge == nil then
        self:dbg("toggle query id=" .. tostring(toggleId) .. " using fallback because bridge missing value=" .. tostring(fallback == true))
        return fallback == true
    end

    local ok, value = pcall(function()
        return bridge:getIsEnabled(toggleId, fallback == true)
    end)

    if ok and type(value) == "boolean" then
        self:dbg("toggle query id=" .. tostring(toggleId) .. " fallback=" .. tostring(fallback == true) .. " result=" .. tostring(value))
        return value
    end

    self:dbg("toggle query id=" .. tostring(toggleId) .. " failed, using fallback=" .. tostring(fallback == true))
    return fallback == true
end

function RandomTheftEvents:applyExternalToggles()
    local cache = self.externalToggleCache or {}
    cache.localEvents = cache.localEvents or {}
    cache.globalEvents = cache.globalEvents or {}
    cache.economicEvents = cache.economicEvents or {}

    cache.system = self:isExternallyEnabled("randomTheftEvents.enabled", self.enabled == true)

    -- Эти общие блоки менеджер сейчас не хранит как отдельные toggle.
    -- Поэтому не спрашиваем bridge по несуществующим id, иначе он вернёт ложное false.
    cache.startup = self.startup.enabled == true
    cache.localBlock = true
    cache.globalBlock = true
    cache.economicBlock = true

    cache.startupMissingVehicle = self:isExternallyEnabled(
        "randomTheftEvents.startupMissingVehicle.enabled",
        self.startupMissingVehicle.enabled == true
    )

    for eventName, eventCfg in pairs(self.events or {}) do
        local fallback = eventCfg ~= nil and eventCfg.enabled == true or true
        cache.localEvents[eventName] = self:isExternallyEnabled(
            "randomTheftEvents.events." .. tostring(eventName) .. ".enabled",
            fallback
        )
    end

    for eventName, eventCfg in pairs(self.globalEvents or {}) do
        local fallback = eventCfg ~= nil and eventCfg.enabled == true or true
        cache.globalEvents[eventName] = self:isExternallyEnabled(
            "randomTheftEvents.globalEvents." .. tostring(eventName) .. ".enabled",
            fallback
        )
    end

    for _, eventCfg in ipairs(self.economicEvents or {}) do
        local eventName = eventCfg ~= nil and eventCfg.name or nil
        if eventName ~= nil then
            local fallback = eventCfg.enabled == true
            cache.economicEvents[eventName] = self:isExternallyEnabled(
                "randomTheftEvents.economicEvents." .. tostring(eventName) .. ".enabled",
                fallback
            )
        end
    end

    self.externalToggleCache = cache
    self.pendingStartupEvaluation = true
    self.pendingImmediatePeriodicCheck = true
    self:dbg("external toggle cache refreshed system=" .. tostring(cache.system)
        .. " startup=" .. tostring(cache.startup)
        .. " startupMissingVehicle=" .. tostring(cache.startupMissingVehicle)
        .. " localBlock=" .. tostring(cache.localBlock)
        .. " globalBlock=" .. tostring(cache.globalBlock)
        .. " economicBlock=" .. tostring(cache.economicBlock))
end

function RandomTheftEvents:isSystemEnabled()
    local cache = self.externalToggleCache
    if cache ~= nil and cache.system ~= nil then
        return cache.system == true
    end
    return self.enabled == true
end

function RandomTheftEvents:isStartupEnabled()
    local cache = self.externalToggleCache
    if cache ~= nil and cache.startup ~= nil then
        return cache.startup == true
    end
    return self.startup.enabled == true
end

function RandomTheftEvents:isStartupMissingVehicleEnabled()
    local cache = self.externalToggleCache
    if cache ~= nil and cache.startupMissingVehicle ~= nil then
        return cache.startupMissingVehicle == true
    end
    return self.startupMissingVehicle.enabled == true
end

function RandomTheftEvents:areLocalEventsEnabled()
    local cache = self.externalToggleCache
    if cache ~= nil and cache.localBlock ~= nil then
        return cache.localBlock == true
    end
    return true
end

function RandomTheftEvents:isLocalEventEnabled(eventName, eventCfg)
    local cache = self.externalToggleCache
    if cache ~= nil and cache.localEvents ~= nil and cache.localEvents[eventName] ~= nil then
        return cache.localEvents[eventName] == true
    end
    return eventCfg ~= nil and eventCfg.enabled == true or true
end

function RandomTheftEvents:areGlobalEventsEnabled()
    local cache = self.externalToggleCache
    if cache ~= nil and cache.globalBlock ~= nil then
        return cache.globalBlock == true
    end
    return true
end

function RandomTheftEvents:isGlobalEventEnabled(eventName, eventCfg)
    local cache = self.externalToggleCache
    if cache ~= nil and cache.globalEvents ~= nil and cache.globalEvents[eventName] ~= nil then
        return cache.globalEvents[eventName] == true
    end
    return eventCfg ~= nil and eventCfg.enabled == true or true
end

function RandomTheftEvents:areEconomicEventsEnabled()
    local cache = self.externalToggleCache
    if cache ~= nil and cache.economicBlock ~= nil then
        return cache.economicBlock == true
    end
    return true
end

function RandomTheftEvents:isEconomicEventEnabled(eventCfg)
    local eventName = eventCfg ~= nil and eventCfg.name or nil
    local cache = self.externalToggleCache
    if eventName ~= nil and cache ~= nil and cache.economicEvents ~= nil and cache.economicEvents[eventName] ~= nil then
        return cache.economicEvents[eventName] == true
    end
    return eventCfg ~= nil and eventCfg.enabled == true or true
end

function RandomTheftEvents:resolveConfigPath()
    local relPath = "map/config/RandomTheftEvents.xml"
    local resolved = Utils.getFilename(relPath, self.modDirectory or "")
    if resolved ~= nil and resolved ~= "" and fileExists(resolved) then
        return resolved
    end

    local base = self.modDirectory or THIS_MOD_DIR or ""
    if base ~= "" and string.sub(base, -1) ~= "/" and string.sub(base, -1) ~= "\\" then
        base = base .. "/"
    end

    local fallback = base .. relPath
    return fallback
end

function RandomTheftEvents:getStateFilePath()
    if self.stateFilePath ~= nil and self.stateFilePath ~= "" then
        return self.stateFilePath
    end

    local missionInfo = g_currentMission ~= nil and g_currentMission.missionInfo or nil
    local savegameDirectory = missionInfo ~= nil and missionInfo.savegameDirectory or nil
    if savegameDirectory == nil or savegameDirectory == "" then
        return nil
    end

    self.stateFilePath = savegameDirectory .. "/" .. tostring(self.stateFileName or "randomTheftEventsState.xml")
    return self.stateFilePath
end

function RandomTheftEvents:loadPersistentState()
    local statePath = self:getStateFilePath()
    if statePath == nil or statePath == "" or not fileExists(statePath) then
        return false
    end

    local xmlFile = loadXMLFile("RandomTheftEventsState", statePath)
    if xmlFile == nil then
        self:log("failed to load state file: " .. tostring(statePath))
        return false
    end

    self:loadFromXMLFile(xmlFile, "randomTheftEventsState")
    delete(xmlFile)
    self:dbg("persistent state loaded from " .. tostring(statePath))
    return true
end

function RandomTheftEvents:savePersistentState()
    local statePath = self:getStateFilePath()
    if statePath == nil or statePath == "" then
        return false
    end

    local xmlFile = createXMLFile("RandomTheftEventsState", statePath, "randomTheftEventsState")
    if xmlFile == 0 or xmlFile == nil then
        self:log("failed to create state file: " .. tostring(statePath))
        return false
    end

    self:saveToXMLFile(xmlFile, "randomTheftEventsState")
    saveXMLFile(xmlFile)
    delete(xmlFile)
    self:dbg("persistent state saved to " .. tostring(statePath))
    return true
end

function RandomTheftEvents:getXMLBool(xml, key, default)
    local v = getXMLBool(xml, key)
    if v == nil then return default end
    return v
end

function RandomTheftEvents:getXMLFloat(xml, key, default)
    local v = getXMLFloat(xml, key)
    if v == nil then return default end
    return v
end

function RandomTheftEvents:getXMLInt(xml, key, default)
    local v = getXMLInt(xml, key)
    if v == nil then return default end
    return v
end

function RandomTheftEvents:getXMLString(xml, key, default)
    local v = getXMLString(xml, key)
    if v == nil then return default end
    return v
end

function RandomTheftEvents:readEventConfig(xml, baseKey, eventCfg)
    eventCfg.enabled = self:getXMLBool(xml, baseKey .. "#enabled", eventCfg.enabled)
    eventCfg.useStartupEvent = self:getXMLBool(xml, baseKey .. "#useStartupEvent", eventCfg.useStartupEvent)
    eventCfg.usePeriodicEvent = self:getXMLBool(xml, baseKey .. "#usePeriodicEvent", eventCfg.usePeriodicEvent)
    eventCfg.chancePercent = self:getXMLFloat(xml, baseKey .. "#chancePercent", eventCfg.chancePercent)
    eventCfg.cooldownMinutes = self:getXMLFloat(xml, baseKey .. "#cooldownMinutes", eventCfg.cooldownMinutes)
    eventCfg.cooldownPeriods = self:getXMLInt(xml, baseKey .. "#cooldownPeriods", eventCfg.cooldownPeriods)
    eventCfg.minHour = self:getXMLFloat(xml, baseKey .. "#minHour", eventCfg.minHour)
    eventCfg.maxHour = self:getXMLFloat(xml, baseKey .. "#maxHour", eventCfg.maxHour)
    eventCfg.minPeriod = self:getXMLInt(xml, baseKey .. "#minPeriod", eventCfg.minPeriod)
    eventCfg.maxPeriod = self:getXMLInt(xml, baseKey .. "#maxPeriod", eventCfg.maxPeriod)
    eventCfg.oncePerGameYear = self:getXMLBool(xml, baseKey .. "#oncePerGameYear", eventCfg.oncePerGameYear)
    eventCfg.maxTriggersPerGameYear = self:getXMLInt(xml, baseKey .. "#maxTriggersPerGameYear", eventCfg.maxTriggersPerGameYear)
    eventCfg.drainMode = self:getXMLString(xml, baseKey .. "#drainMode", eventCfg.drainMode)
    eventCfg.percent = self:getXMLFloat(xml, baseKey .. "#percent", eventCfg.percent)
    eventCfg.minPercent = self:getXMLFloat(xml, baseKey .. "#minPercent", eventCfg.minPercent)
    eventCfg.maxPercent = self:getXMLFloat(xml, baseKey .. "#maxPercent", eventCfg.maxPercent)
    eventCfg.message = self:getXMLString(xml, baseKey .. "#message", eventCfg.message)
end

function RandomTheftEvents:loadStartupConfig(xml, root)
    self.startup.enabled = self:getXMLBool(xml, root .. ".startup#enabled", self.startup.enabled)
    self.startup.onExistingSave = self:getXMLBool(xml, root .. ".startup#onExistingSave", self.startup.onExistingSave)
    self.startup.onNewSave = self:getXMLBool(xml, root .. ".startup#onNewSave", self.startup.onNewSave)
    self.startup.oncePerLogin = self:getXMLBool(xml, root .. ".startup#oncePerLogin", self.startup.oncePerLogin)
    self.startup.minimumCooldownMinutes = self:getXMLFloat(xml, root .. ".startup#minimumCooldownMinutes", self.startup.minimumCooldownMinutes)
    self.startup.chancePercent = self:getXMLFloat(xml, root .. ".startup#chancePercent", self.startup.chancePercent)
    self.startup.allowFuel = self:getXMLBool(xml, root .. ".startup#allowFuel", self.startup.allowFuel)
    self.startup.allowSeeds = self:getXMLBool(xml, root .. ".startup#allowSeeds", self.startup.allowSeeds)
    self.startup.allowFertilizer = self:getXMLBool(xml, root .. ".startup#allowFertilizer", self.startup.allowFertilizer)

    self.startupMissingVehicle.enabled = self:getXMLBool(xml, root .. ".startupMissingVehicle#enabled", self.startupMissingVehicle.enabled)
    self.startupMissingVehicle.chancePercent = self:getXMLFloat(xml, root .. ".startupMissingVehicle#chancePercent", self.startupMissingVehicle.chancePercent)
    self.startupMissingVehicle.oncePerLogin = self:getXMLBool(xml, root .. ".startupMissingVehicle#oncePerLogin", self.startupMissingVehicle.oncePerLogin)
    self.startupMissingVehicle.minimumCooldownMinutes = self:getXMLFloat(xml, root .. ".startupMissingVehicle#minimumCooldownMinutes", self.startupMissingVehicle.minimumCooldownMinutes)
    self.startupMissingVehicle.message = self:getXMLString(xml, root .. ".startupMissingVehicle#message", self.startupMissingVehicle.message)
    self.startupMissingVehicle.minPeriod = self:getXMLInt(xml, root .. ".startupMissingVehicle#minPeriod", self.startupMissingVehicle.minPeriod)
    self.startupMissingVehicle.maxPeriod = self:getXMLInt(xml, root .. ".startupMissingVehicle#maxPeriod", self.startupMissingVehicle.maxPeriod)
    self.startupMissingVehicle.oncePerGameYear = self:getXMLBool(xml, root .. ".startupMissingVehicle#oncePerGameYear", self.startupMissingVehicle.oncePerGameYear)
    self.startupMissingVehicle.maxTriggersPerGameYear = self:getXMLInt(xml, root .. ".startupMissingVehicle#maxTriggersPerGameYear", self.startupMissingVehicle.maxTriggersPerGameYear)
    self.startupMissingVehicle.cooldownPeriods = self:getXMLInt(xml, root .. ".startupMissingVehicle#cooldownPeriods", self.startupMissingVehicle.cooldownPeriods)
end

function RandomTheftEvents:readGlobalEventConfig(xml, baseKey, cfg)
    cfg.enabled = self:getXMLBool(xml, baseKey .. "#enabled", cfg.enabled)
    cfg.chancePercent = self:getXMLFloat(xml, baseKey .. "#chancePercent", cfg.chancePercent)
    cfg.useStartupEvent = self:getXMLBool(xml, baseKey .. "#useStartupEvent", cfg.useStartupEvent)
    cfg.usePeriodicEvent = self:getXMLBool(xml, baseKey .. "#usePeriodicEvent", cfg.usePeriodicEvent)
    cfg.cooldownMinutes = self:getXMLFloat(xml, baseKey .. "#cooldownMinutes", cfg.cooldownMinutes)
    cfg.cooldownPeriods = self:getXMLInt(xml, baseKey .. "#cooldownPeriods", cfg.cooldownPeriods)
    cfg.minHour = self:getXMLFloat(xml, baseKey .. "#minHour", cfg.minHour)
    cfg.maxHour = self:getXMLFloat(xml, baseKey .. "#maxHour", cfg.maxHour)
    cfg.minPeriod = self:getXMLInt(xml, baseKey .. "#minPeriod", cfg.minPeriod)
    cfg.maxPeriod = self:getXMLInt(xml, baseKey .. "#maxPeriod", cfg.maxPeriod)
    cfg.oncePerLogin = self:getXMLBool(xml, baseKey .. "#oncePerLogin", cfg.oncePerLogin)
    cfg.oncePerGameYear = self:getXMLBool(xml, baseKey .. "#oncePerGameYear", cfg.oncePerGameYear)
    cfg.maxTriggersPerGameYear = self:getXMLInt(xml, baseKey .. "#maxTriggersPerGameYear", cfg.maxTriggersPerGameYear)
    cfg.minimumCooldownMinutes = self:getXMLFloat(xml, baseKey .. "#minimumCooldownMinutes", cfg.minimumCooldownMinutes)
    cfg.exclusiveGroup = self:getXMLString(xml, baseKey .. "#exclusiveGroup", cfg.exclusiveGroup or "")
    cfg.message = self:getXMLString(xml, baseKey .. "#message", cfg.message)
end

function RandomTheftEvents:loadEconomicEventsFromXML(xml, root)
    self.economicEvents = {}
    local i = 0
    while hasXMLProperty(xml, string.format("%s.economicEvents.event(%d)", root, i)) do
        local base = string.format("%s.economicEvents.event(%d)", root, i)
        local eventCfg = {
            name = self:getXMLString(xml, base .. "#name", "economicEvent" .. tostring(i)),
            enabled = self:getXMLBool(xml, base .. "#enabled", true),
            targetFillType = self:getXMLString(xml, base .. "#targetFillType", "DIESEL"),
            useStartupEvent = self:getXMLBool(xml, base .. "#useStartupEvent", false),
            usePeriodicEvent = self:getXMLBool(xml, base .. "#usePeriodicEvent", true),
            chancePercent = self:getXMLFloat(xml, base .. "#chancePercent", 10),
            cooldownMinutes = self:getXMLFloat(xml, base .. "#cooldownMinutes", 0),
            cooldownPeriods = self:getXMLInt(xml, base .. "#cooldownPeriods", 0),
            minHour = self:getXMLFloat(xml, base .. "#minHour", 0),
            maxHour = self:getXMLFloat(xml, base .. "#maxHour", 24),
            minPeriod = self:getXMLInt(xml, base .. "#minPeriod", 1),
            maxPeriod = self:getXMLInt(xml, base .. "#maxPeriod", self:getPeriodsPerYear()),
            oncePerLogin = self:getXMLBool(xml, base .. "#oncePerLogin", true),
            oncePerGameYear = self:getXMLBool(xml, base .. "#oncePerGameYear", false),
            maxTriggersPerGameYear = self:getXMLInt(xml, base .. "#maxTriggersPerGameYear", 0),
            durationMinutes = self:getXMLFloat(xml, base .. "#durationMinutes", 0),
            durationPeriods = self:getXMLInt(xml, base .. "#durationPeriods", 0),
            triggerEveryNPeriods = self:getXMLInt(xml, base .. "#triggerEveryNPeriods", 0),
            triggerOnPeriodStart = self:getXMLBool(xml, base .. "#triggerOnPeriodStart", false),
            triggerOnYearStart = self:getXMLBool(xml, base .. "#triggerOnYearStart", false),
            mode = self:getXMLString(xml, base .. "#mode", "multiply"),
            factor = self:getXMLFloat(xml, base .. "#factor", 1),
            percent = self:getXMLFloat(xml, base .. "#percent", 0),
            minFactor = self:getXMLFloat(xml, base .. "#minFactor", 1),
            maxFactor = self:getXMLFloat(xml, base .. "#maxFactor", 1),
            absolutePrice = self:getXMLFloat(xml, base .. "#absolutePrice", 0),
            message = self:getXMLString(xml, base .. "#message", "Экономическое событие повлияло на цену ресурса."),
            dialogType = self:getXMLString(xml, base .. "#dialogType", "warning"),
            lastTriggerMinute = -1000000,
            lastTriggeredYear = -1,
            triggersThisYear = 0,
            lastTriggeredPeriod = -1000000,
            sessionStartupHandled = false
        }
        table.insert(self.economicEvents, eventCfg)
        i = i + 1
    end
    self:dbg("economic events loaded count=" .. tostring(#self.economicEvents))
end

function RandomTheftEvents:loadConfig()
    self:dbg("module create modName=" .. tostring(self.modName))
    self:dbg("mod directory=" .. tostring(self.modDirectory))
    self:dbg("final config path=" .. tostring(self.configFile))

    if not fileExists(self.configFile) then
        self:log("config missing: " .. tostring(self.configFile))
        self:dbg("config exists=false")
        return
    end
    self:dbg("config exists=true")

    local xml = loadXMLFile("RandomTheftEventsConfig", self.configFile)
    if xml == nil then
        self:log("failed to load config")
        self:dbg("config load result=nil")
        return
    end
    self:dbg("config load result=success")

    local root = "randomTheftEvents"
    self.enabled = self:getXMLBool(xml, root .. "#enabled", self.enabled)
    self.checkIntervalMinutes = self:getXMLFloat(xml, root .. "#checkIntervalMinutes", self.checkIntervalMinutes)
    self.useRealTime = self:getXMLBool(xml, root .. "#useRealTime", self.useRealTime)
    self.onlyWhenPlayerInSession = self:getXMLBool(xml, root .. "#onlyWhenPlayerInSession", self.onlyWhenPlayerInSession)
    self.minimumSessionMinutesBeforeEvents = self:getXMLFloat(xml, root .. "#minimumSessionMinutesBeforeEvents", self.minimumSessionMinutesBeforeEvents)
    self.messageEnabled = self:getXMLBool(xml, root .. "#messageEnabled", self.messageEnabled)
    self.randomSeed = self:getXMLInt(xml, root .. "#randomSeed", self.randomSeed)
    self.debugLogging = self:getXMLBool(xml, root .. "#debugLogging", self.debugLogging)
    self:loadStartupConfig(xml, root)

    self.filters.skipEnteredVehicles = self:getXMLBool(xml, root .. ".filters#skipEnteredVehicles", self.filters.skipEnteredVehicles)
    self.filters.skipActiveMotorizedVehicles = self:getXMLBool(xml, root .. ".filters#skipActiveMotorizedVehicles", self.filters.skipActiveMotorizedVehicles)
    self.filters.skipMovingVehicles = self:getXMLBool(xml, root .. ".filters#skipMovingVehicles", self.filters.skipMovingVehicles)
    self.filters.skipVehiclesWithAttachedImplementInUse = self:getXMLBool(xml, root .. ".filters#skipVehiclesWithAttachedImplementInUse", self.filters.skipVehiclesWithAttachedImplementInUse)
    self.filters.farmScoped = self:getXMLBool(xml, root .. ".filters#farmScoped", self.filters.farmScoped)

    self:readEventConfig(xml, root .. ".events.fuel", self.events.fuel)
    self:readEventConfig(xml, root .. ".events.seeds", self.events.seeds)
    self:readEventConfig(xml, root .. ".events.fertilizer", self.events.fertilizer)
    self:readGlobalEventConfig(xml, root .. ".globalEvents.drought", self.globalEvents.drought)
    self:readGlobalEventConfig(xml, root .. ".globalEvents.flood", self.globalEvents.flood)
    self:loadEconomicEventsFromXML(xml, root)

    delete(xml)
end

function RandomTheftEvents:loadMap()
    if g_currentMission == nil or not g_currentMission:getIsServer() then
        return
    end
    self:dbg("loadMap begin")

    self:loadConfig()
    if ECONOMIC_EVENTS_ENABLED then
        self:installEconomyHooks()
    else
        self:dbg("economic system hotfix: hooks disabled")
    end
    self:resolveFillTypes()
    self:loadPersistentState()
    self.externalToggleCache = self.externalToggleCache or {}
    self:applyExternalToggles()
    self.pendingStartupEvaluation = true
    self.pendingImmediatePeriodicCheck = true

    self:dbg("post-load toggles system=" .. tostring(self:isSystemEnabled())
        .. " startup=" .. tostring(self:isStartupEnabled())
        .. " startupMissingVehicle=" .. tostring(self:isStartupMissingVehicleEnabled())
        .. " localBlock=" .. tostring(self:areLocalEventsEnabled())
        .. " globalBlock=" .. tostring(self:areGlobalEventsEnabled())
        .. " economicBlock=" .. tostring(self:areEconomicEventsEnabled()))

    local seed = self.randomSeed
    if seed == nil or seed == 0 then
        seed = 12345
        if g_currentMission ~= nil and g_currentMission.missionInfo ~= nil and g_currentMission.missionInfo.savegameIndex ~= nil then
            seed = seed + g_currentMission.missionInfo.savegameIndex * 997
        end
        seed = seed + math.floor(self.totalMinutes * 10)
        if seed <= 0 then
            seed = 12345
        end
    end
    math.randomseed(seed)
    self:dbg("rng seed=" .. tostring(seed))

    self:log("initialized")
end

function RandomTheftEvents:loadFromXMLFile(xmlFile, key)
    if xmlFile == nil then
        return
    end

    self.totalMinutes = getXMLFloat(xmlFile, key .. ".randomTheftEvents#totalMinutes") or self.totalMinutes
    self.elapsedSessionMinutes = getXMLFloat(xmlFile, key .. ".randomTheftEvents#elapsedSessionMinutes") or self.elapsedSessionMinutes
    self.checkTimerMinutes = getXMLFloat(xmlFile, key .. ".randomTheftEvents#checkTimerMinutes") or self.checkTimerMinutes
    self.events.fuel.lastTriggerMinute = getXMLFloat(xmlFile, key .. ".randomTheftEvents.events#fuelLast") or self.events.fuel.lastTriggerMinute
    self.events.seeds.lastTriggerMinute = getXMLFloat(xmlFile, key .. ".randomTheftEvents.events#seedsLast") or self.events.seeds.lastTriggerMinute
    self.events.fertilizer.lastTriggerMinute = getXMLFloat(xmlFile, key .. ".randomTheftEvents.events#fertilizerLast") or self.events.fertilizer.lastTriggerMinute
    self.saveInitialized = getXMLBool(xmlFile, key .. ".randomTheftEvents.startup#saveInitialized") or self.saveInitialized
    self.lastStartupMinute = getXMLFloat(xmlFile, key .. ".randomTheftEvents.startup#lastStartupMinute") or self.lastStartupMinute
    self.lastStartupMissingVehicleMinute = getXMLFloat(xmlFile, key .. ".randomTheftEvents.startup#lastStartupMissingVehicleMinute") or self.lastStartupMissingVehicleMinute
    self.globalEvents.drought.lastTriggerMinute = getXMLFloat(xmlFile, key .. ".randomTheftEvents.globalEvents#droughtLast") or self.globalEvents.drought.lastTriggerMinute
    self.globalEvents.flood.lastTriggerMinute = getXMLFloat(xmlFile, key .. ".randomTheftEvents.globalEvents#floodLast") or self.globalEvents.flood.lastTriggerMinute
    self.globalEvents.drought.lastStartupMinute = getXMLFloat(xmlFile, key .. ".randomTheftEvents.globalEvents#droughtStartupLast") or self.globalEvents.drought.lastStartupMinute
    self.globalEvents.flood.lastStartupMinute = getXMLFloat(xmlFile, key .. ".randomTheftEvents.globalEvents#floodStartupLast") or self.globalEvents.flood.lastStartupMinute
    self.startupMissingVehicle.lastTriggeredYear = getXMLInt(xmlFile, key .. ".randomTheftEvents.startupMissingVehicle#lastTriggeredYear") or self.startupMissingVehicle.lastTriggeredYear
    self.startupMissingVehicle.triggersThisYear = getXMLInt(xmlFile, key .. ".randomTheftEvents.startupMissingVehicle#triggersThisYear") or self.startupMissingVehicle.triggersThisYear
    self.startupMissingVehicle.lastTriggeredPeriod = getXMLInt(xmlFile, key .. ".randomTheftEvents.startupMissingVehicle#lastTriggeredPeriod") or self.startupMissingVehicle.lastTriggeredPeriod

    local function loadEventState(prefix, cfg)
        cfg.lastTriggeredYear = getXMLInt(xmlFile, key .. prefix .. "#lastTriggeredYear") or cfg.lastTriggeredYear
        cfg.triggersThisYear = getXMLInt(xmlFile, key .. prefix .. "#triggersThisYear") or cfg.triggersThisYear
        cfg.lastTriggeredPeriod = getXMLInt(xmlFile, key .. prefix .. "#lastTriggeredPeriod") or cfg.lastTriggeredPeriod
    end

    loadEventState(".randomTheftEvents.events.fuelYear", self.events.fuel)
    loadEventState(".randomTheftEvents.events.seedsYear", self.events.seeds)
    loadEventState(".randomTheftEvents.events.fertilizerYear", self.events.fertilizer)
    loadEventState(".randomTheftEvents.globalEvents.droughtYear", self.globalEvents.drought)
    loadEventState(".randomTheftEvents.globalEvents.floodYear", self.globalEvents.flood)

    self.globalEventLocks = {}
    local globalLockIndex = 0
    while hasXMLProperty(xmlFile, string.format("%s.randomTheftEvents.globalLocks.lock(%d)", key, globalLockIndex)) do
        local base = string.format("%s.randomTheftEvents.globalLocks.lock(%d)", key, globalLockIndex)
        local group = getXMLString(xmlFile, base .. "#group")
        if group ~= nil and group ~= "" then
            self.globalEventLocks[group] = {
                eventName = getXMLString(xmlFile, base .. "#eventName") or "",
                lastTriggeredPeriod = getXMLInt(xmlFile, base .. "#lastTriggeredPeriod") or -1000000,
                cooldownPeriods = getXMLInt(xmlFile, base .. "#cooldownPeriods") or 0
            }
        end
        globalLockIndex = globalLockIndex + 1
    end

    for i, eventCfg in ipairs(self.economicEvents) do
        local base = string.format("%s.randomTheftEvents.economic.event(%d)", key, i - 1)
        eventCfg.lastTriggerMinute = getXMLFloat(xmlFile, base .. "#lastTriggerMinute") or eventCfg.lastTriggerMinute
        eventCfg.lastTriggeredYear = getXMLInt(xmlFile, base .. "#lastTriggeredYear") or eventCfg.lastTriggeredYear
        eventCfg.triggersThisYear = getXMLInt(xmlFile, base .. "#triggersThisYear") or eventCfg.triggersThisYear
        eventCfg.lastTriggeredPeriod = getXMLInt(xmlFile, base .. "#lastTriggeredPeriod") or eventCfg.lastTriggeredPeriod
    end

    self.activeEconomicModifiers = {}
    local i = 0
    while hasXMLProperty(xmlFile, string.format("%s.randomTheftEvents.economic.active(%d)", key, i)) do
        local base = string.format("%s.randomTheftEvents.economic.active(%d)", key, i)
        local fillTypeIndex = getXMLInt(xmlFile, base .. "#fillTypeIndex")
        if fillTypeIndex ~= nil then
            self.activeEconomicModifiers[fillTypeIndex] = {
                eventName = getXMLString(xmlFile, base .. "#eventName"),
                fillTypeName = getXMLString(xmlFile, base .. "#fillTypeName"),
                factor = getXMLFloat(xmlFile, base .. "#factor") or 1,
                endMinute = getXMLFloat(xmlFile, base .. "#endMinute"),
                endPeriod = getXMLInt(xmlFile, base .. "#endPeriod")
            }
        end
        i = i + 1
    end
end

function RandomTheftEvents:saveToXMLFile(xmlFile, key, usedModNames)
    if xmlFile == nil then
        return
    end

    setXMLFloat(xmlFile, key .. ".randomTheftEvents#totalMinutes", self.totalMinutes)
    setXMLFloat(xmlFile, key .. ".randomTheftEvents#elapsedSessionMinutes", self.elapsedSessionMinutes)
    setXMLFloat(xmlFile, key .. ".randomTheftEvents#checkTimerMinutes", self.checkTimerMinutes)
    setXMLFloat(xmlFile, key .. ".randomTheftEvents.events#fuelLast", self.events.fuel.lastTriggerMinute)
    setXMLFloat(xmlFile, key .. ".randomTheftEvents.events#seedsLast", self.events.seeds.lastTriggerMinute)
    setXMLFloat(xmlFile, key .. ".randomTheftEvents.events#fertilizerLast", self.events.fertilizer.lastTriggerMinute)
    setXMLBool(xmlFile, key .. ".randomTheftEvents.startup#saveInitialized", true)
    setXMLFloat(xmlFile, key .. ".randomTheftEvents.startup#lastStartupMinute", self.lastStartupMinute)
    setXMLFloat(xmlFile, key .. ".randomTheftEvents.startup#lastStartupMissingVehicleMinute", self.lastStartupMissingVehicleMinute)
    setXMLFloat(xmlFile, key .. ".randomTheftEvents.globalEvents#droughtLast", self.globalEvents.drought.lastTriggerMinute)
    setXMLFloat(xmlFile, key .. ".randomTheftEvents.globalEvents#floodLast", self.globalEvents.flood.lastTriggerMinute)
    setXMLFloat(xmlFile, key .. ".randomTheftEvents.globalEvents#droughtStartupLast", self.globalEvents.drought.lastStartupMinute)
    setXMLFloat(xmlFile, key .. ".randomTheftEvents.globalEvents#floodStartupLast", self.globalEvents.flood.lastStartupMinute)
    setXMLInt(xmlFile, key .. ".randomTheftEvents.startupMissingVehicle#lastTriggeredYear", self.startupMissingVehicle.lastTriggeredYear or -1)
    setXMLInt(xmlFile, key .. ".randomTheftEvents.startupMissingVehicle#triggersThisYear", self.startupMissingVehicle.triggersThisYear or 0)
    setXMLInt(xmlFile, key .. ".randomTheftEvents.startupMissingVehicle#lastTriggeredPeriod", self.startupMissingVehicle.lastTriggeredPeriod or -1000000)

    local function saveEventState(prefix, cfg)
        setXMLInt(xmlFile, key .. prefix .. "#lastTriggeredYear", cfg.lastTriggeredYear or -1)
        setXMLInt(xmlFile, key .. prefix .. "#triggersThisYear", cfg.triggersThisYear or 0)
        setXMLInt(xmlFile, key .. prefix .. "#lastTriggeredPeriod", cfg.lastTriggeredPeriod or -1000000)
    end

    saveEventState(".randomTheftEvents.events.fuelYear", self.events.fuel)
    saveEventState(".randomTheftEvents.events.seedsYear", self.events.seeds)
    saveEventState(".randomTheftEvents.events.fertilizerYear", self.events.fertilizer)
    saveEventState(".randomTheftEvents.globalEvents.droughtYear", self.globalEvents.drought)
    saveEventState(".randomTheftEvents.globalEvents.floodYear", self.globalEvents.flood)

    local globalLockIndex = 0
    for group, data in pairs(self.globalEventLocks or {}) do
        local base = string.format("%s.randomTheftEvents.globalLocks.lock(%d)", key, globalLockIndex)
        setXMLString(xmlFile, base .. "#group", tostring(group))
        setXMLString(xmlFile, base .. "#eventName", tostring(data.eventName or ""))
        setXMLInt(xmlFile, base .. "#lastTriggeredPeriod", data.lastTriggeredPeriod or -1000000)
        setXMLInt(xmlFile, base .. "#cooldownPeriods", data.cooldownPeriods or 0)
        globalLockIndex = globalLockIndex + 1
    end

    for i, eventCfg in ipairs(self.economicEvents) do
        local base = string.format("%s.randomTheftEvents.economic.event(%d)", key, i - 1)
        setXMLFloat(xmlFile, base .. "#lastTriggerMinute", eventCfg.lastTriggerMinute or -1000000)
        setXMLInt(xmlFile, base .. "#lastTriggeredYear", eventCfg.lastTriggeredYear or -1)
        setXMLInt(xmlFile, base .. "#triggersThisYear", eventCfg.triggersThisYear or 0)
        setXMLInt(xmlFile, base .. "#lastTriggeredPeriod", eventCfg.lastTriggeredPeriod or -1000000)
    end

    if usedModNames ~= nil and self.modName ~= nil then
        usedModNames[self.modName] = true
    end

    local idx = 0
    for fillTypeIndex, modifier in pairs(self.activeEconomicModifiers) do
        local base = string.format("%s.randomTheftEvents.economic.active(%d)", key, idx)
        setXMLInt(xmlFile, base .. "#fillTypeIndex", fillTypeIndex)
        setXMLString(xmlFile, base .. "#eventName", tostring(modifier.eventName or ""))
        setXMLString(xmlFile, base .. "#fillTypeName", tostring(modifier.fillTypeName or ""))
        setXMLFloat(xmlFile, base .. "#factor", modifier.factor or 1)
        if modifier.endMinute ~= nil then
            setXMLFloat(xmlFile, base .. "#endMinute", modifier.endMinute)
        end
        if modifier.endPeriod ~= nil then
            setXMLInt(xmlFile, base .. "#endPeriod", modifier.endPeriod)
        end
        idx = idx + 1
    end
end

function RandomTheftEvents:deleteMap()
    self:savePersistentState()
end

function RandomTheftEvents:update(dt)
    if g_currentMission == nil or not g_currentMission:getIsServer() then
        return
    end

    local systemEnabled = self:isSystemEnabled()
    if not systemEnabled then
        if self._lastSystemEnabledState ~= false then
            self:dbg("update skip: system disabled by toggle")
        end
        self._lastSystemEnabledState = false
        return
    end

    if self._lastSystemEnabledState ~= true then
        self:dbg("system enabled: periodic logic active")
    end
    self._lastSystemEnabledState = true

    if self.onlyWhenPlayerInSession and not self:hasAnyActiveUser() then
        self:dbg("periodic skip: no players")
        return
    end

    local scale = 1
    if not self.useRealTime and g_currentMission.missionInfo ~= nil and g_currentMission.missionInfo.timeScale ~= nil then
        scale = g_currentMission.missionInfo.timeScale
    end

    local deltaMinutes = (dt / 60000) * scale
    self.totalMinutes = self.totalMinutes + deltaMinutes
    self.elapsedSessionMinutes = self.elapsedSessionMinutes + deltaMinutes
    self.checkTimerMinutes = self.checkTimerMinutes + deltaMinutes

    if self.pendingStartupEvaluation == true then
        self.pendingStartupEvaluation = false
        self:tryRunStartupEvent()
        self:tryRunStartupMissingVehicleEvent()
        self:tryRunStartupGlobalEvents()
        if ECONOMIC_EVENTS_ENABLED then
            self:processEconomicEvents(true)
            self:updateEconomicModifiers()
        end
    elseif ECONOMIC_EVENTS_ENABLED then
        self:updateEconomicModifiers()
    end

    if self.elapsedSessionMinutes < self.minimumSessionMinutesBeforeEvents then
        return
    end

    local shouldRunPeriodic = false
    if self.pendingImmediatePeriodicCheck == true then
        self.pendingImmediatePeriodicCheck = false
        shouldRunPeriodic = true
    elseif self.checkTimerMinutes >= self.checkIntervalMinutes then
        shouldRunPeriodic = true
    end

    if not shouldRunPeriodic then
        return
    end

    self:dbg("periodic event check start")
    self.checkTimerMinutes = 0
    self:processEvent("fuel", self.events.fuel, self.fillTypes.fuel, self.events.fuel.message)
    self:processEvent("seeds", self.events.seeds, self.fillTypes.seeds, self.events.seeds.message)
    self:processEvent("fertilizer", self.events.fertilizer, self.fillTypes.fertilizer, self.events.fertilizer.message)
    self:processGlobalEventsPeriodic()
    if ECONOMIC_EVENTS_ENABLED then
        self:processEconomicEvents(false)
    end
end

function RandomTheftEvents:getCurrentPeriod()
    if g_currentMission ~= nil and g_currentMission.environment ~= nil and g_currentMission.environment.currentPeriod ~= nil then
        return g_currentMission.environment.currentPeriod
    end
    return 1
end

function RandomTheftEvents:getPeriodsPerYear()
    if g_currentMission ~= nil and g_currentMission.environment ~= nil then
        if g_currentMission.environment.periodsPerYear ~= nil then
            return g_currentMission.environment.periodsPerYear
        end
    end
    return 12
end

function RandomTheftEvents:getCurrentGameYear()
    if g_currentMission ~= nil and g_currentMission.environment ~= nil and g_currentMission.environment.currentYear ~= nil then
        return g_currentMission.environment.currentYear
    end

    local periodsPerYear = self:getPeriodsPerYear()
    local currentPeriod = self:getCurrentPeriod()
    local daysPerPeriod = 1
    if g_currentMission ~= nil and g_currentMission.environment ~= nil and g_currentMission.environment.daysPerPeriod ~= nil then
        daysPerPeriod = g_currentMission.environment.daysPerPeriod
    end

    local absoluteDay = nil
    if g_currentMission ~= nil and g_currentMission.environment ~= nil and g_currentMission.environment.currentDay ~= nil then
        absoluteDay = g_currentMission.environment.currentDay
    end
    if absoluteDay == nil then
        absoluteDay = math.floor(self.totalMinutes / 1440) + 1
    end

    local yearIndex = math.floor((absoluteDay - 1) / math.max(1, periodsPerYear * daysPerPeriod)) + 1
    self:dbg(string.format("calendar currentPeriod=%s daysPerPeriod=%s gameYear=%s", tostring(currentPeriod), tostring(daysPerPeriod), tostring(yearIndex)))
    return yearIndex
end

function RandomTheftEvents:isPeriodAllowed(cfg, eventName)
    local currentPeriod = self:getCurrentPeriod()
    local minPeriod = cfg.minPeriod or 1
    local maxPeriod = cfg.maxPeriod or self:getPeriodsPerYear()

    local allowed = false
    if minPeriod <= maxPeriod then
        allowed = currentPeriod >= minPeriod and currentPeriod <= maxPeriod
    else
        allowed = currentPeriod >= minPeriod or currentPeriod <= maxPeriod
    end

    self:dbg(string.format("%s period check current=%s min=%s max=%s pass=%s", tostring(eventName), tostring(currentPeriod), tostring(minPeriod), tostring(maxPeriod), tostring(allowed)))
    return allowed
end

function RandomTheftEvents:getAbsolutePeriodIndex()
    local periodsPerYear = self:getPeriodsPerYear()
    local year = self:getCurrentGameYear()
    local period = self:getCurrentPeriod()
    return ((year - 1) * periodsPerYear) + period
end

function RandomTheftEvents:resetYearCountersIfNeeded(cfg, eventName)
    local currentYear = self:getCurrentGameYear()
    if cfg.lastTriggeredYear ~= currentYear then
        cfg.lastTriggeredYear = currentYear
        cfg.triggersThisYear = 0
        self:dbg(string.format("%s yearly reset year=%s", tostring(eventName), tostring(currentYear)))
    end
end

function RandomTheftEvents:isYearlyLimitAllowed(cfg, eventName)
    self:resetYearCountersIfNeeded(cfg, eventName)
    local maxPerYear = cfg.maxTriggersPerGameYear or 0
    if cfg.oncePerGameYear then
        maxPerYear = math.max(maxPerYear, 1)
    end
    if maxPerYear > 0 and (cfg.triggersThisYear or 0) >= maxPerYear then
        self:dbg(string.format("%s yearly limit failed triggersThisYear=%s max=%s lastYear=%s", tostring(eventName), tostring(cfg.triggersThisYear), tostring(maxPerYear), tostring(cfg.lastTriggeredYear)))
        return false
    end
    self:dbg(string.format("%s yearly limit pass triggersThisYear=%s lastYear=%s", tostring(eventName), tostring(cfg.triggersThisYear), tostring(cfg.lastTriggeredYear)))
    return true
end

function RandomTheftEvents:isCooldownPeriodsAllowed(cfg, eventName)
    local cooldownPeriods = cfg.cooldownPeriods or 0
    if cooldownPeriods <= 0 then
        return true
    end

    local currentAbsPeriod = self:getAbsolutePeriodIndex()
    local lastPeriod = cfg.lastTriggeredPeriod or -1000000
    if (currentAbsPeriod - lastPeriod) < cooldownPeriods then
        self:dbg(string.format("%s cooldownPeriods failed current=%s last=%s cooldown=%s", tostring(eventName), tostring(currentAbsPeriod), tostring(lastPeriod), tostring(cooldownPeriods)))
        return false
    end
    self:dbg(string.format("%s cooldownPeriods pass current=%s last=%s cooldown=%s", tostring(eventName), tostring(currentAbsPeriod), tostring(lastPeriod), tostring(cooldownPeriods)))
    return true
end

function RandomTheftEvents:markEventTriggered(cfg, eventName)
    cfg.lastTriggerMinute = self.totalMinutes
    cfg.lastTriggeredYear = self:getCurrentGameYear()
    cfg.triggersThisYear = (cfg.triggersThisYear or 0) + 1
    cfg.lastTriggeredPeriod = self:getAbsolutePeriodIndex()
    self:dbg(string.format("%s triggered year=%s triggersThisYear=%s lastPeriod=%s", tostring(eventName), tostring(cfg.lastTriggeredYear), tostring(cfg.triggersThisYear), tostring(cfg.lastTriggeredPeriod)))
    self:savePersistentState()
end

function RandomTheftEvents:getGlobalEventExclusiveGroup(cfg)
    local group = cfg ~= nil and cfg.exclusiveGroup or nil
    if group == nil then
        return nil
    end

    group = tostring(group)
    if group == "" then
        return nil
    end

    return group
end

function RandomTheftEvents:isGlobalEventExclusiveLocked(eventName, cfg)
    local group = self:getGlobalEventExclusiveGroup(cfg)
    if group == nil then
        return false
    end

    local lock = self.globalEventLocks ~= nil and self.globalEventLocks[group] or nil
    if lock == nil then
        return false
    end

    local cooldownPeriods = lock.cooldownPeriods or 0
    if cooldownPeriods <= 0 then
        return false
    end

    local currentAbsPeriod = self:getAbsolutePeriodIndex()
    local lastPeriod = lock.lastTriggeredPeriod or -1000000
    local locked = (currentAbsPeriod - lastPeriod) < cooldownPeriods
    self:dbg(string.format("global exclusive check event=%s group=%s current=%s last=%s cooldown=%s locked=%s", tostring(eventName), tostring(group), tostring(currentAbsPeriod), tostring(lastPeriod), tostring(cooldownPeriods), tostring(locked)))
    return locked
end

function RandomTheftEvents:setGlobalEventExclusiveLock(eventName, cfg)
    local group = self:getGlobalEventExclusiveGroup(cfg)
    if group == nil then
        return
    end

    self.globalEventLocks = self.globalEventLocks or {}
    self.globalEventLocks[group] = {
        eventName = tostring(eventName or ""),
        lastTriggeredPeriod = self:getAbsolutePeriodIndex(),
        cooldownPeriods = cfg ~= nil and (cfg.cooldownPeriods or 0) or 0
    }

    local lock = self.globalEventLocks[group]
    self:dbg(string.format("global exclusive lock set event=%s group=%s last=%s cooldown=%s", tostring(eventName), tostring(group), tostring(lock.lastTriggeredPeriod), tostring(lock.cooldownPeriods)))
end

function RandomTheftEvents:getSortedGlobalEventNames()
    local names = {}
    for eventName, _ in pairs(self.globalEvents or {}) do
        table.insert(names, eventName)
    end
    table.sort(names)
    return names
end


function RandomTheftEvents:getEffectivePrice(fillTypeIndex, basePrice)
    local modifier = self.activeEconomicModifiers[fillTypeIndex]
    if modifier ~= nil and modifier.factor ~= nil then
        return basePrice * modifier.factor
    end
    return basePrice
end

function RandomTheftEvents:installEconomyHooks()
    if self._economyHooksInstalled then
        return
    end
    self._economyHooksInstalled = true

    if EconomyManager ~= nil and EconomyManager.getPricePerLiter ~= nil then
        EconomyManager.getPricePerLiter = Utils.overwrittenFunction(EconomyManager.getPricePerLiter, function(superFunc, ecoMgr, fillTypeIndex, ...)
            local basePrice = superFunc(ecoMgr, fillTypeIndex, ...)
            if g_randomTheftEvents ~= nil then
                return g_randomTheftEvents:getEffectivePrice(fillTypeIndex, basePrice)
            end
            return basePrice
        end)
    end
    if EconomyManager ~= nil and EconomyManager.getCostPerLiter ~= nil then
        EconomyManager.getCostPerLiter = Utils.overwrittenFunction(EconomyManager.getCostPerLiter, function(superFunc, ecoMgr, fillTypeIndex, ...)
            local basePrice = superFunc(ecoMgr, fillTypeIndex, ...)
            if g_randomTheftEvents ~= nil then
                return g_randomTheftEvents:getEffectivePrice(fillTypeIndex, basePrice)
            end
            return basePrice
        end)
    end
end

function RandomTheftEvents:resolveEconomicFactor(eventCfg, basePrice)
    if eventCfg.mode == "multiply" then
        return math.max(0, eventCfg.factor or 1)
    elseif eventCfg.mode == "percent" then
        return math.max(0, 1 + ((eventCfg.percent or 0) / 100))
    elseif eventCfg.mode == "range" then
        local minFactor = eventCfg.minFactor or 1
        local maxFactor = eventCfg.maxFactor or minFactor
        if maxFactor < minFactor then
            maxFactor = minFactor
        end
        return math.max(0, minFactor + (math.random() * (maxFactor - minFactor)))
    elseif eventCfg.mode == "absolute" then
        if basePrice ~= nil and basePrice > 0 and eventCfg.absolutePrice ~= nil and eventCfg.absolutePrice >= 0 then
            return eventCfg.absolutePrice / basePrice
        end
        return nil
    end
    return nil
end

function RandomTheftEvents:getCurrentBasePrice(fillTypeIndex)
    if g_currentMission ~= nil and g_currentMission.economyManager ~= nil and g_currentMission.economyManager.getPricePerLiter ~= nil then
        local price = g_currentMission.economyManager:getPricePerLiter(fillTypeIndex)
        local active = self.activeEconomicModifiers[fillTypeIndex]
        if active ~= nil and active.factor ~= nil and active.factor ~= 0 then
            return price / active.factor
        end
        return price
    end
    return nil
end

function RandomTheftEvents:getCurrentDayInPeriod()
    if g_currentMission ~= nil and g_currentMission.environment ~= nil and g_currentMission.environment.currentDayInPeriod ~= nil then
        return g_currentMission.environment.currentDayInPeriod
    end
    return nil
end

function RandomTheftEvents:isEconomicCalendarPatternAllowed(eventCfg, eventName)
    local currentPeriod = self:getCurrentPeriod()
    local periodsPerYear = self:getPeriodsPerYear()
    if eventCfg.triggerEveryNPeriods ~= nil and eventCfg.triggerEveryNPeriods > 0 then
        if (currentPeriod % eventCfg.triggerEveryNPeriods) ~= 0 then
            self:dbg(eventName .. " skip: triggerEveryNPeriods")
            return false
        end
    end

    local dayInPeriod = self:getCurrentDayInPeriod()
    if eventCfg.triggerOnPeriodStart and dayInPeriod ~= nil and dayInPeriod ~= 1 then
        self:dbg(eventName .. " skip: not period start")
        return false
    end

    if eventCfg.triggerOnYearStart then
        local isYearStartPeriod = currentPeriod == 1
        local isYearStartDay = dayInPeriod == nil or dayInPeriod == 1
        if not (isYearStartPeriod and isYearStartDay) then
            self:dbg(eventName .. " skip: not year start")
            return false
        end
    end
    return true
end

function RandomTheftEvents:processEconomicEvent(eventCfg, isStartup)
    local eventName = "economic " .. tostring(eventCfg.name)
    self:dbg("economic event check start: " .. eventName)
    if not self:areEconomicEventsEnabled() then
        self:dbg(eventName .. " skip: economicEvents block disabled")
        return
    end
    if not self:isEconomicEventEnabled(eventCfg) then
        self:dbg(eventName .. " skip: toggle disabled")
        return
    end
    if not eventCfg.enabled then
        self:dbg(eventName .. " skip: disabled")
        return
    end
    if isStartup then
        if not eventCfg.useStartupEvent then
            self:dbg(eventName .. " skip: startup disabled")
            return
        end
        if eventCfg.oncePerLogin and eventCfg.sessionStartupHandled then
            self:dbg(eventName .. " skip: oncePerLogin")
            return
        end
        eventCfg.sessionStartupHandled = true
    else
        if not eventCfg.usePeriodicEvent then
            self:dbg(eventName .. " skip: periodic disabled")
            return
        end
    end

    if not self:isEventAllowedByHour(eventCfg) then
        self:dbg(eventName .. " skip: wrong hour")
        return
    end
    if not self:isPeriodAllowed(eventCfg, eventName) then
        self:dbg(eventName .. " skip: wrong period")
        return
    end
    if not self:isYearlyLimitAllowed(eventCfg, eventName) then
        self:dbg(eventName .. " skip: yearly limit")
        return
    end
    if not self:isCooldownPeriodsAllowed(eventCfg, eventName) then
        self:dbg(eventName .. " skip: cooldownPeriods")
        return
    end
    if (self.totalMinutes - (eventCfg.lastTriggerMinute or -1000000)) < (eventCfg.cooldownMinutes or 0) then
        self:dbg(eventName .. " skip: cooldown minutes")
        return
    end
    if not self:isEconomicCalendarPatternAllowed(eventCfg, eventName) then
        return
    end

    local chanceRoll = math.random() * 100
    if chanceRoll > (eventCfg.chancePercent or 0) then
        self:dbg(eventName .. " skip: chance failed")
        return
    end

    local fillTypeIndex = self:resolveFillTypeIndex(eventCfg.targetFillType)
    if fillTypeIndex == nil then
        self:dbg(eventName .. " skip: invalid fillType " .. tostring(eventCfg.targetFillType))
        return
    end

    local basePrice = self:getCurrentBasePrice(fillTypeIndex)
    if basePrice == nil then
        self:dbg(eventName .. " skip: basePrice=nil")
        return
    end

    local factor = self:resolveEconomicFactor(eventCfg, basePrice)
    if factor == nil then
        self:dbg(eventName .. " skip: invalid mode/factor")
        return
    end

    local endMinute = nil
    local endPeriod = nil
    if (eventCfg.durationMinutes or 0) > 0 then
        endMinute = self.totalMinutes + eventCfg.durationMinutes
    end
    if (eventCfg.durationPeriods or 0) > 0 then
        endPeriod = self:getAbsolutePeriodIndex() + eventCfg.durationPeriods
    end
    if endMinute == nil and endPeriod == nil then
        endMinute = self.totalMinutes + 1
    end

    self.activeEconomicModifiers[fillTypeIndex] = {
        eventName = eventCfg.name,
        fillTypeName = eventCfg.targetFillType,
        factor = factor,
        endMinute = endMinute,
        endPeriod = endPeriod
    }

    self:markEventTriggered(eventCfg, eventName)
    self:dbg(string.format("%s applied fillType=%s basePrice=%.4f factor=%.4f finalPrice=%.4f endMinute=%s endPeriod=%s", eventName, tostring(eventCfg.targetFillType), basePrice, factor, basePrice * factor, tostring(endMinute), tostring(endPeriod)))
    self:notify(eventCfg.message)
end

function RandomTheftEvents:updateEconomicModifiers()
    local currentPeriodIndex = self:getAbsolutePeriodIndex()
    local changed = false
    for fillTypeIndex, modifier in pairs(self.activeEconomicModifiers) do
        local expiredByMinute = modifier.endMinute ~= nil and self.totalMinutes >= modifier.endMinute
        local expiredByPeriod = modifier.endPeriod ~= nil and currentPeriodIndex >= modifier.endPeriod
        if expiredByMinute or expiredByPeriod then
            self:dbg(string.format("economic modifier expired fillType=%s event=%s", tostring(modifier.fillTypeName), tostring(modifier.eventName)))
            self.activeEconomicModifiers[fillTypeIndex] = nil
            changed = true
        end
    end

    if changed then
        self:savePersistentState()
    end
end

function RandomTheftEvents:processEconomicEvents(isStartup)
    for _, eventCfg in ipairs(self.economicEvents) do
        self:processEconomicEvent(eventCfg, isStartup)
    end
end

function RandomTheftEvents:tryRunStartupEvent()
    self:dbg("startup event check system=" .. tostring(self:isSystemEnabled()) .. " startup=" .. tostring(self:isStartupEnabled()))
    if not self:isStartupEnabled() then
        self:dbg("startup skip: disabled")
        return
    end

    if self.startup.oncePerLogin and self.sessionStartupHandled then
        self:dbg("startup skip: oncePerLogin")
        return
    end
    if not self:isEventAllowedByHour(self.startup) then
        self:dbg("startup skip: hour restriction")
        return
    end

    local isExistingSave = self.saveInitialized
    if isExistingSave and not self.startup.onExistingSave then
        self.sessionStartupHandled = true
        self:dbg("startup skip: existing save disabled")
        return
    end
    if not isExistingSave and not self.startup.onNewSave then
        self.sessionStartupHandled = true
        self:dbg("startup skip: new save disabled")
        return
    end

    local startupCooldown = math.max(30, self.startup.minimumCooldownMinutes or 30)
    if (self.totalMinutes - self.lastStartupMinute) < startupCooldown then
        self:dbg("startup skip: cooldown")
        return
    end

    self.sessionStartupHandled = true

    local startupRoll = math.random() * 100
    if startupRoll > (self.startup.chancePercent or 0) then
        self:dbg("startup skip: chance failed")
        return
    end

    local startupCandidates = {}
    if self.startup.allowFuel and self:isLocalEventEnabled("fuel", self.events.fuel) and self.events.fuel.useStartupEvent then
        if self:isPeriodAllowed(self.events.fuel, "startup fuel") and self:isYearlyLimitAllowed(self.events.fuel, "startup fuel") and self:isCooldownPeriodsAllowed(self.events.fuel, "startup fuel") then
            table.insert(startupCandidates, {name="fuel", cfg=self.events.fuel, types=self.fillTypes.fuel, message=self.events.fuel.message})
        end
    end
    if self.startup.allowSeeds and self:isLocalEventEnabled("seeds", self.events.seeds) and self.events.seeds.useStartupEvent then
        if self:isPeriodAllowed(self.events.seeds, "startup seeds") and self:isYearlyLimitAllowed(self.events.seeds, "startup seeds") and self:isCooldownPeriodsAllowed(self.events.seeds, "startup seeds") then
            table.insert(startupCandidates, {name="seeds", cfg=self.events.seeds, types=self.fillTypes.seeds, message=self.events.seeds.message})
        end
    end
    if self.startup.allowFertilizer and self:isLocalEventEnabled("fertilizer", self.events.fertilizer) and self.events.fertilizer.useStartupEvent then
        if self:isPeriodAllowed(self.events.fertilizer, "startup fertilizer") and self:isYearlyLimitAllowed(self.events.fertilizer, "startup fertilizer") and self:isCooldownPeriodsAllowed(self.events.fertilizer, "startup fertilizer") then
            table.insert(startupCandidates, {name="fertilizer", cfg=self.events.fertilizer, types=self.fillTypes.fertilizer, message=self.events.fertilizer.message})
        end
    end

    if #startupCandidates == 0 then
        self:dbg("startup skip: no startup candidates")
        return
    end

    local selected = startupCandidates[math.random(1, #startupCandidates)]
    if self:executeEventTheft(selected.name, selected.cfg, selected.types, selected.message) then
        self.lastStartupMinute = self.totalMinutes
        self:markEventTriggered(selected.cfg, "startup " .. tostring(selected.name))
    else
        self:dbg("startup skip: no candidates after filters")
    end
end

function RandomTheftEvents:getVehicleDeletionCandidates()
    local vehicles = g_currentMission ~= nil and g_currentMission.vehicleSystem ~= nil and g_currentMission.vehicleSystem.vehicles or nil
    if vehicles == nil then
        return {}
    end

    local farmSet = self:getCandidateFarmSet()
    local candidates = {}
    local seen = 0
    local filtered = 0

    for _, vehicle in pairs(vehicles) do
        seen = seen + 1
        local farmId = self:getVehicleFarmId(vehicle)
        if farmId ~= nil and (farmSet == nil or farmSet[farmId]) and not self:isVehicleBlocked(vehicle) and vehicle.delete ~= nil then
            filtered = filtered + 1
            table.insert(candidates, vehicle)
        end
    end

    self:dbg(string.format("vehicle scan total=%d filtered=%d", seen, filtered))
    return candidates
end

function RandomTheftEvents:tryRunStartupMissingVehicleEvent()
    self:dbg("startupMissingVehicle check enabled=" .. tostring(self:isStartupMissingVehicleEnabled()))
    if not self:isStartupMissingVehicleEnabled() then
        self:dbg("startup vehicle loss skip: toggle disabled")
        return
    end

    if self.startupMissingVehicle.oncePerLogin and self.sessionStartupMissingVehicleHandled then
        return
    end
    if not self:isEventAllowedByHour(self.startupMissingVehicle) then
        self:dbg("startup vehicle loss skip: hour restriction")
        return
    end

    self.sessionStartupMissingVehicleHandled = true

    if not self:isPeriodAllowed(self.startupMissingVehicle, "startupMissingVehicle") then
        self:dbg("startup vehicle loss skip: period restriction")
        return
    end
    if not self:isYearlyLimitAllowed(self.startupMissingVehicle, "startupMissingVehicle") then
        self:dbg("startup vehicle loss skip: yearly limit")
        return
    end
    if not self:isCooldownPeriodsAllowed(self.startupMissingVehicle, "startupMissingVehicle") then
        self:dbg("startup vehicle loss skip: cooldownPeriods")
        return
    end

    local startupCooldown = math.max(30, self.startupMissingVehicle.minimumCooldownMinutes or 30)
    if (self.totalMinutes - self.lastStartupMissingVehicleMinute) < startupCooldown then
        self:dbg("startup vehicle loss skip: cooldown")
        return
    end

    local roll = math.random() * 100
    if roll > (self.startupMissingVehicle.chancePercent or 0) then
        self:dbg("startup vehicle loss skip: chance failed")
        return
    end

    local candidates = self:getVehicleDeletionCandidates()
    if #candidates == 0 then
        self:dbg("startup vehicle loss skip: no candidates")
        return
    end

    local target = candidates[math.random(1, #candidates)]
    local targetFarmId = self:getVehicleFarmId(target)
    local targetName = nil
    if target ~= nil and target.getName ~= nil then
        targetName = target:getName()
    end
    if targetName == nil or targetName == "" then
        targetName = target ~= nil and target.configFileName or nil
    end
    if targetName == nil or targetName == "" then
        targetName = tostring(target)
    end
    local rootNodeId = target ~= nil and target.rootNode or nil
    self:log(string.format("Deleted vehicle: %s (farmId=%s, rootNode=%s, config=%s)", tostring(targetName), tostring(targetFarmId), tostring(rootNodeId), tostring(target ~= nil and target.configFileName or "")))
    local deleted = pcall(function()
        target:delete()
    end)

    if deleted then
        self.lastStartupMissingVehicleMinute = self.totalMinutes
        self:markEventTriggered(self.startupMissingVehicle, "startupMissingVehicle")
        self:notify(self.startupMissingVehicle.message or "Пока вас не было, пропала одна единица техники.")
        self:dbg("startup vehicle loss applied")
    else
        self:dbg("startup vehicle loss skip: delete failed")
    end
end

function RandomTheftEvents:resolveSourceStateRange(fruitTypeDesc)
    if fruitTypeDesc == nil then
        return nil, nil
    end

    local minState = fruitTypeDesc.minDisasterDestructionState
    local maxState = fruitTypeDesc.maxDisasterDestructionState
    if minState ~= nil and maxState ~= nil then
        return minState, maxState
    end

    local minHarvest = fruitTypeDesc.minHarvestingGrowthState
    local maxHarvest = fruitTypeDesc.maxHarvestingGrowthState
    if minHarvest ~= nil and maxHarvest ~= nil and minHarvest <= maxHarvest then
        return minHarvest, maxHarvest
    end

    return nil, nil
end

function RandomTheftEvents:getGlobalTargetState(eventName, fruitTypeDesc)
    if fruitTypeDesc == nil then
        return nil, "fruitTypeDesc=nil"
    end

    if eventName == "flood" then
        if fruitTypeDesc.cutState ~= nil and fruitTypeDesc.cutState > 0 then
            return fruitTypeDesc.cutState, "cutState"
        end
        return nil, "missing cutState"
    end

    if fruitTypeDesc.witheredState ~= nil then
        return fruitTypeDesc.witheredState, "witheredState"
    end

    local disasterState = fruitTypeDesc.disasterDestructionState
    if disasterState ~= nil and disasterState > 0 then
        return disasterState, "disasterDestructionState"
    end

    return nil, "missing withered/disaster state"
end

function RandomTheftEvents:applyGlobalCropState(eventName, cfg)
    local fruitTypeManager = g_fruitTypeManager
    if fruitTypeManager == nil or fruitTypeManager.getFruitTypes == nil then
        self:dbg("global event " .. eventName .. " skip: fruitTypeManager unavailable")
        return false
    end

    local fruitTypes = fruitTypeManager:getFruitTypes()
    if fruitTypes == nil then
        self:dbg("global event " .. eventName .. " skip: no fruit types")
        return false
    end

    local terrainNode = g_terrainNode
    if terrainNode == nil then
        self:dbg("global event " .. eventName .. " skip: g_terrainNode=nil")
        return false
    end

    local mapSize = getTerrainSize(terrainNode)
    local mapHalf = mapSize * 0.5
    local processed = 0
    local skipped = 0

    for _, fruitTypeDesc in pairs(fruitTypes) do
        local fruitName = tostring(fruitTypeDesc ~= nil and fruitTypeDesc.name or "unknown")
        if fruitTypeDesc ~= nil and fruitTypeDesc.getDataPlaneInfo ~= nil and fruitTypeDesc.useForFieldMissions ~= false then
            local terrainDataPlaneId, startStateChannel, numStateChannels = fruitTypeDesc:getDataPlaneInfo()
            if terrainDataPlaneId ~= nil and startStateChannel ~= nil and numStateChannels ~= nil then
                local targetState, targetSource = self:getGlobalTargetState(eventName, fruitTypeDesc)
                local minSourceState, maxSourceState = self:resolveSourceStateRange(fruitTypeDesc)
                if targetState ~= nil and minSourceState ~= nil and maxSourceState ~= nil then
                    local modifier = DensityMapModifier.new(terrainDataPlaneId, startStateChannel, numStateChannels, terrainNode)
                    local filter = DensityMapFilter.new(terrainDataPlaneId, startStateChannel, numStateChannels, terrainNode)
                    modifier:setParallelogramWorldCoords(-mapHalf, -mapHalf, mapSize, 0, 0, mapSize, DensityCoordType.POINT_POINT_POINT)
                    filter:setValueCompareParams(DensityValueCompareType.BETWEEN, minSourceState, maxSourceState)
                    modifier:executeSet(targetState, filter)
                    processed = processed + 1
                    self:dbg(string.format("global %s fruit=%s target=%s source=%s range=%s-%s processed", eventName, fruitName, tostring(targetState), tostring(targetSource), tostring(minSourceState), tostring(maxSourceState)))
                else
                    skipped = skipped + 1
                    self:dbg(string.format("global %s fruit=%s skipped reason=no valid target/range", eventName, fruitName))
                end
            else
                skipped = skipped + 1
                self:dbg(string.format("global %s fruit=%s skipped reason=no dataplane", eventName, fruitName))
            end
        else
            skipped = skipped + 1
            self:dbg(string.format("global %s fruit=%s skipped reason=not field crop", eventName, fruitName))
        end
    end

    self:dbg(string.format("global %s summary processed=%d skipped=%d", eventName, processed, skipped))
    return processed > 0
end

function RandomTheftEvents:tryRunStartupGlobalEvent(eventName, cfg)
    if not self:areGlobalEventsEnabled() then
        self:dbg("startup global " .. eventName .. " skip: globalEvents block disabled")
        return
    end
    if not self:isGlobalEventEnabled(eventName, cfg) then
        self:dbg("startup global " .. eventName .. " skip: toggle disabled")
        return
    end
    if not cfg.enabled then
        self:dbg("startup global " .. eventName .. " skip: disabled")
        return
    end
    if not cfg.useStartupEvent then
        self:dbg("startup global " .. eventName .. " skip: useStartupEvent=false")
        return
    end
    if cfg.oncePerLogin and cfg.sessionStartupHandled then
        self:dbg("startup global " .. eventName .. " skip: oncePerLogin")
        return
    end
    if not self:isEventAllowedByHour(cfg) then
        self:dbg("startup global " .. eventName .. " skip: hour restriction")
        return
    end

    if not self:isPeriodAllowed(cfg, "startup global " .. eventName) then
        self:dbg("startup global " .. eventName .. " skip: period restriction")
        return
    end
    if not self:isYearlyLimitAllowed(cfg, "startup global " .. eventName) then
        self:dbg("startup global " .. eventName .. " skip: yearly limit")
        return
    end
    if not self:isCooldownPeriodsAllowed(cfg, "startup global " .. eventName) then
        self:dbg("startup global " .. eventName .. " skip: cooldownPeriods")
        return
    end
    if self:isGlobalEventExclusiveLocked(eventName, cfg) then
        self:dbg("startup global " .. eventName .. " skip: exclusiveGroup lock")
        return
    end

    cfg.sessionStartupHandled = true

    local startupCooldown = math.max(30, cfg.minimumCooldownMinutes or 30)
    if (self.totalMinutes - cfg.lastStartupMinute) < startupCooldown then
        self:dbg("startup global " .. eventName .. " skip: cooldown")
        return
    end

    local roll = math.random() * 100
    if roll > (cfg.chancePercent or 0) then
        self:dbg("startup global " .. eventName .. " skip: chance failed")
        return
    end

    if self:applyGlobalCropState(eventName, cfg) then
        cfg.lastStartupMinute = self.totalMinutes
        self:setGlobalEventExclusiveLock(eventName, cfg)
        self:markEventTriggered(cfg, "startup global " .. eventName)
        self:notify(cfg.message)
    else
        self:dbg("startup global " .. eventName .. " skip: no valid fruit types")
    end
end

function RandomTheftEvents:tryRunStartupGlobalEvents()
    self:dbg("startup global event check blockEnabled=" .. tostring(self:areGlobalEventsEnabled()))
    for _, eventName in ipairs(self:getSortedGlobalEventNames()) do
        self:tryRunStartupGlobalEvent(eventName, self.globalEvents[eventName])
    end
end

function RandomTheftEvents:processGlobalEventPeriodic(eventName, cfg)
    if not self:areGlobalEventsEnabled() then
        self:dbg("periodic global " .. eventName .. " skip: globalEvents block disabled")
        return
    end
    if not self:isGlobalEventEnabled(eventName, cfg) then
        self:dbg("periodic global " .. eventName .. " skip: toggle disabled")
        return
    end
    if not cfg.enabled then
        self:dbg("periodic global " .. eventName .. " skip: disabled")
        return
    end
    if not cfg.usePeriodicEvent then
        self:dbg("periodic global " .. eventName .. " skip: usePeriodicEvent=false")
        return
    end
    if not self:isPeriodAllowed(cfg, "periodic global " .. eventName) then
        self:dbg("periodic global " .. eventName .. " skip: period restriction")
        return
    end
    if not self:isYearlyLimitAllowed(cfg, "periodic global " .. eventName) then
        self:dbg("periodic global " .. eventName .. " skip: yearly limit")
        return
    end
    if not self:isCooldownPeriodsAllowed(cfg, "periodic global " .. eventName) then
        self:dbg("periodic global " .. eventName .. " skip: cooldownPeriods")
        return
    end
    if self:isGlobalEventExclusiveLocked(eventName, cfg) then
        self:dbg("periodic global " .. eventName .. " skip: exclusiveGroup lock")
        return
    end
    if self.totalMinutes - cfg.lastTriggerMinute < (cfg.cooldownMinutes or 0) then
        self:dbg("periodic global " .. eventName .. " skip: cooldown")
        return
    end
    if not self:isEventAllowedByHour(cfg) then
        self:dbg("periodic global " .. eventName .. " skip: hour restriction")
        return
    end

    local roll = math.random() * 100
    if roll > (cfg.chancePercent or 0) then
        self:dbg("periodic global " .. eventName .. " skip: chance failed")
        return
    end

    if self:applyGlobalCropState(eventName, cfg) then
        self:setGlobalEventExclusiveLock(eventName, cfg)
        self:markEventTriggered(cfg, "periodic global " .. eventName)
        self:notify(cfg.message)
    else
        self:dbg("periodic global " .. eventName .. " skip: no valid fruit types")
    end
end

function RandomTheftEvents:processGlobalEventsPeriodic()
    self:dbg("periodic global event check blockEnabled=" .. tostring(self:areGlobalEventsEnabled()))
    for _, eventName in ipairs(self:getSortedGlobalEventNames()) do
        self:processGlobalEventPeriodic(eventName, self.globalEvents[eventName])
    end
end

function RandomTheftEvents:hasAnyActiveUser()
    if g_currentMission == nil or g_currentMission.userManager == nil or g_currentMission.userManager.getUsers == nil then
        return true
    end

    local users = g_currentMission.userManager:getUsers()
    return users ~= nil and next(users) ~= nil
end

function RandomTheftEvents:resolveFillTypeIndex(name)
    if g_fillTypeManager == nil or name == nil then
        return nil
    end

    if g_fillTypeManager.getFillTypeIndexByName ~= nil then
        local idx = g_fillTypeManager:getFillTypeIndexByName(name)
        if idx ~= nil and idx ~= FillType.UNKNOWN then
            return idx
        end
    end

    if FillType ~= nil then
        local idx = FillType[name]
        if idx ~= nil and idx ~= FillType.UNKNOWN then
            return idx
        end
    end

    return nil
end

function RandomTheftEvents:resolveFillTypes()
    self.fillTypes.fuel = {}
    self.fillTypes.seeds = {}
    self.fillTypes.fertilizer = {}

    local fuelNames = {"DIESEL", "FUEL"}
    for _, name in ipairs(fuelNames) do
        local idx = self:resolveFillTypeIndex(name)
        if idx ~= nil then
            self.fillTypes.fuel[idx] = true
        end
    end

    local seeds = self:resolveFillTypeIndex("SEEDS")
    if seeds ~= nil then
        self.fillTypes.seeds[seeds] = true
    end

    local fert = self:resolveFillTypeIndex("FERTILIZER")
    if fert ~= nil then
        self.fillTypes.fertilizer[fert] = true
    end

    local liqFert = self:resolveFillTypeIndex("LIQUIDFERTILIZER")
    if liqFert ~= nil then
        self.fillTypes.fertilizer[liqFert] = true
    end

    local function countKeys(t)
        local n = 0
        for _, _ in pairs(t) do
            n = n + 1
        end
        return n
    end

    self:dbg(string.format("fill types resolved fuel=%d seeds=%d fertilizer=%d", countKeys(self.fillTypes.fuel), countKeys(self.fillTypes.seeds), countKeys(self.fillTypes.fertilizer)))
end

function RandomTheftEvents:getCandidateFarmSet()
    local farmSet = {}
    if not self.filters.farmScoped then
        return nil
    end

    if g_currentMission == nil or g_currentMission.userManager == nil or g_currentMission.userManager.getUsers == nil then
        return nil
    end

    local users = g_currentMission.userManager:getUsers()
    if users == nil then
        return nil
    end

    for _, user in pairs(users) do
        if user ~= nil and user.farmId ~= nil and user.farmId > 0 then
            farmSet[user.farmId] = true
        end
    end

    if next(farmSet) == nil then
        return nil
    end

    return farmSet
end

function RandomTheftEvents:isVehicleBlocked(vehicle)
    if vehicle == nil then
        return true
    end

    if self.filters.skipEnteredVehicles then
        if vehicle.getIsControlled ~= nil and vehicle:getIsControlled() then
            return true
        end
        if vehicle.getIsEntered ~= nil and vehicle:getIsEntered() then
            return true
        end
    end

    if self.filters.skipActiveMotorizedVehicles and vehicle.getIsMotorStarted ~= nil and vehicle:getIsMotorStarted() then
        return true
    end

    if self.filters.skipMovingVehicles and vehicle.getLastSpeed ~= nil then
        local speed = vehicle:getLastSpeed() or 0
        if speed > 0.5 then
            return true
        end
    end

    if self.filters.skipVehiclesWithAttachedImplementInUse and vehicle.getAttachedImplements ~= nil then
        local attached = vehicle:getAttachedImplements()
        if attached ~= nil then
            for _, impl in pairs(attached) do
                local obj = impl ~= nil and impl.object or nil
                if obj ~= nil and obj.getIsTurnedOn ~= nil and obj:getIsTurnedOn() then
                    return true
                end
            end
        end
    end

    return false
end

function RandomTheftEvents:getVehicleFarmId(vehicle)
    if vehicle == nil then
        return nil
    end

    if vehicle.getOwnerFarmId ~= nil then
        local farmId = vehicle:getOwnerFarmId()
        if farmId ~= nil and farmId > 0 then
            return farmId
        end
    end

    if vehicle.ownerFarmId ~= nil and vehicle.ownerFarmId > 0 then
        return vehicle.ownerFarmId
    end

    return nil
end

function RandomTheftEvents:getFillUnitIndices(vehicle)
    local result = {}

    if vehicle.getFillUnits ~= nil then
        local fillUnits = vehicle:getFillUnits()
        if fillUnits ~= nil then
            for index, _ in pairs(fillUnits) do
                if type(index) == "number" then
                    result[index] = true
                end
            end
        end
    end

    if vehicle.spec_fillUnit ~= nil and vehicle.spec_fillUnit.fillUnits ~= nil then
        for index, _ in pairs(vehicle.spec_fillUnit.fillUnits) do
            if type(index) == "number" then
                result[index] = true
            end
        end
    end

    return result
end

function RandomTheftEvents:findMatchingFillUnit(vehicle, acceptedFillTypes)
    if vehicle == nil then
        return nil
    end

    local indices = self:getFillUnitIndices(vehicle)
    for fillUnitIndex, _ in pairs(indices) do
        if vehicle.getFillUnitFillType ~= nil and vehicle.getFillUnitFillLevel ~= nil then
            local currentFillType = vehicle:getFillUnitFillType(fillUnitIndex)
            local level = vehicle:getFillUnitFillLevel(fillUnitIndex) or 0
            if level > 0 and currentFillType ~= nil and acceptedFillTypes[currentFillType] then
                return fillUnitIndex, currentFillType, level
            end
        end
    end

    return nil
end

function RandomTheftEvents:chooseDrainAmount(level, eventCfg)
    if level <= 0 then
        return 0
    end

    if eventCfg.drainMode == "full" then
        return level
    elseif eventCfg.drainMode == "range" then
        local minP = math.max(0, eventCfg.minPercent or 0)
        local maxP = math.max(minP, eventCfg.maxPercent or minP)
        local p = minP + (math.random() * (maxP - minP))
        return math.min(level, level * (p / 100))
    end

    local p = math.max(0, eventCfg.percent or 0)
    return math.min(level, level * (p / 100))
end

function RandomTheftEvents:applyDrain(vehicle, farmId, fillUnitIndex, fillTypeIndex, amount)
    if amount <= 0 or vehicle == nil then
        return false
    end

    if vehicle.addFillUnitFillLevel ~= nil then
        vehicle:addFillUnitFillLevel(farmId or 0, fillUnitIndex, -amount, fillTypeIndex, ToolType and ToolType.UNDEFINED or nil, nil)
        return true
    end

    if vehicle.setFillUnitFillLevel ~= nil then
        local oldLevel = vehicle:getFillUnitFillLevel(fillUnitIndex) or 0
        local newLevel = math.max(0, oldLevel - amount)
        vehicle:setFillUnitFillLevel(farmId or 0, fillUnitIndex, newLevel, fillTypeIndex, ToolType and ToolType.UNDEFINED or nil)
        return true
    end

    return false
end

function RandomTheftEvents:showLocalMessage(text)
    if not self.messageEnabled then
        return
    end

    local shownDialog = false
    if InfoDialog ~= nil and InfoDialog.show ~= nil then
        local dialogType = DialogElement ~= nil and DialogElement.TYPE_WARNING or nil
        local ok, _ = pcall(function()
            InfoDialog.show(tostring(text), nil, nil, dialogType)
        end)
        shownDialog = ok
    end

    if shownDialog then
        self:dbg("dialog shown: InfoDialog(TYPE_WARNING)")
        return
    end

    self:dbg("dialog fallback: ingame notification")
    if g_currentMission ~= nil and g_currentMission.addIngameNotification ~= nil and FSBaseMission ~= nil then
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_INFO, text)
        return
    end

    self:dbg("dialog fallback: log only")
    self:log(text)
end

function RandomTheftEvents:notify(text)
    if not self.messageEnabled then
        return
    end

    if g_server ~= nil then
        RandomTheftEventsDialogEvent.sendToClients(text)
        self:showLocalMessage(text)
    else
        self:showLocalMessage(text)
    end
end

function RandomTheftEvents:isEventAllowedByHour(eventCfg)
    if g_currentMission == nil or g_currentMission.environment == nil or g_currentMission.environment.currentHour == nil then
        return true
    end

    local h = g_currentMission.environment.currentHour
    local minHour = eventCfg.minHour or 0
    local maxHour = eventCfg.maxHour or 24

    if minHour <= maxHour then
        return h >= minHour and h <= maxHour
    end

    return h >= minHour or h <= maxHour
end

function RandomTheftEvents:processEvent(eventName, eventCfg, acceptedFillTypes, messageText)
    self:dbg("periodic local check " .. tostring(eventName) .. " blockEnabled=" .. tostring(self:areLocalEventsEnabled()) .. " eventEnabled=" .. tostring(self:isLocalEventEnabled(eventName, eventCfg)) .. " cfgEnabled=" .. tostring(eventCfg ~= nil and eventCfg.enabled == true))
    if not self:areLocalEventsEnabled() then
        self:dbg("periodic skip " .. eventName .. ": events block disabled")
        return
    end
    if not self:isLocalEventEnabled(eventName, eventCfg) then
        self:dbg("periodic skip " .. eventName .. ": toggle disabled")
        return
    end
    if not eventCfg.enabled then
        self:dbg("periodic skip " .. eventName .. ": disabled")
        return
    end
    if not eventCfg.usePeriodicEvent then
        self:dbg("periodic skip " .. eventName .. ": usePeriodicEvent=false")
        return
    end
    if not self:isPeriodAllowed(eventCfg, eventName) then
        self:dbg("periodic skip " .. eventName .. ": period restriction")
        return
    end
    if not self:isYearlyLimitAllowed(eventCfg, eventName) then
        self:dbg("periodic skip " .. eventName .. ": yearly limit")
        return
    end
    if not self:isCooldownPeriodsAllowed(eventCfg, eventName) then
        self:dbg("periodic skip " .. eventName .. ": cooldownPeriods")
        return
    end

    if self.totalMinutes - eventCfg.lastTriggerMinute < eventCfg.cooldownMinutes then
        self:dbg("periodic skip " .. eventName .. ": cooldown")
        return
    end

    if not self:isEventAllowedByHour(eventCfg) then
        self:dbg("periodic skip " .. eventName .. ": hour restriction")
        return
    end

    local roll = math.random() * 100
    if roll > eventCfg.chancePercent then
        self:dbg("periodic skip " .. eventName .. ": chance failed")
        return
    end

    if self:executeEventTheft(eventName, eventCfg, acceptedFillTypes, messageText) then
        self:markEventTriggered(eventCfg, eventName)
    end
end

function RandomTheftEvents:executeEventTheft(eventName, eventCfg, acceptedFillTypes, messageText)

    local farmSet = self:getCandidateFarmSet()
    local candidates = {}
    local vehicles = g_currentMission ~= nil and g_currentMission.vehicleSystem ~= nil and g_currentMission.vehicleSystem.vehicles or nil
    if vehicles == nil then
        self:dbg("event " .. eventName .. " skip: vehicles=nil")
        return false
    end

    local seen = 0
    local filtered = 0
    for _, vehicle in pairs(vehicles) do
        seen = seen + 1
        local farmId = self:getVehicleFarmId(vehicle)
        if farmId ~= nil and (farmSet == nil or farmSet[farmId]) and not self:isVehicleBlocked(vehicle) then
            filtered = filtered + 1
            local fillUnitIndex, fillTypeIndex, level = self:findMatchingFillUnit(vehicle, acceptedFillTypes)
            if fillUnitIndex ~= nil and level > 0 then
                table.insert(candidates, {
                    vehicle = vehicle,
                    farmId = farmId,
                    fillUnitIndex = fillUnitIndex,
                    fillTypeIndex = fillTypeIndex,
                    level = level
                })
            end
        end
    end
    self:dbg(string.format("event %s vehicles total=%d filtered=%d candidates=%d", eventName, seen, filtered, #candidates))

    if #candidates == 0 then
        self:dbg("event " .. eventName .. " skipped: no candidates")
        return false
    end

    local selected = candidates[math.random(1, #candidates)]
    self:dbg(string.format("event %s selected fillUnit=%s fillType=%s level=%.2f", eventName, tostring(selected.fillUnitIndex), tostring(selected.fillTypeIndex), tonumber(selected.level) or 0))
    local amount = self:chooseDrainAmount(selected.level, eventCfg)
    if amount <= 0 then
        return false
    end

    local ok = self:applyDrain(selected.vehicle, selected.farmId, selected.fillUnitIndex, selected.fillTypeIndex, amount)
    if ok then
        self:notify(messageText)
        self:dbg(string.format("event %s applied farm=%s amount=%.2f", eventName, tostring(selected.farmId), amount))
        return true
    end
    return false
end

local function loadMission()
    if g_randomTheftEvents == nil then
        g_randomTheftEvents = RandomTheftEvents.new(THIS_MOD_DIR)
        addModEventListener(g_randomTheftEvents)
    end
end

local function deleteMission()
    if g_randomTheftEvents ~= nil then
        removeModEventListener(g_randomTheftEvents)
        g_randomTheftEvents = nil
    end
end

Mission00.load = Utils.prependedFunction(Mission00.load, loadMission)
FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, deleteMission)
