-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.







---
LadderTrigger = {}
local LadderTrigger_mt = Class(LadderTrigger)


---On create ladder trigger
-- @param integer id trigger node id
function LadderTrigger:onCreate(id)
    g_currentMission:addNonUpdateable(LadderTrigger.new(id))
end


---Creating ladder trigger object
-- @param integer node trigger node id
-- @return table instance instance of object
function LadderTrigger.new(node)
    local self = setmetatable({}, LadderTrigger_mt)

    if g_currentMission:getIsClient() then
        self.triggerId = node

        if not CollisionFlag.getHasMaskFlagSet(node, CollisionFlag.PLAYER) then
            Logging.warning("Missing collision mask bit '%d'. Please add this bit to ladder trigger node '%s'", CollisionFlag.getBit(CollisionFlag.PLAYER), I3DUtil.getNodePath(node))
        end

        addTrigger(node, "triggerCallback", self)
    end

    return self
end


---Deleting ladder trigger
function LadderTrigger:delete()
    if self.triggerId ~= nil then
        removeTrigger(self.triggerId)
    end
end


---Trigger callback
-- @param integer triggerId id of trigger
-- @param integer otherId id of actor
-- @param boolean onEnter on enter
-- @param boolean onLeave on leave
-- @param boolean onStay on stay
function LadderTrigger:triggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
    if onEnter or onLeave then
        if g_localPlayer ~= nil and otherId == g_localPlayer.rootNode then
            if onEnter then
                g_localPlayer.mover:setIsOnLadder(true)
            else
                g_localPlayer.mover:setIsOnLadder(false)
            end
        end
    end
end
