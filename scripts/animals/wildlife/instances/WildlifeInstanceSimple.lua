-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.







---
WildlifeInstanceSimple = {}
local WildlifeInstanceSimple_mt = Class(WildlifeInstanceSimple, WildlifeInstance)
















































































---Finds if this instance wants to currently despawn. This will be false if the instance is in the process of despawning.
-- @return boolean canDespawn True if this species has a despawn time range defined, the instance has been alive for long enough, and the instance is not already fleeing; otherwise false.
function WildlifeInstanceSimple:getCanDespawnNow()
    return not self.stateMachine.states.flee.fleeingToDespawn and self.despawnTime ~= nil and self:getSecondsSinceSpawn() >= self.despawnTime
end
