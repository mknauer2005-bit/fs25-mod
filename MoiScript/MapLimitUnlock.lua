MapLimitUnlock = {}
MapLimitUnlock.MOD_NAME = g_currentModName or "FS25_MapLimitUnlock"
MapLimitUnlock.LOG_PREFIX = "[LimitUnlock] "

MapLimitUnlock.TARGET_PRODUCTION_LIMIT = 999999
MapLimitUnlock.TARGET_HUSBANDRY_LIMIT = 999999
MapLimitUnlock.TARGET_FILLTYPE_BITS = 15
MapLimitUnlock.TARGET_TREE_LIMIT = 500000
MapLimitUnlock.TARGET_PLACEABLE_LIMIT = 999999

MapLimitUnlock._hooksInstalled = false

local function luLog(msg)
    Logging.info(MapLimitUnlock.LOG_PREFIX .. "%s", tostring(msg))
end

local function setNumericFieldIfExists(tbl, key, newValue)
    if tbl == nil or key == nil then
        return false, nil
    end

    local oldValue = rawget(tbl, key)
    if type(oldValue) == "number" then
        rawset(tbl, key, newValue)
        return true, oldValue
    end

    return false, oldValue
end

function MapLimitUnlock:applyFillTypeLimit()
    if FillTypeManager == nil then
        return
    end

    local old = FillTypeManager.SEND_NUM_BITS
    if type(old) == "number" and old < self.TARGET_FILLTYPE_BITS then
        FillTypeManager.SEND_NUM_BITS = self.TARGET_FILLTYPE_BITS
        luLog(string.format("FillType bits: %s -> %s", tostring(old), tostring(FillTypeManager.SEND_NUM_BITS)))
    else
        luLog(string.format("FillType bits: %s -> %s", tostring(old), tostring(old)))
    end
end

function MapLimitUnlock:applyProductionLimit()
    local old = nil
    if ProductionChainManager ~= nil and type(ProductionChainManager.NUM_MAX_PRODUCTION_POINTS) == "number" then
        old = ProductionChainManager.NUM_MAX_PRODUCTION_POINTS
        if old < self.TARGET_PRODUCTION_LIMIT then
            ProductionChainManager.NUM_MAX_PRODUCTION_POINTS = self.TARGET_PRODUCTION_LIMIT
        end
    end

    luLog(string.format("Production limit: %s -> %s", tostring(old), tostring(ProductionChainManager ~= nil and ProductionChainManager.NUM_MAX_PRODUCTION_POINTS or old)))
end

function MapLimitUnlock:applyPlaceableLimit(mission)
    local ps = mission ~= nil and mission.placeableSystem or nil

    local changed = false
    local old = nil
    if PlaceableSystem ~= nil then
        local keys = {
            "NUM_MAX_PLACEABLES",
            "MAX_NUM_PLACEABLES",
            "MAX_NUM_OF_PLACEABLES"
        }

        for _, key in ipairs(keys) do
            local didSet, previous = setNumericFieldIfExists(PlaceableSystem, key, self.TARGET_PLACEABLE_LIMIT)
            if previous ~= nil and old == nil then
                old = previous
            end
            changed = changed or didSet
        end
    end

    if ps ~= nil then
        local keys = {
            "numMaxPlaceables",
            "maxNumPlaceables"
        }

        for _, key in ipairs(keys) do
            local didSet, previous = setNumericFieldIfExists(ps, key, self.TARGET_PLACEABLE_LIMIT)
            if previous ~= nil and old == nil then
                old = previous
            end
            changed = changed or didSet
        end
    end

    if changed then
        luLog(string.format("Placeable limit: %s -> %s", tostring(old), tostring(self.TARGET_PLACEABLE_LIMIT)))
    else
        luLog("Placeable limit: no explicit Lua hard-cap field found (unchanged)")
    end
end

function MapLimitUnlock:applyHusbandryLimit(mission)
    local hs = mission ~= nil and mission.husbandrySystem or nil
    local old = nil
    local changed = false

    local function applyOne(tbl, key)
        local didSet, previous = setNumericFieldIfExists(tbl, key, self.TARGET_HUSBANDRY_LIMIT)
        if previous ~= nil and old == nil then
            old = previous
        end
        changed = changed or didSet
    end

    if hs ~= nil then
        applyOne(hs, "maxNumHusbandries")
        applyOne(hs, "numMaxHusbandries")
        applyOne(hs, "maxHusbandries")
        applyOne(hs, "husbandryLimit")
    end

    if HusbandrySystem ~= nil then
        applyOne(HusbandrySystem, "MAX_NUM_HUSBANDRIES")
        applyOne(HusbandrySystem, "NUM_MAX_HUSBANDRIES")
    end

    luLog(string.format("Husbandry limit: %s -> %s", tostring(old), tostring(changed and self.TARGET_HUSBANDRY_LIMIT or old)))
end

function MapLimitUnlock:applyTreeLimit(mission)
    local tm = mission ~= nil and mission.treePlantManager or g_treePlantManager
    local old = nil

    if tm ~= nil then
        if type(tm.maxNumTrees) == "number" then
            old = tm.maxNumTrees
            if tm.maxNumTrees < self.TARGET_TREE_LIMIT then
                tm.maxNumTrees = self.TARGET_TREE_LIMIT
            end
        end

        if not tm._limitUnlockCanPlantTreeOverwritten and type(tm.canPlantTree) == "function" then
            tm._limitUnlockCanPlantTreeOverwritten = true
            tm.canPlantTree = function(selfTree)
                local totalNumSplit, numSplit = getNumOfSplitShapes()
                local numUnsplit = totalNumSplit - numSplit
                local maxAllowed = selfTree.maxNumTrees or MapLimitUnlock.TARGET_TREE_LIMIT
                return (numUnsplit + (selfTree.numTreesWithoutSplits or 0)) < maxAllowed
            end
        end
    end

    luLog(string.format("Tree limit: %s -> %s", tostring(old), tostring(tm ~= nil and tm.maxNumTrees or old)))
end

function MapLimitUnlock:applyAll(mission)
    self:applyProductionLimit()
    self:applyPlaceableLimit(mission)
    self:applyHusbandryLimit(mission)
    self:applyTreeLimit(mission)
end

function MapLimitUnlock.installHooks()
    if MapLimitUnlock._hooksInstalled then
        return
    end

    MapLimitUnlock._hooksInstalled = true

    if Mission00 == nil then
        luLog("Mission00 not available, hooks not installed")
        return
    end

    Mission00.loadMap = Utils.prependedFunction(Mission00.loadMap, function(_mission, _mapName)
        MapLimitUnlock:applyFillTypeLimit()
    end)

    Mission00.loadMapFinished = Utils.appendedFunction(Mission00.loadMapFinished, function(mission)
        MapLimitUnlock:applyAll(mission)
    end)

    luLog("hooks installed")
end

MapLimitUnlock.installHooks()
