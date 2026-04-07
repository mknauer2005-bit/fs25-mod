FarmlandDropOnPurchase = {}
FarmlandDropOnPurchase.modName = g_currentModName
FarmlandDropOnPurchase.modDirectory = g_currentModDirectory

local FDP_STATIC_MOD_NAME = g_currentModName
local FDP_LOG_PREFIX = "[FarmlandDropOnPurchase]"
local FDP_LOG_ENABLED = true
local FDP_TRACE_UPDATE = false
local unpackFn = table.unpack or unpack

g_farmlandDropOnCreateData = g_farmlandDropOnCreateData or {}

local function fdpLog(stage, message)
    if not FDP_LOG_ENABLED then
        return
    end

    print(string.format("%s[%s] %s", FDP_LOG_PREFIX, tostring(stage or "-"), tostring(message or "")))
end

local function fdpExposeGlobal(name, value)
    _G[name] = value

    local rootEnv = getfenv ~= nil and getfenv(0) or nil
    if rootEnv ~= nil then
        rootEnv[name] = value
    end
end

local function toNumber(value, fallback)
    local n = tonumber(value)
    if n == nil then
        return fallback
    end
    return n
end

local function toBool(value, fallback)
    if value == nil then
        return fallback
    end

    local v = tostring(value):lower()
    if v == "1" or v == "true" or v == "yes" then
        return true
    end

    if v == "0" or v == "false" or v == "no" then
        return false
    end

    return fallback
end

