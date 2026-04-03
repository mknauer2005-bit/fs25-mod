-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.











---
ExtendedWeedControl = {}
local ExtendedWeedControl_mt = Class(ExtendedWeedControl)



















---
function ExtendedWeedControl:loadFromXML(_, _, baseDirectory, configFileName, mapFilename)
    local noiseFilename = Utils.getFilename("shared/weedNoise.grle", ExtendedWeedControl.BASE_DIRECTORY)

    self.noiseBitVectorMap = createBitVectorMap("weedNoise")
    if not loadBitVectorMapFromFile(self.noiseBitVectorMap, noiseFilename, 1) then
        loadBitVectorMapNew(self.noiseBitVectorMap, 4096, 4096, 1, false)

        Logging.error("Failed to load weed noise map from %s", noiseFilename)
        return false
    end

    self.noiseFilter = DensityMapFilter.new(self.noiseBitVectorMap, 0, 1)
    self.noiseFilter:setValueCompareParams(DensityValueCompareType.EQUAL, 0)
end


---
function ExtendedWeedControl:unloadMapData()
    self.noiseFilter = nil
    self.weedFilter = nil

    if self.noiseBitVectorMap ~= nil then
        delete(self.noiseBitVectorMap)
        self.noiseBitVectorMap = nil
    end

    if g_server ~= nil then
        removeConsoleCommand("pfWeedSetNoiseParameters")
    end
end


---
function ExtendedWeedControl:setWeedNoiseParameters(minOctave1, numOctave1, persistence1, minOctave2, numOctave2, persistence2)
    minOctave1, numOctave1, persistence1, minOctave2, numOctave2, persistence2 = tonumber(minOctave1), tonumber(numOctave1), tonumber(persistence1), tonumber(minOctave2), tonumber(numOctave2), tonumber(persistence2)

    self.minOctave1, self.numOctave1, self.persistence1 = minOctave1 or self.minOctave1, numOctave1 or self.numOctave1, persistence1 or self.persistence1
    self.minOctave2, self.numOctave2, self.persistence2 = minOctave2 or self.minOctave2, numOctave2 or self.numOctave2, persistence2 or self.persistence2

    log("Weed Noise Parameters:")
    log(string.format("  minOctave1 %.2f, numOctave1 %.2f, persistence1 %.2f", self.minOctave1, self.numOctave1, self.persistence1))
    log(string.format("  minOctave2 %.2f, numOctave2 %.2f, persistence2 %.2f", self.minOctave2, self.numOctave2, self.persistence2))

    loadBitVectorMapNew(self.noiseBitVectorMap, 4096, 4096, 1, false)

    local modifier = DensityMapModifier.new(self.noiseBitVectorMap, 0, 1, g_terrainNode)

    local perlinNoiseFilter1 = PerlinNoiseFilter.new(self.noiseBitVectorMap, self.minOctave1, self.numOctave1, self.persistence1, math.random(0, 1000))
    local perlinNoiseFilter2 = PerlinNoiseFilter.new(self.noiseBitVectorMap, self.minOctave2, self.numOctave2, self.persistence2, math.random(0, 1000))

    local noiseValues = {}
    table.insert(noiseValues, {0, 750, 0, 9000})
    table.insert(noiseValues, {750, 1500, 0, 5000})
    table.insert(noiseValues, {1500, 2000, 0, 3000})
    table.insert(noiseValues, {2000, 3500, 0, 2000})
    table.insert(noiseValues, {3500, 5000, 0, 1000})
    table.insert(noiseValues, {5000, 10000, 0, 500})

    for _, noiseValue in ipairs(noiseValues) do
        perlinNoiseFilter1:setValueCompareParams(DensityValueCompareType.BETWEEN, noiseValue[1], noiseValue[2])
        perlinNoiseFilter2:setValueCompareParams(DensityValueCompareType.BETWEEN, noiseValue[3], noiseValue[4])
        modifier:executeSet(1, perlinNoiseFilter1, perlinNoiseFilter2)
    end

    local path = getUserProfileAppPath() .. "weedNoise.grle"
    saveBitVectorMapToFile(self.noiseBitVectorMap, path)
    Logging.info("Saved weed noise map to %s", path)
end


---
function ExtendedWeedControl:clearWeedArea(modifier, weedFilter)
    modifier:executeSet(0, self.noiseFilter, weedFilter)
end


