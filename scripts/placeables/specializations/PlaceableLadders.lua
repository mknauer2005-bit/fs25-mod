-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.






---
PlaceableLadders = {}











---
function PlaceableLadders.registerOverwrittenFunctions(placeableType)
    SpecializationUtil.registerOverwrittenFunction(placeableType, "collectPickObjects", PlaceableLadders.collectPickObjects)
end


































---
function PlaceableLadders:collectPickObjects(superFunc, node)
    local spec = self.spec_ladders

    local foundNode = false
    if spec.ladderTriggers ~= nil then
        for _, ladderTrigger in ipairs(spec.ladderTriggers) do
            if node == ladderTrigger.node then
                foundNode = true
                break
            end
        end
    end

    if not foundNode then
        superFunc(self, node)
    end
end
