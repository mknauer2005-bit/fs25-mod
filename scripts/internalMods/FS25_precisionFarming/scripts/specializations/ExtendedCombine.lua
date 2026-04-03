-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.







---Specialization to toggle minimap zoom while on field
-- @category Specializations
ExtendedCombine = {}












---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function ExtendedCombine.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Combine, specializations)
       and SpecializationUtil.hasSpecialization(PrecisionFarmingStatistic, specializations)
end































---Called on deleting
function ExtendedCombine:onDelete()
    local spec = self[ExtendedCombine.SPEC_TABLE_NAME]
    if spec.hudExtension ~= nil then
        spec.hudExtension:delete()
    end
end


---
function ExtendedCombine:onReadUpdateStream(streamId, timestamp, connection)
    if connection:getIsServer() then
        local spec = self[ExtendedCombine.SPEC_TABLE_NAME]

        if streamReadBool(streamId) then
            spec.lastYieldWeight = streamReadUIntN(streamId, ExtendedCombine.YIELD_NUM_BITS) / 10
            spec.lastYieldPercentage = streamReadUIntN(streamId, ExtendedCombine.YIELD_PCT_NUM_BITS)
            spec.lastYieldPotential = streamReadUIntN(streamId, ExtendedCombine.YIELD_PCT_NUM_BITS)
        end
    end
end


---
function ExtendedCombine:onWriteUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then
        local spec = self[ExtendedCombine.SPEC_TABLE_NAME]

        if streamWriteBool(streamId, bit32.band(dirtyMask, spec.usageValuesDirtyFlag) ~= 0) then
            streamWriteUIntN(streamId, math.min(math.floor(spec.lastYieldWeight * 10), ExtendedCombine.YIELD_MAX_VALUE), ExtendedCombine.YIELD_NUM_BITS)
            streamWriteUIntN(streamId, math.min(math.floor(spec.lastYieldPercentage), ExtendedCombine.YIELD_PCT_MAX_VALUE), ExtendedCombine.YIELD_PCT_NUM_BITS)
            streamWriteUIntN(streamId, math.min(math.floor(spec.lastYieldPotential), ExtendedCombine.YIELD_PCT_MAX_VALUE), ExtendedCombine.YIELD_PCT_NUM_BITS)
        end
    end
end


---
function ExtendedCombine:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self[ExtendedCombine.SPEC_TABLE_NAME]
    if self.isActiveForInputIgnoreSelectionIgnoreAI then
        if spec.hudExtension ~= nil then
            local hud = g_currentMission.hud
            hud:addHelpExtension(spec.hudExtension)
        end
    end
end


---
function ExtendedCombine:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    if self.isClient then
        if self.isActiveForInputIgnoreSelectionIgnoreAI then
            ExtendedCombine.updateMinimapActiveState(self)
        end
    end
end


---
function ExtendedCombine:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    if self.isClient then
        if isActiveForInputIgnoreSelection then
            ExtendedCombine.updateMinimapActiveState(self)
        else
            ExtendedCombine.updateMinimapActiveState(self, false)
        end
    end
end


---
function ExtendedCombine.updateMinimapActiveState(self, forcedState)
    local yieldMap = self:getPFYieldMap()
    if yieldMap ~= nil then

        local isActive = forcedState
        if isActive == nil then
            local _, _, _, isOnField, mission = self:getPFStatisticInfo()
            isActive = isOnField and self.spec_combine.numAttachedCutters > 0 and mission == nil
        end

        yieldMap:setRequireMinimapDisplay(isActive, self, self:getIsSelected())
    end
end


---
function ExtendedCombine:setLastYieldValues(lastYieldWeight, lastYieldPercentage, lastYieldPotential)
    local spec = self[ExtendedCombine.SPEC_TABLE_NAME]
    if lastYieldWeight ~= spec.lastYieldWeight or lastYieldPercentage ~= spec.lastYieldPercentage or lastYieldPotential ~= spec.lastYieldPotential then
        spec.lastYieldWeight = lastYieldWeight
        spec.lastYieldPercentage = lastYieldPercentage
        spec.lastYieldPotential = lastYieldPotential

        self:raiseDirtyFlags(spec.usageValuesDirtyFlag)
    end
end