local function collectFallbackEntriesFromScene()
    local collected = {}
    local seen = {}

    if getRootNode == nil then
        fdpLog("fallback", "getRootNode API not available")
        return collected
    end

    local function scanNode(nodeId)
        if nodeId == nil or nodeId == 0 or seen[nodeId] then
            return
        end
        seen[nodeId] = true

        local farmlandId = toNumber(getUserAttribute(nodeId, "farmlandId"), nil)
        if farmlandId ~= nil then
            local entry = {
                nodeId = nodeId,
                farmlandId = farmlandId,
                dropDistance = toNumber(getUserAttribute(nodeId, "dropDistance"), 20),
                includeChildren = toBool(getUserAttribute(nodeId, "includeChildren"), false),
                applyIfOwnedOnLoad = toBool(getUserAttribute(nodeId, "applyIfOwnedOnLoad"), true),
            }

            table.insert(collected, entry)
            fdpLog("fallback", string.format("found nodeId=%s farmlandId=%s", tostring(entry.nodeId), tostring(entry.farmlandId)))
        end

        local childCount = getNumOfChildren(nodeId)
        for i = 0, childCount - 1 do
            scanNode(getChildAt(nodeId, i))
        end
    end

    local rootNode = getRootNode()
    fdpLog("fallback", string.format("scene scan started rootNode=%s", tostring(rootNode)))
    scanNode(rootNode)
    fdpLog("fallback", string.format("scene scan finished entries=%d", #collected))

    return collected
end

function FarmlandDrop_onCreate(nodeId)
    local farmlandId = toNumber(getUserAttribute(nodeId, "farmlandId"), nil)
    local dropDistance = toNumber(getUserAttribute(nodeId, "dropDistance"), 20)
    local includeChildren = toBool(getUserAttribute(nodeId, "includeChildren"), false)
    local applyIfOwnedOnLoad = toBool(getUserAttribute(nodeId, "applyIfOwnedOnLoad"), true)

    fdpLog("onCreate", string.format("called nodeId=%s farmlandId=%s dropDistance=%s includeChildren=%s applyIfOwnedOnLoad=%s", tostring(nodeId), tostring(farmlandId), tostring(dropDistance), tostring(includeChildren), tostring(applyIfOwnedOnLoad)))

    if farmlandId == nil then
        fdpLog("onCreate", string.format("nodeId=%s skipped: missing userAttribute farmlandId", tostring(nodeId)))
        return
    end

    table.insert(g_farmlandDropOnCreateData, {
        nodeId = nodeId,
        farmlandId = farmlandId,
        dropDistance = dropDistance,
        includeChildren = includeChildren,
        applyIfOwnedOnLoad = applyIfOwnedOnLoad,
    })

    fdpLog("onCreate", string.format("queued nodeId=%s; queueSize=%d", tostring(nodeId), #g_farmlandDropOnCreateData))
end

local function registerOnCreateAliases()
    local modName = g_currentModName or FDP_STATIC_MOD_NAME or FarmlandDropOnPurchase.modName

    if modName ~= nil and modName ~= "" then
        _G[modName] = _G[modName] or {}
        _G[modName].FarmlandDrop_onCreate = FarmlandDrop_onCreate
    end

    fdpExposeGlobal("FarmlandDrop_onCreate", FarmlandDrop_onCreate)

    _G["modOnCreate"] = _G["modOnCreate"] or {}
    _G["modOnCreate"].FarmlandDrop_onCreate = FarmlandDrop_onCreate

    local rootEnv = getfenv ~= nil and getfenv(0) or nil
    if rootEnv ~= nil then
        rootEnv.modOnCreate = rootEnv.modOnCreate or {}
        rootEnv.modOnCreate.FarmlandDrop_onCreate = FarmlandDrop_onCreate
    end

    fdpLog("aliases", string.format("registered (modName=%s)", tostring(modName)))
end

registerOnCreateAliases()

local FarmlandDropRuntime = {}
FarmlandDropRuntime.__index = FarmlandDropRuntime

function FarmlandDropRuntime.new()
    local self = setmetatable({}, FarmlandDropRuntime)
    self.entries = {}
    self.checkIntervalMs = 1000
    self.checkTimerMs = 0
    self.initialized = false
    self.updateTicks = 0
    self.unknownOwnerWarned = {}
    self.usePolling = true
    self.hookCount = 0
    return self
end

function FarmlandDropRuntime:processFarmlandOwnershipChanges(reason)
    local appliedCount = 0
    local restoredCount = 0

    for i, entry in ipairs(self.entries) do
        local isOwnedNow = self:isFarmlandOwned(entry.farmlandId)

        if not entry.lastOwned and isOwnedNow then
            fdpLog("ownership", string.format("changed to owned -> applying drop for entry[%d] by %s", i, tostring(reason)))
            self:applyDrop(entry)
            appliedCount = appliedCount + 1
        elseif entry.lastOwned and not isOwnedNow then
            fdpLog("ownership", string.format("changed to unowned -> restoring position for entry[%d] by %s", i, tostring(reason)))
            self:restoreDrop(entry)
            restoredCount = restoredCount + 1
        end

        entry.lastOwned = isOwnedNow
    end

    return appliedCount, restoredCount
end

function FarmlandDropRuntime:onFarmlandOwnershipChanged(reason)
    if not self.initialized then
        return
    end

    local applied, restored = self:processFarmlandOwnershipChanges(reason)
    if applied > 0 or restored > 0 then
        fdpLog("ownership", string.format("applied=%d restored=%d entries after event=%s", applied, restored, tostring(reason)))
    end
end

function FarmlandDropRuntime:installFarmlandHooks()
    if g_farmlandManager == nil then
        fdpLog("hooks", "g_farmlandManager is nil, fallback to polling")
        self.usePolling = true
        return
    end

    local manager = g_farmlandManager
    local wrapped = 0
    local candidates = {
        "buyFarmland",
        "sellFarmland",
        "setFarmlandOwner",
        "setFarmlandOwnerFarmId",
        "setLandOwnership",
        "changeFarmlandState",
    }

    for _, fnName in ipairs(candidates) do
        local original = manager[fnName]
        local marker = "_fdpWrapped_" .. fnName
        if type(original) == "function" and manager[marker] ~= true then
            manager[marker] = true
            manager[fnName] = function(mgr, ...)
                local results = { original(mgr, ...) }
                if g_farmlandDropRuntime ~= nil then
                    g_farmlandDropRuntime:onFarmlandOwnershipChanged("hook:" .. fnName)
                end
                return unpackFn(results)
            end
            wrapped = wrapped + 1
            fdpLog("hooks", string.format("wrapped g_farmlandManager.%s", fnName))
        end
    end

    self.hookCount = wrapped
    self.usePolling = wrapped == 0
    fdpLog("hooks", string.format("hookCount=%d usePolling=%s", wrapped, tostring(self.usePolling)))
end

function FarmlandDropRuntime:getFarmlandOwnerFarmId(farmlandId, farmland)
    if farmland == nil then
        return nil
    end

    if farmland.getOwnerFarmId ~= nil then
        local owner = farmland:getOwnerFarmId()
        if owner ~= nil then
            return owner
        end
    end

    if farmland.ownerFarmId ~= nil then
        return farmland.ownerFarmId
    end

    if farmland.farmId ~= nil then
        return farmland.farmId
    end

    if farmland.ownerFarm ~= nil and farmland.ownerFarm.farmId ~= nil then
        return farmland.ownerFarm.farmId
    end

    if g_farmlandManager ~= nil and g_farmlandManager.getFarmlandOwnerId ~= nil then
        local owner = g_farmlandManager:getFarmlandOwnerId(farmlandId)
        if owner ~= nil then
            return owner
        end
    end

    return nil
end

function FarmlandDropRuntime:isFarmlandOwned(farmlandId)
    if g_farmlandManager == nil or farmlandId == nil then
        fdpLog("isOwned", string.format("farmlandId=%s => false (manager nil or id nil)", tostring(farmlandId)))
        return false
    end

    local farmland = g_farmlandManager:getFarmlandById(farmlandId)
    if farmland == nil then
        fdpLog("isOwned", string.format("farmlandId=%s => false (no such farmland)", tostring(farmlandId)))
        return false
    end

    local ownerFarmId = self:getFarmlandOwnerFarmId(farmlandId, farmland)
    local owned = false

    if ownerFarmId ~= nil then
        owned = ownerFarmId ~= 0
    elseif farmland.isOwned ~= nil then
        owned = farmland.isOwned == true
    end

    if ownerFarmId == nil and self.unknownOwnerWarned[farmlandId] ~= true then
        self.unknownOwnerWarned[farmlandId] = true
        fdpLog("isOwned", string.format("warning: farmlandId=%s owner id unresolved; fallback isOwned=%s", tostring(farmlandId), tostring(farmland.isOwned)))
    end

    fdpLog("isOwned", string.format("farmlandId=%s ownerFarmId=%s owned=%s", tostring(farmlandId), tostring(ownerFarmId), tostring(owned)))
    return owned
end

function FarmlandDropRuntime:dropNode(nodeId, dropDistance)
    if nodeId == nil or nodeId == 0 then
        fdpLog("dropNode", "skip: nodeId nil/0")
        return
    end

    local x, y, z = getTranslation(nodeId)
    setTranslation(nodeId, x, y - dropDistance, z)
    fdpLog("dropNode", string.format("nodeId=%s moved Y %.3f -> %.3f", tostring(nodeId), y, y - dropDistance))
end

function FarmlandDropRuntime:rememberOriginalTransform(entry, nodeId)
    if entry == nil or nodeId == nil or nodeId == 0 then
        return
    end

    entry.originalTransforms = entry.originalTransforms or {}
    if entry.originalTransforms[nodeId] ~= nil then
        return
    end

    local x, y, z = getTranslation(nodeId)
    entry.originalTransforms[nodeId] = { x = x, y = y, z = z }
    fdpLog("transform", string.format("remembered nodeId=%s at (%.3f, %.3f, %.3f)", tostring(nodeId), x, y, z))
end

function FarmlandDropRuntime:restoreNode(entry, nodeId)
    if entry == nil or nodeId == nil or nodeId == 0 or entry.originalTransforms == nil then
        return
    end

    local original = entry.originalTransforms[nodeId]
    if original == nil then
        fdpLog("restoreNode", string.format("skip: missing original transform for nodeId=%s", tostring(nodeId)))
        return
    end

    setTranslation(nodeId, original.x, original.y, original.z)
    fdpLog("restoreNode", string.format("nodeId=%s restored to (%.3f, %.3f, %.3f)", tostring(nodeId), original.x, original.y, original.z))
end

function FarmlandDropRuntime:applyDrop(entry)
    if entry == nil then
        fdpLog("applyDrop", "skip: entry nil")
        return
    end

    if entry.applied then
        fdpLog("applyDrop", string.format("skip: already applied nodeId=%s farmlandId=%s", tostring(entry.nodeId), tostring(entry.farmlandId)))
        return
    end

    fdpLog("applyDrop", string.format("start nodeId=%s farmlandId=%s includeChildren=%s dropDistance=%.3f", tostring(entry.nodeId), tostring(entry.farmlandId), tostring(entry.includeChildren), entry.dropDistance))

    if entry.includeChildren then
        local childCount = getNumOfChildren(entry.nodeId)
        fdpLog("applyDrop", string.format("nodeId=%s children=%d", tostring(entry.nodeId), childCount))
        for i = 0, childCount - 1 do
            local child = getChildAt(entry.nodeId, i)
            self:rememberOriginalTransform(entry, child)
            self:dropNode(child, entry.dropDistance)
        end
    else
        self:rememberOriginalTransform(entry, entry.nodeId)
        self:dropNode(entry.nodeId, entry.dropDistance)
    end

    entry.applied = true
    fdpLog("applyDrop", string.format("done nodeId=%s farmlandId=%s", tostring(entry.nodeId), tostring(entry.farmlandId)))
end

function FarmlandDropRuntime:restoreDrop(entry)
    if entry == nil then
        fdpLog("restoreDrop", "skip: entry nil")
        return
    end

    if not entry.applied then
        fdpLog("restoreDrop", string.format("skip: not applied nodeId=%s farmlandId=%s", tostring(entry.nodeId), tostring(entry.farmlandId)))
        return
    end

    fdpLog("restoreDrop", string.format("start nodeId=%s farmlandId=%s includeChildren=%s", tostring(entry.nodeId), tostring(entry.farmlandId), tostring(entry.includeChildren)))

    if entry.includeChildren then
        local childCount = getNumOfChildren(entry.nodeId)
        for i = 0, childCount - 1 do
            local child = getChildAt(entry.nodeId, i)
            self:restoreNode(entry, child)
        end
    else
        self:restoreNode(entry, entry.nodeId)
    end

    entry.applied = false
    fdpLog("restoreDrop", string.format("done nodeId=%s farmlandId=%s", tostring(entry.nodeId), tostring(entry.farmlandId)))
end

function FarmlandDropRuntime:loadMap(mapName)
    registerOnCreateAliases()

    fdpLog("loadMap", string.format("start mapName=%s queuedOnCreate=%d", tostring(mapName), #g_farmlandDropOnCreateData))

    self.entries = {}

    if #g_farmlandDropOnCreateData == 0 then
        fdpLog("loadMap", "warning: onCreate queue is empty, trying fallback scene scan by userAttribute farmlandId")
        local fallbackEntries = collectFallbackEntriesFromScene()
        for _, fallback in ipairs(fallbackEntries) do
            table.insert(g_farmlandDropOnCreateData, fallback)
        end
        fdpLog("loadMap", string.format("fallback appended entries=%d totalQueued=%d", #fallbackEntries, #g_farmlandDropOnCreateData))
    end

    for idx, data in ipairs(g_farmlandDropOnCreateData) do
        fdpLog("loadMap", string.format("queue[%d]: nodeId=%s farmlandId=%s dropDistance=%.3f includeChildren=%s applyIfOwnedOnLoad=%s", idx, tostring(data.nodeId), tostring(data.farmlandId), data.dropDistance, tostring(data.includeChildren), tostring(data.applyIfOwnedOnLoad)))

        local isOwnedNow = self:isFarmlandOwned(data.farmlandId)

        local entry = {
            nodeId = data.nodeId,
            farmlandId = data.farmlandId,
            dropDistance = data.dropDistance,
            includeChildren = data.includeChildren,
            applyIfOwnedOnLoad = data.applyIfOwnedOnLoad,
            lastOwned = isOwnedNow,
            applied = false,
            originalTransforms = {},
        }

        if isOwnedNow and entry.applyIfOwnedOnLoad then
            fdpLog("loadMap", string.format("farmland already owned -> apply immediately nodeId=%s farmlandId=%s", tostring(entry.nodeId), tostring(entry.farmlandId)))
            self:applyDrop(entry)
        end

        table.insert(self.entries, entry)
    end

    self.checkTimerMs = 0
    self.updateTicks = 0
    self.initialized = true
    self:installFarmlandHooks()
    self:onFarmlandOwnershipChanged("loadMapInit")
    fdpLog("loadMap", string.format("done entries=%d", #self.entries))
end

function FarmlandDropRuntime:update(dt)
    self.updateTicks = self.updateTicks + 1

    if not self.initialized then
        return
    end

    if not self.usePolling then
        return
    end

    self.checkTimerMs = self.checkTimerMs + dt
    if self.checkTimerMs < self.checkIntervalMs then
        return
    end

    self.checkTimerMs = 0
    fdpLog("update", string.format("polling farmland ownership fallback (entries=%d)", #self.entries))
    self:processFarmlandOwnershipChanges("polling")
end

function FarmlandDropRuntime:deleteMap()
    fdpLog("deleteMap", string.format("entriesBeforeClear=%d", #self.entries))
    self.entries = {}
    self.initialized = false
    self.checkTimerMs = 0
    self.updateTicks = 0
    g_farmlandDropOnCreateData = {}
end

if g_farmlandDropRuntime == nil then
    g_farmlandDropRuntime = FarmlandDropRuntime.new()
    addModEventListener(g_farmlandDropRuntime)
    fdpLog("runtime", "listener added")
else
    fdpLog("runtime", "listener already exists")
end
