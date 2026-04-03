-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.







---Gamepad button display overlay.
-- @category GUI
GlyphButtonOverlay = {}
local GlyphButtonOverlay_mt = Class(GlyphButtonOverlay, ButtonOverlay)


---
-- @param table? customMt
-- @return GlyphButtonOverlay self
function GlyphButtonOverlay.new(customMt)
    local self = ButtonOverlay.new(GlyphButtonOverlay_mt)

    return self
end
