-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.







---Specialization for spot spraying of weeds
-- @category Specializations
WeedSpotSpray = {}







---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function WeedSpotSpray.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Sprayer, specializations) and SpecializationUtil.hasSpecialization(PrecisionFarmingStatistic, specializations)
end


---
function WeedSpotSpray.initSpecialization()
    g_vehicleConfigurationManager:addConfigurationType("weedSpotSpray", g_i18n:getText("configuration_weedSpotSpray"), "weedSpotSpray", VehicleConfigurationItem)
end


---
function WeedSpotSpray.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "getIsSpotSprayEnabled", WeedSpotSpray.getIsSpotSprayEnabled)
    SpecializationUtil.registerFunction(vehicleType, "addWeedSpotSpraySensorNodes", WeedSpotSpray.addWeedSpotSpraySensorNodes)
end


---
function WeedSpotSpray.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getSprayerUsage", WeedSpotSpray.getSprayerUsage)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "addExtendedSprayerNozzleEffect", WeedSpotSpray.addExtendedSprayerNozzleEffect)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "updateExtendedSprayerNozzleEffectState", WeedSpotSpray.updateExtendedSprayerNozzleEffectState)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "loadWorkAreaFromXML", WeedSpotSpray.loadWorkAreaFromXML)
end


---
function WeedSpotSpray.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onPreLoad", WeedSpotSpray)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", WeedSpotSpray)
    SpecializationUtil.registerEventListener(vehicleType, "onEndWorkAreaProcessing", WeedSpotSpray)
end


---
function WeedSpotSpray:onPreLoad(savegame)
    local spec = self[WeedSpotSpray.SPEC_TABLE_NAME]

    spec.isEnabled = (self.configurations["weedSpotSpray"] or 1) > 1
end


---
function WeedSpotSpray:onLoad(savegame)
    local spec = self[WeedSpotSpray.SPEC_TABLE_NAME]

    spec.lastRegularUsage = 0

    spec.weedDetectionStates = {}
    local weedSystem = g_currentMission.weedSystem
    local replacementData = weedSystem:getHerbicideReplacements()
    if replacementData.weed ~= nil then
        for sourceState, targetState in pairs(replacementData.weed.replacements) do
            if targetState ~= 0 then -- ignore preventative spraying
                spec.weedDetectionStates[sourceState] = true
            end
        end
    end

    if spec.isEnabled then
        if g_precisionFarming ~= nil then
            local linkData, _ = g_precisionFarming:getSprayerNodeData(self.configFileName, self.configurations)
            if linkData ~= nil then
                self:addWeedSpotSpraySensorNodes(linkData)
            end
        end
    end

    spec.weedMapId, spec.weedFirstChannel, spec.weedNumChannels = g_currentMission.weedSystem:getDensityMapData()
    spec.groundTypeMapId, spec.groundTypeFirstChannel, spec.groundTypeNumChannels = g_currentMission.fieldGroundSystem:getDensityMapData(FieldDensityMap.GROUND_TYPE)
    spec.sprayTypeMapId, spec.sprayTypeFirstChannel, spec.sprayTypeNumChannels = g_currentMission.fieldGroundSystem:getDensityMapData(FieldDensityMap.SPRAY_TYPE)
end


---
function WeedSpotSpray:onEndWorkAreaProcessing(dt)
    local spec = self[WeedSpotSpray.SPEC_TABLE_NAME]

    if self:getLastSpeed() > 0.5 then
        local specSprayer = self.spec_sprayer
        if self.isServer then
            if specSprayer.workAreaParameters.isActive then
                local sprayFillType = specSprayer.workAreaParameters.sprayFillType
                if sprayFillType == FillType.HERBICIDE then
                    local sprayVehicle = specSprayer.workAreaParameters.sprayVehicle
                    local usage = specSprayer.workAreaParameters.usage
                    if sprayVehicle ~= nil or self:getIsAIActive() then
                        self:updatePFStatistic("usedHerbicide", usage)
                        self:updatePFStatistic("usedHerbicideRegular", spec.lastRegularUsage)
                    end
                end
            end
        end
    end
end


---
function WeedSpotSpray:getIsSpotSprayEnabled()
    return self[WeedSpotSpray.SPEC_TABLE_NAME].isEnabled
end


