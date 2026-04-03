-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.












---
ThreePartOverlay = {}
local ThreePartOverlay_mt = Class(ThreePartOverlay)


---
function ThreePartOverlay.new(custom_mt)
    local self = setmetatable({}, custom_mt or ThreePartOverlay_mt)

    self.dirX = 1
    self.dirY = 0

    return self
end
