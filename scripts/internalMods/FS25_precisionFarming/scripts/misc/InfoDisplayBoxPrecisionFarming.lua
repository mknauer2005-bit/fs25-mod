-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.








---
InfoDisplayBoxPrecisionFarming = {}
local InfoDisplayBoxPrecisionFarming_mt = Class(InfoDisplayBoxPrecisionFarming, InfoDisplayKeyValueBox)


---
function InfoDisplayBoxPrecisionFarming.new(infoDisplay, uiScale)
    local self = InfoDisplayKeyValueBox.new(infoDisplay, uiScale, InfoDisplayBoxPrecisionFarming_mt)

    return self
end
