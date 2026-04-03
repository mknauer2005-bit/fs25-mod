-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.







---Specialization to track vehicle wear costs
-- @category Specializations
ExtendedWearable = {}




---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function ExtendedWearable.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Wearable, specializations) and SpecializationUtil.hasSpecialization(PrecisionFarmingStatistic, specializations)
end



















---
function ExtendedWearable:onPostUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self[ExtendedWearable.SPEC_TABLE_NAME]

    local damage = self.spec_wearable.damage
    if spec.lastDamage > 0 then
        local price = self:getPrice()
        local lastRepairPrice = Wearable.calculateRepairPrice(price, spec.lastDamage)
        local repairPrice = Wearable.calculateRepairPrice(price, damage)
        local repairCosts = repairPrice - lastRepairPrice
        if repairCosts > 0 then
            local _, isOnField, _ = self:getPFStatisticInfo()
            if isOnField then
                self:updatePFStatistic("vehicleCosts", repairCosts)
            end
        end
    end

    spec.lastDamage = damage
end