---
function WeedSpotSpray:addWeedSpotSpraySensorNodes(linkData)
    for _, sensorNodeData in pairs(linkData.sensorNodes) do
        local linkNode
        if sensorNodeData.nodeName ~= nil then
            if self.i3dMappings[sensorNodeData.nodeName] ~= nil then
                linkNode = self.i3dMappings[sensorNodeData.nodeName].nodeId
            end
        end

        if linkNode ~= nil then
            local sensorNode, hasBracket = g_precisionFarming:getClonedSprayerWeedSensorNode(sensorNodeData.id)
            if sensorNode ~= nil then
                link(linkNode, sensorNode)
                setTranslation(sensorNode, sensorNodeData.translation[1], sensorNodeData.translation[2], sensorNodeData.translation[3])
                setRotation(sensorNode, sensorNodeData.rotation[1], sensorNodeData.rotation[2], sensorNodeData.rotation[3])

                if hasBracket and sensorNodeData.bracketSize ~= 1 then
                    setScale(getChildAt(sensorNode, 0), 1, sensorNodeData.bracketSize, sensorNodeData.bracketSize)
                end
            end
        end
    end
end


---
function WeedSpotSpray:getSprayerUsage(superFunc, fillType, dt)
    local spec = self[WeedSpotSpray.SPEC_TABLE_NAME]

    local usage = superFunc(self, fillType, dt)
    spec.lastRegularUsage = usage

    if self.getNumExtendedSprayerNozzleEffectsActive ~= nil then
        local _, alpha = self:getNumExtendedSprayerNozzleEffectsActive()
        usage = usage * alpha
    end

    return usage
end


---
function WeedSpotSpray:addExtendedSprayerNozzleEffect(superFunc, effectData, effectNode, linkNode, linkNodeData)
    if not superFunc(self, effectData, effectNode, linkNode, linkNodeData) then
        return false
    end

    return true
end


---
function WeedSpotSpray:updateExtendedSprayerNozzleEffectState(superFunc, effectData, dt, isTurnedOn, lastSpeed)
    local isActive, amountScale = superFunc(self, effectData, dt, isTurnedOn, lastSpeed)

    local spec = self[WeedSpotSpray.SPEC_TABLE_NAME]
    if isActive and spec.isEnabled then
        if self.movingDirection < 0 or (lastSpeed or 0) < 0.25 then
            isActive = false
        end
    end

    if isActive then
        local sprayFillType = self.spec_sprayer.workAreaParameters.sprayFillType
        if sprayFillType == FillType.HERBICIDE then
            if spec.isEnabled then
                local x, y, z = localToWorld(effectData.effectNode, 0, 0, 1)
                local densityBits = getDensityAtWorldPos(spec.weedMapId, x, y, z)
                local weedState = bit32.band(bit32.rshift(densityBits, spec.weedFirstChannel), 2 ^ spec.weedNumChannels - 1)

                if not spec.weedDetectionStates[weedState] then
                    isActive = false
                end
            else
                local x, y, z = localToWorld(effectData.effectNode, 0, 0, 1)
                local densityBitsGround = getDensityAtWorldPos(spec.groundTypeMapId, x, y, z)
                local groundTypeValue = bit32.band(bit32.rshift(densityBitsGround, spec.groundTypeFirstChannel), 2 ^ spec.groundTypeNumChannels - 1)
                local groundType = FieldGroundType.getTypeByValue(groundTypeValue)

                if groundType == FieldGroundType.NONE then
                    isActive = false
                end
            end
        elseif sprayFillType == FillType.LIQUIDFERTILIZER then
            local x, y, z = localToWorld(effectData.effectNode, 0, 0, 1.5)
            local densityBitsGround = getDensityAtWorldPos(spec.groundTypeMapId, x, y, z)
            local groundTypeValue = bit32.band(bit32.rshift(densityBitsGround, spec.groundTypeFirstChannel), 2 ^ spec.groundTypeNumChannels - 1)
            local groundType = FieldGroundType.getTypeByValue(groundTypeValue)

            if groundType == FieldGroundType.NONE then
                isActive = false
            end

            if isActive then
                local densityBitsSpray = densityBitsGround
                if spec.sprayTypeMapId ~= spec.groundTypeMapId then
                    densityBitsSpray = getDensityAtWorldPos(spec.sprayTypeMapId, x, y, z)
                end

                local sprayValue = bit32.band(bit32.rshift(densityBitsSpray, spec.sprayTypeFirstChannel), 2 ^ spec.sprayTypeNumChannels - 1)
                local sprayType = FieldSprayType.getTypeByValue(sprayValue)

                if sprayType == FieldSprayType.FERTILIZER then
                    isActive = false
                end
            end
        end
    end

    return isActive, amountScale
end


---
function WeedSpotSpray:loadWorkAreaFromXML(superFunc, workArea, xmlFile, key)
    if not superFunc(self, workArea, xmlFile, key) then
        return false
    end

    if self[WeedSpotSpray.SPEC_TABLE_NAME].isEnabled then
        workArea.disableBackwards = true -- do not allow backwards spraying as the cameras are in front of the sprayer
    end

    return true
end
