-- FS25_SvapaAgro/scripts/SvapaFarmlandLinkedPlaceables.lua

SvapaFarmlandLinkedPlaceables = {}
SvapaFarmlandLinkedPlaceables.MOD_NAME = g_currentModName or "FS25_SvapaAgro"

local function FL_log(fmt, ...)
    local msg = string.format(fmt, ...)
    print(string.format("[SvapaFarmlandLinkedPlaceables] %s", msg))
end

-- ---------- helpers

local function isPlaceableBoughtWithFarmland(placeable)
    -- у Placeable есть boughtWithFarmland (из xml) и boughtWithFarmlandSavegameOverwrite (из savegame)
    if placeable == nil then
        return false
    end

    if placeable.boughtWithFarmlandSavegameOverwrite ~= nil then
        return placeable.boughtWithFarmlandSavegameOverwrite == true
    end

    return placeable.boughtWithFarmland == true
end

local function getFarmlandIdOfPlaceable(placeable)
    if placeable ~= nil and placeable.getFarmlandId ~= nil then
        return placeable:getFarmlandId()
    end
    return nil
end

local function moveLinkedPlaceablesOnFarmland(farmlandId, targetFarmId)
    if g_currentMission == nil or g_currentMission.placeableSystem == nil then
        return
    end

    local moved = 0
    for _, p in ipairs(g_currentMission.placeableSystem.placeables) do
        -- Нам нужны только placeables, которые “привязаны к земле”
        if isPlaceableBoughtWithFarmland(p) then
            local pFarmlandId = getFarmlandIdOfPlaceable(p)
            if pFarmlandId == farmlandId then
                if p.setOwnerFarmId ~= nil then
                    -- noEventSend=true чтобы не плодить лишних событий, смена и так произойдёт штатно
                    p:setOwnerFarmId(targetFarmId, true)
                    moved = moved + 1
                end
            end
        end
    end

    if moved > 0 then
        FL_log("Moved %d linked placeables on farmlandId=%d to farmId=%d", moved, farmlandId, targetFarmId)
    end
end

-- ---------- hook candidates (FS25 может отличаться по названиям)

local function hookCanSellFarmland()
    if g_farmlandManager == nil then
        FL_log("g_farmlandManager is nil - can't hook")
        return false
    end

    -- Часто встречающиеся имена “проверки продажи”
    local candidates = {
        "getCanSellFarmland",
        "canSellFarmland",
        "getCanSellLand",
        "canSellLand"
    }

    for _, fnName in ipairs(candidates) do
        local fn = g_farmlandManager[fnName]
        if type(fn) == "function" then
            g_farmlandManager[fnName] = Utils.overwrittenFunction(fn, function(self, superFunc, farmlandId, farmId, ...)
                -- 1) спросим оригинал
                local canSell, reason = superFunc(self, farmlandId, farmId, ...)

                if canSell then
                    return canSell, reason
                end

                -- 2) Если оригинал запрещает из-за “есть объекты на участке”,
                --    то разрешаем, если ВСЕ блокирующие объекты = boughtWithFarmland placeables.
                --    Мы не можем вытащить точную причину без внутренних констант,
                --    поэтому делаем свою проверку по placeables.

                local ownerFarmId = farmId
                if ownerFarmId == nil then
                    ownerFarmId = g_currentMission ~= nil and g_currentMission:getFarmId() or 1
                end

                -- ищем “чужие” для продажи объекты: owned placeables на этой земле, которые НЕ boughtWithFarmland
                local hasHardBlocker = false
                if g_currentMission ~= nil and g_currentMission.placeableSystem ~= nil then
                    for _, p in ipairs(g_currentMission.placeableSystem.placeables) do
                        local pFarmlandId = getFarmlandIdOfPlaceable(p)
                        if pFarmlandId == farmlandId then
                            local pOwner = p.getOwnerFarmId ~= nil and p:getOwnerFarmId() or nil
                            if pOwner == ownerFarmId then
                                if not isPlaceableBoughtWithFarmland(p) then
                                    hasHardBlocker = true
                                    break
                                end
                            end
                        end
                    end
                end

                if not hasHardBlocker then
                    -- разрешаем продажу, если “мешают” только boughtWithFarmland
                    FL_log("%s: overriding sell-check for farmlandId=%d (only boughtWithFarmland placeables)", fnName, farmlandId)
                    return true, nil
                end

                return canSell, reason
            end)

            FL_log("Hooked %s OK", fnName)
            return true
        end
    end

    FL_log("No canSellFarmland-like function found to hook")
    return false
end

local function hookSetLandOwnership()
    if g_farmlandManager == nil then
        return false
    end

    -- В документации Placeable видно, что FarmlandManager имеет setLandOwnership
    local fnName = "setLandOwnership"
    local fn = g_farmlandManager[fnName]
    if type(fn) ~= "function" then
        FL_log("FarmlandManager.%s not found", fnName)
        return false
    end

    g_farmlandManager[fnName] = Utils.overwrittenFunction(fn, function(self, superFunc, farmlandId, newOwnerFarmId, ...)
        local oldOwnerFarmId = self.getFarmlandOwner ~= nil and self:getFarmlandOwner(farmlandId) or nil

        -- Если землю продают в “публичную” (0), заранее уводим linked placeables на 0,
        -- чтобы они не блокировали механику и не оставались привязанными к старой ферме.
        if newOwnerFarmId == FarmManager.SPECTATOR_FARM_ID then
            moveLinkedPlaceablesOnFarmland(farmlandId, FarmManager.SPECTATOR_FARM_ID)
        end

        local ret = { superFunc(self, farmlandId, newOwnerFarmId, ...) }

        -- Если землю купили (owner != 0), возвращаем placeables владельцу
        if newOwnerFarmId ~= FarmManager.SPECTATOR_FARM_ID then
            moveLinkedPlaceablesOnFarmland(farmlandId, newOwnerFarmId)
        else
            -- на всякий случай лог
            if oldOwnerFarmId ~= nil then
                FL_log("FarmlandId=%d owner changed %s -> %s", farmlandId, tostring(oldOwnerFarmId), tostring(newOwnerFarmId))
            end
        end

        return unpack(ret)
    end)

    FL_log("Hooked %s OK", fnName)
    return true
end

-- ---------- entry point

function SvapaFarmlandLinkedPlaceables.loadMap()
    -- хукаем после того как миссия поднялась
    if g_currentMission == nil then
        return
    end

    local ok1 = hookCanSellFarmland()
    local ok2 = hookSetLandOwnership()

    if not ok1 and not ok2 then
        FL_log("No hooks installed - nothing will work")
    else
        FL_log("Loaded OK (hooks: canSell=%s, setLandOwnership=%s)", tostring(ok1), tostring(ok2))
    end
end

addModEventListener(SvapaFarmlandLinkedPlaceables)