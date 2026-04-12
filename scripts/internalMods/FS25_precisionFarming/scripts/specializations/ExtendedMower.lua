-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.







---Specialization to toggle minimap zoom while on field
-- @category Specializations
ExtendedMower = {}


---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function ExtendedMower.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Mower, specializations)
       and SpecializationUtil.hasSpecialization(PrecisionFarmingStatistic, specializations)
end














---
function ExtendedMower:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    if self.isClient then
        if self.isActiveForInputIgnoreSelectionIgnoreAI then
            ExtendedMower.updateMinimapActiveState(self)
        end
    end
end


---
function ExtendedMower:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    if self.isClient then
        if isActiveForInputIgnoreSelection then
            ExtendedMower.updateMinimapActiveState(self)
        else
            ExtendedMower.updateMinimapActiveState(self, false)
        end
    end
end


---
function ExtendedMower.updateMinimapActiveState(self, forcedState)
    local yieldMap = self:getPFYieldMap()

    local isActive = forcedState
    if isActive == nil then
        local _, _, _, isOnField = self:getPFStatisticInfo()
        isActive = isOnField
    end

    yieldMap:setRequireMinimapDisplay(isActive, self, self:getIsSelected())
end


---
function ExtendedMower:processMowerArea(superFunc, workArea, dt)
    if not self.isServer and self.currentUpdateDistance > Mower.CLIENT_DM_UPDATE_RADIUS then
        return superFunc(self, workArea, dt)
    end

    if g_precisionFarming ~= nil then
        g_precisionFarming.harvestExtension:preProcessMowerArea(self, workArea, dt)
    end

    local lastChangedArea, lastTotalArea = superFunc(self, workArea, dt)

    if g_precisionFarming ~= nil then
        g_precisionFarming.harvestExtension:postProcessMowerArea(self, workArea, dt, lastChangedArea)
    end

    return lastChangedArea, lastTotalArea
end