---
function ExtendedWeedControl:getWeedModifier()
    if self.weedModifier == nil then
        local weedSystem = g_currentMission.weedSystem
        if weedSystem:getMapHasWeed() then
            local terrainRootNode = g_terrainNode
            local weedMapId, weedFirstChannel, weedNumChannels = weedSystem:getDensityMapData()

            self.weedModifier = DensityMapModifier.new(weedMapId, weedFirstChannel, weedNumChannels, terrainRootNode)

            local weedSparseState = weedSystem:getSparseStartState()
            local weedDenseState = weedSystem:getDenseStartState()

            self.weedFilterDense = DensityMapFilter.new(weedMapId, weedFirstChannel, weedNumChannels)
            self.weedFilterDense:setValueCompareParams(DensityValueCompareType.EQUAL, weedDenseState)

            self.weedFilterSparse = DensityMapFilter.new(weedMapId, weedFirstChannel, weedNumChannels)
            self.weedFilterSparse:setValueCompareParams(DensityValueCompareType.EQUAL, weedSparseState)
        end
    end

    return self.weedModifier
end


---
function ExtendedWeedControl:overwriteGameFunctions(pfModule)

    pfModule:overwriteGameFunction(FSDensityMapUtil, "setSowingWeedArea", function(superFunc, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
        superFunc(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)

        local weedModifier = self:getWeedModifier()
        if weedModifier == nil then
            return
        end

        weedModifier:setParallelogramWorldCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)

        self:clearWeedArea(weedModifier, self.weedFilterDense)
        self:clearWeedArea(weedModifier, self.weedFilterSparse)
    end)

    pfModule:overwriteGameFunction(Sprayer, "processSprayerArea", function(superFunc, vehicle, workArea, dt)
        self.lastUseSpotSpraying = vehicle.getIsSpotSprayEnabled ~= nil and vehicle:getIsSpotSprayEnabled()
        return superFunc(vehicle, workArea, dt)
    end)

    pfModule:overwriteGameFunction(FSDensityMapUtil, "updateHerbicideArea", function(superFunc, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, groundType)
        local allowPreventiveSpraying = self.lastUseSpotSpraying ~= true

        local weedSystem = g_currentMission.weedSystem

        if not weedSystem:getMapHasWeed() then
            return 0, 0
        end

        local functionData = FSDensityMapUtil.functionCache.updateHerbicideArea
        if functionData == nil then
            functionData = {}
            functionData.numChangedPixels = {}
            functionData.totalNumPixels = {}
            functionData.multiModifiers = {}
            functionData.defaultMultiModifiers = {}
            FSDensityMapUtil.functionCache.updateHerbicideArea = functionData
        end

        local labelTotal = "sprayedTotal"
        local labelSprayed = "sprayed"
        local label = labelTotal

        if groundType ~= nil then
            if functionData.multiModifiers[groundType] == nil then
                functionData.multiModifiers[groundType] = {}
            end
        end

        local multiModifier = groundType and functionData.multiModifiers[groundType][allowPreventiveSpraying] or functionData.defaultMultiModifiers[allowPreventiveSpraying]
        if multiModifier == nil then
            multiModifier = DensityMapMultiModifier.new()

            local terrainRootNode = g_terrainNode
            local fieldGroundSystem = g_currentMission.fieldGroundSystem
            local groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.GROUND_TYPE)
            local sprayTypeMapId, sprayTypeFirstChannel, sprayTypeNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.SPRAY_TYPE)
            local weedMapId, weedFirstChannel, weedNumChannels = weedSystem:getDensityMapData()
            local firstSowableValue, lastSowableValue = fieldGroundSystem:getSowableRange()
            local replacementData = weedSystem:getHerbicideReplacements()
            local replacements = replacementData.weed.replacements

            if replacementData.custom ~= nil then
                for _, data in ipairs(replacementData.custom) do
                    local desc = data.fruitType
                    if desc.terrainDataPlaneId ~= nil then
                        local fruitModifier = DensityMapModifier.new(desc.terrainDataPlaneId, desc.startStateChannel, desc.numStateChannels, terrainRootNode)
                        local sourceStateFilter = DensityMapFilter.new(desc.terrainDataPlaneId, desc.startStateChannel, desc.numStateChannels)

                        for sourceState, targetState in pairs(replacements) do
                            sourceStateFilter:setValueCompareParams(DensityValueCompareType.EQUAL, sourceState)
                            multiModifier:addExecuteSetWithStats(label, targetState, fruitModifier, sourceStateFilter)
                            label = labelSprayed
                        end
                    end
                end
            end

            local sprayModifier = DensityMapModifier.new(sprayTypeMapId, sprayTypeFirstChannel, sprayTypeNumChannels, terrainRootNode)
            local weedModifier = DensityMapModifier.new(weedMapId, weedFirstChannel, weedNumChannels, terrainRootNode)
            local groundFilter = DensityMapFilter.new(groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels)
            groundFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, firstSowableValue, lastSowableValue)

            for sourceState, targetState in pairs(replacements) do
                if allowPreventiveSpraying or (sourceState ~= 1 and sourceState ~= 2) then
                    local weedFilter = DensityMapFilter.new(weedMapId, weedFirstChannel, weedNumChannels)
                    weedFilter:setValueCompareParams(DensityValueCompareType.EQUAL, sourceState)

                    for _, desc in pairs(g_fruitTypeManager:getFruitTypes()) do
                        if desc.terrainDataPlaneId ~= nil then
                            local fruitFilter = DensityMapFilter.new(desc.terrainDataPlaneId, desc.startStateChannel, desc.numStateChannels)

                            fruitFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 1, desc.minHarvestingGrowthState - 1)
                            multiModifier:addExecuteSet(groundType, sprayModifier, fruitFilter, weedFilter)
                            multiModifier:addExecuteSetWithStats(label, targetState, weedModifier, fruitFilter, weedFilter)

                            --cut
                            local cutFruitFilter = DensityMapFilter.new(desc.terrainDataPlaneId, desc.startStateChannel, desc.numStateChannels)
                            cutFruitFilter:setValueCompareParams(DensityValueCompareType.EQUAL, desc.cutState+1)
                            multiModifier:addExecuteSet(groundType, sprayModifier, cutFruitFilter, weedFilter)
                            multiModifier:addExecuteSetWithStats(label, targetState, weedModifier, cutFruitFilter, weedFilter)

                            -- destructed state if not equal cut state
                            if desc.wheelDestructionState ~= nil and desc.wheelDestructionState ~= desc.cutState+1 then
                                local wheelDestructionFruitFilter = DensityMapFilter.new(desc.terrainDataPlaneId, desc.startStateChannel, desc.numStateChannels)
                                wheelDestructionFruitFilter:setValueCompareParams(DensityValueCompareType.EQUAL, desc.wheelDestructionState)
                                multiModifier:addExecuteSet(groundType, sprayModifier, wheelDestructionFruitFilter, weedFilter)
                                multiModifier:addExecuteSetWithStats(label, targetState, weedModifier, wheelDestructionFruitFilter, weedFilter)
                            end
                        end
                    end

                    multiModifier:addExecuteSet(groundType, sprayModifier, groundFilter, weedFilter)
                    multiModifier:addExecuteSetWithStats(label, targetState, weedModifier, groundFilter, weedFilter)
                end
            end

            if groundType then
                functionData.multiModifiers[groundType][allowPreventiveSpraying] = multiModifier
            else
                functionData.defaultMultiModifiers[allowPreventiveSpraying] = multiModifier
            end
        end

        local numChangedPixels = functionData.numChangedPixels
        local totalNumPixels = functionData.totalNumPixels

        multiModifier:updateParallelogramWorldCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
        multiModifier:resetStats()
        multiModifier:execute(nil, numChangedPixels, totalNumPixels)

        local area = numChangedPixels[labelTotal] + numChangedPixels[labelSprayed]
        local totalPixels = totalNumPixels[labelTotal] or 0

        return area, totalPixels
    end)

    pfModule:overwriteGameFunction(FieldUpdateTask, "prepare", function(superFunc, _self, ...)
        superFunc(_self, ...)

        if _self.weedState ~= nil then
            local weedModifier = self:getWeedModifier()
            if weedModifier ~= nil then
                _self.multiModifier:addExecuteSet(0, weedModifier, self.noiseFilter)
            end
        end
    end)

    pfModule:overwriteGameFunction(FieldState, "update", function(superFunc, _self, x, z, ...)
        superFunc(_self, x, z, ...)

        local weedSystem = g_currentMission.weedSystem
        if weedSystem:getMapHasWeed() then
            local functionData = self.fieldStateWeedStateData

            if functionData == nil then
                local terrainRootNode = g_terrainNode
                local weedMapId, weedFirstChannel, weedNumChannels = weedSystem:getDensityMapData()
                local factors = weedSystem:getFactors()

                functionData = {}
                functionData.weedModifier = DensityMapModifier.new(weedMapId, weedFirstChannel, weedNumChannels, terrainRootNode)
                functionData.weedStateFilters = {}

                for state, _ in pairs(factors) do
                    local filter = DensityMapFilter.new(weedMapId, weedFirstChannel, weedNumChannels)
                    filter:setValueCompareParams(DensityValueCompareType.EQUAL, state)
                    functionData.weedStateFilters[filter] = state
                end

                self.fieldStateWeedStateData = functionData
            end

            local weedModifier = functionData.weedModifier
            local weedStateFilters = functionData.weedStateFilters

            weedModifier:setParallelogramWorldCoords(x - 10, z - 10, x + 10, z - 10, x - 10, z + 10, DensityCoordType.POINT_POINT_POINT)

            for filter, state in pairs(weedStateFilters) do
                local _, pixels, _ = weedModifier:executeGet(filter)

                if pixels > 0 then
                    _self.weedState = state
                    _self.weedFactor = weedSystem.factors[state] or 0

                    break
                end
            end
        end
    end)
end
