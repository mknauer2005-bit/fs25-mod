-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.







---
-- @category debug
DebugShapeOutline = {}
local DebugShapeOutline_mt = Class(DebugShapeOutline, DebugElement)













---draw
function DebugShapeOutline:draw()
    DebugShapeOutline.render(
        self.node,
        self.recursive
    )
end
