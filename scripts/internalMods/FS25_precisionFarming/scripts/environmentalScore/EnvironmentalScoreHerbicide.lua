-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.













---
EnvironmentalScoreHerbicide = {}
local EnvironmentalScoreHerbicide_mt = Class(EnvironmentalScoreHerbicide, EnvironmentalScoreValue)










---
function EnvironmentalScoreHerbicide:loadFromXML(xmlFile, key, baseDirectory, configFileName, mapFilename)
    if not EnvironmentalScoreTillage:superClass().loadFromXML(self, xmlFile, key, baseDirectory, configFileName, mapFilename) then
        return false
    end

    return true
end


---
function EnvironmentalScoreHerbicide:update(dt)
end


---
function EnvironmentalScoreHerbicide:getScore(farmlandId)
    local farmlandData = self:getFarmlandData(farmlandId)

    if farmlandData.clientScore ~= nil then
        return farmlandData.clientScore
    end

    local sum = 0
    for i=1, 3 do
        sum = sum + farmlandData.areaByType[i]
    end

    if sum == 0 then
        return 0.5
    end

    local score = 0
    score = score + (farmlandData.areaByType[EnvironmentalScoreHerbicide.TYPE_SPOT_SPRAY] / sum) * 1
    score = score + (farmlandData.areaByType[EnvironmentalScoreHerbicide.TYPE_FULL_SPRAY] / sum) * 0.6
    score = score + (farmlandData.areaByType[EnvironmentalScoreHerbicide.TYPE_MECHANICAL] / sum) * 0.75

    return math.clamp(score, 0, 1)
end


---
function EnvironmentalScoreHerbicide:initFarmlandData()
    return {
        areaByType = {
            [EnvironmentalScoreHerbicide.TYPE_SPOT_SPRAY] = 0,
            [EnvironmentalScoreHerbicide.TYPE_FULL_SPRAY] = 0,
            [EnvironmentalScoreHerbicide.TYPE_MECHANICAL] = 0,
        },
        pendingReset = false,
    }
end


---
function EnvironmentalScoreHerbicide:loadFarmlandData(data, xmlFile, key)
    data.areaByType[EnvironmentalScoreHerbicide.TYPE_SPOT_SPRAY] = xmlFile:getFloat(key .. "#spotSpray", data.areaByType[EnvironmentalScoreHerbicide.TYPE_SPOT_SPRAY])
    data.areaByType[EnvironmentalScoreHerbicide.TYPE_FULL_SPRAY] = xmlFile:getFloat(key .. "#fullSpray", data.areaByType[EnvironmentalScoreHerbicide.TYPE_FULL_SPRAY])
    data.areaByType[EnvironmentalScoreHerbicide.TYPE_MECHANICAL] = xmlFile:getFloat(key .. "#mechanical", data.areaByType[EnvironmentalScoreHerbicide.TYPE_MECHANICAL])

    data.pendingReset = xmlFile:getBool(key .. "#pendingReset", data.pendingReset)
end


---
function EnvironmentalScoreHerbicide:saveFarmlandData(data, xmlFile, key)
    xmlFile:setFloat(key .. "#spotSpray", data.areaByType[EnvironmentalScoreHerbicide.TYPE_SPOT_SPRAY])
    xmlFile:setFloat(key .. "#fullSpray", data.areaByType[EnvironmentalScoreHerbicide.TYPE_FULL_SPRAY])
    xmlFile:setFloat(key .. "#mechanical", data.areaByType[EnvironmentalScoreHerbicide.TYPE_MECHANICAL])

    xmlFile:setBool(key .. "#pendingReset", data.pendingReset)
end


---
function EnvironmentalScoreHerbicide:readFarmlandDataFromStream(data, streamId, connection)
    local score = MathUtil.round(streamReadUIntN(streamId, 8) / 255, 2)
    data.clientScore = score
end


---
function EnvironmentalScoreHerbicide:writeFarmlandDataToStream(data, streamId, connection)
    local score = self:getScore(data.farmlandId)
    streamWriteUIntN(streamId, score * 255, 8)
end


---
function EnvironmentalScoreHerbicide:onHarvestScoreReset(farmlandId)
    local farmlandData = self:getFarmlandData(farmlandId)
    farmlandData.pendingReset = true
end


---
function EnvironmentalScoreHerbicide:addWorkedArea(farmlandId, area, type)
    local farmlandData = self:getFarmlandData(farmlandId)

    if farmlandData.pendingReset then
        farmlandData.areaByType[EnvironmentalScoreHerbicide.TYPE_SPOT_SPRAY] = 0
        farmlandData.areaByType[EnvironmentalScoreHerbicide.TYPE_FULL_SPRAY] = 0
        farmlandData.areaByType[EnvironmentalScoreHerbicide.TYPE_MECHANICAL] = 0

        farmlandData.pendingReset = false
    end

    farmlandData.areaByType[type] = farmlandData.areaByType[type] + area
end


---
function EnvironmentalScoreHerbicide:overwriteGameFunctions(pfModule)
    if g_server ~= nil then
        pfModule:overwriteGameFunction(Sprayer, "processSprayerArea", function(superFunc, vehicle, workArea, dt)
            local changedArea, totalArea = superFunc(vehicle, workArea, dt)

            if changedArea > 0 then
                if vehicle.spec_sprayer.workAreaParameters.sprayFillType == FillType.HERBICIDE then
                    local x, _, z = getWorldTranslation(vehicle.rootNode)
                    local farmlandId = g_farmlandManager:getFarmlandIdAtWorldPosition(x, z)
                    if farmlandId ~= nil then
                        local spec = vehicle[WeedSpotSpray.SPEC_TABLE_NAME]
                        if vehicle.getIsSpotSprayEnabled ~= nil and vehicle:getIsSpotSprayEnabled() then
                            self:addWorkedArea(farmlandId, changedArea, EnvironmentalScoreHerbicide.TYPE_SPOT_SPRAY)
                        else
                            self:addWorkedArea(farmlandId, changedArea, EnvironmentalScoreHerbicide.TYPE_FULL_SPRAY)
                        end
                    end
                end
            end

            return changedArea, totalArea
        end)

        pfModule:overwriteGameFunction(Weeder, "processWeederArea", function(superFunc, vehicle, workArea, dt)
            local changedArea, totalArea = superFunc(vehicle, workArea, dt)

            if changedArea > 0 then
                local x, _, z = getWorldTranslation(vehicle.rootNode)
                local farmlandId = g_farmlandManager:getFarmlandIdAtWorldPosition(x, z)
                if farmlandId ~= nil then
                    self:addWorkedArea(farmlandId, changedArea, EnvironmentalScoreHerbicide.TYPE_MECHANICAL)
                end
            end

            return changedArea, totalArea
        end)

        -- grass does not need any weed control, so we consider the same score as mechanical weed control
        pfModule:overwriteGameFunction(HarvestExtension, "setLastScoringValues", function(superFunc, harvestExtension, area, farmlandId, nActual, nTarget, pHActual, pHTarget, ignoreOverfertilization, fillTypeIndex)
            superFunc(harvestExtension, area, farmlandId, nActual, nTarget, pHActual, pHTarget, ignoreOverfertilization, fillTypeIndex)

            if fillTypeIndex ~= nil and (fillTypeIndex == FillType.GRASS or fillTypeIndex == FillType.GRASS_WINDROW) and area > 0 and farmlandId ~= nil then
                self:addWorkedArea(farmlandId, area, EnvironmentalScoreHerbicide.TYPE_SPOT_SPRAY)
            end
        end)
    end
end
