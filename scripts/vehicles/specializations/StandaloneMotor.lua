-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.














---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function StandaloneMotor.prerequisitesPresent(specializations)
    return true
end


---
function StandaloneMotor.initSpecialization()
    local schema = Vehicle.xmlSchema
    schema:setXMLSpecializationType("StandaloneMotor")

    schema:register(XMLValueType.TIME, "vehicle.standaloneMotor#turnOffDelay", "Time until the motor is turned off after it is not needed anymore", 0)
    schema:register(XMLValueType.FLOAT, "vehicle.standaloneMotor#idleLoad", "Idle load in percentage [0-1]", 0.2)
    schema:register(XMLValueType.FLOAT, "vehicle.standaloneMotor#idleRpm", "Idle rpm in percentage [0-1]", 0.2)
    schema:register(XMLValueType.TIME, "vehicle.standaloneMotor#motorStartDuration", "Time until motor has been started (used for ignitionState dashboard)", 1.5)

    schema:register(XMLValueType.FLOAT, "vehicle.standaloneMotor#foldMinLimit", "Min. fold time to allow the motor to run", 0)
    schema:register(XMLValueType.FLOAT, "vehicle.standaloneMotor#foldMaxLimit", "Max. fold time to allow the motor to run", 1)

    SoundManager.registerSampleXMLPaths(schema, "vehicle.standaloneMotor.sounds", "motor(?)")
    EffectManager.registerEffectXMLPaths(schema, "vehicle.standaloneMotor.effects")
    AnimationManager.registerAnimationNodesXMLPaths(schema, "vehicle.standaloneMotor.animationNodes")

    Dashboard.registerDashboardXMLPaths(schema, "vehicle.standaloneMotor.dashboards", {"operatingTime", "motorTemperature", "motorTemperatureWarning", "ignitionState"})

    schema:register(XMLValueType.BOOL, Dashboard.GROUP_XML_KEY .. "#isMotorRunning", "Is motor running")

    schema:setXMLSpecializationType()
end


---
function StandaloneMotor.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "updateStandaloneMotorTemperature", StandaloneMotor.updateStandaloneMotorTemperature)
    SpecializationUtil.registerFunction(vehicleType, "getNeedsStandaloneMotorRunning", StandaloneMotor.getNeedsStandaloneMotorRunning)
    SpecializationUtil.registerFunction(vehicleType, "getAllowsStandaloneMotorRunning", StandaloneMotor.getAllowsStandaloneMotorRunning)
    SpecializationUtil.registerFunction(vehicleType, "getStandaloneMotorTargetRpm", StandaloneMotor.getStandaloneMotorTargetRpm)
    SpecializationUtil.registerFunction(vehicleType, "getStandaloneMotorLoad", StandaloneMotor.getStandaloneMotorLoad)
end


---
function StandaloneMotor.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsOperating", StandaloneMotor.getIsOperating)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "loadDashboardGroupFromXML", StandaloneMotor.loadDashboardGroupFromXML)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsDashboardGroupActive", StandaloneMotor.getIsDashboardGroupActive)
end


---
function StandaloneMotor.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", StandaloneMotor)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterDashboardValueTypes", StandaloneMotor)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", StandaloneMotor)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", StandaloneMotor)
end


---
function StandaloneMotor:onLoad(savegame)
    local spec = self.spec_standaloneMotor

    spec.turnOffDelay = self.xmlFile:getValue("vehicle.standaloneMotor#turnOffDelay", 0)
    spec.turnOffTimer = spec.turnOffDelay

    spec.idleLoad = self.xmlFile:getValue("vehicle.standaloneMotor#idleLoad", 0.2)
    spec.idleRpm = self.xmlFile:getValue("vehicle.standaloneMotor#idleRpm", 0.2)
    spec.motorStartDuration = self.xmlFile:getValue("vehicle.standaloneMotor#motorStartDuration", 1.5)
    spec.motorStartTime = 0

    spec.foldMinLimit = self.xmlFile:getValue("vehicle.standaloneMotor#foldMinLimit", 0)
    spec.foldMaxLimit = self.xmlFile:getValue("vehicle.standaloneMotor#foldMaxLimit", 1)

    spec.isActive = false
    spec.lastRpm = 0
    spec.lastLoad = 0

    spec.motorTemperature = {}
    spec.motorTemperature.value = 20
    spec.motorTemperature.valueSend = 20
    spec.motorTemperature.valueMax = 120
    spec.motorTemperature.valueMin = 20
    spec.motorTemperature.heatingPerMS = 1.5 / 1000 -- delta °C per ms, at full load

    spec.motorFan = {}
    spec.motorFan.enabled = false
    spec.motorFan.enableTemperature = 95
    spec.motorFan.disableTemperature = 85
    spec.motorFan.coolingPerMS = 3.0 / 1000

    spec.motorSamples = g_soundManager:loadSamplesFromXML(self.xmlFile, "vehicle.standaloneMotor.sounds", "motor", self.baseDirectory, self.components, 0, AudioGroup.VEHICLE, self.i3dMappings, self)
    spec.motorEffects = g_effectManager:loadEffect(self.xmlFile, "vehicle.standaloneMotor.effects", self.components, self, self.i3dMappings)
    spec.animationNodes = g_animationManager:loadAnimations(self.xmlFile, "vehicle.standaloneMotor.animationNodes", self.components, self, self.i3dMappings)
end


---Called on post load to register dashboard value types
function StandaloneMotor:onRegisterDashboardValueTypes()
    local spec = self.spec_standaloneMotor

    local operatingTime = DashboardValueType.new("standaloneMotor", "operatingTime")
    operatingTime:setValue(self, Enterable.getFormattedOperatingTime)
    self:registerDashboardValueType(operatingTime)

    local motorTemperature = DashboardValueType.new("standaloneMotor", "motorTemperature")
    motorTemperature:setValue(spec.motorTemperature, "value")
    motorTemperature:setRange("valueMin", "valueMax")
    self:registerDashboardValueType(motorTemperature)

    local motorTemperatureWarning = DashboardValueType.new("standaloneMotor", "motorTemperatureWarning")
    motorTemperatureWarning:setValue(spec.motorTemperature, function(_, dashboard)
        local motorTemperature = spec.motorTemperature.value
        return motorTemperature > dashboard.warningThresholdMin and motorTemperature < dashboard.warningThresholdMax
    end)
    motorTemperatureWarning:setAdditionalFunctions(Dashboard.warningAttributes)
    self:registerDashboardValueType(motorTemperatureWarning)

    local ignitionState = DashboardValueType.new("standaloneMotor", "ignitionState")
    ignitionState:setValue(self, StandaloneMotor.getMotorIgnitionState)
    ignitionState:setRange(0, 2)
    self:registerDashboardValueType(ignitionState)
end


---
function StandaloneMotor:onDelete()
    local spec = self.spec_standaloneMotor

    g_soundManager:deleteSamples(spec.motorSamples)
    g_effectManager:deleteEffects(spec.motorEffects)
    g_animationManager:deleteAnimations(spec.animationNodes)
end


---
function StandaloneMotor:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_standaloneMotor

    local needsRunning = self:getNeedsStandaloneMotorRunning()
    local allowsRunning = self:getAllowsStandaloneMotorRunning()
    needsRunning = needsRunning and allowsRunning
    if spec.isActive ~= needsRunning then
        if needsRunning then
            spec.isActive = true
            if not g_soundManager:getIsSamplePlaying(spec.motorSamples[1]) then
                g_soundManager:playSamples(spec.motorSamples)
            end

            g_effectManager:startEffects(spec.motorEffects)
            g_animationManager:startAnimations(spec.animationNodes)

            spec.turnOffTimer = spec.turnOffDelay
            spec.motorStartTime = g_time + spec.motorStartDuration
        else
            if not allowsRunning then
                spec.turnOffTimer = 0 -- instant shutdown if the motor is not allowed to run
            else
                spec.turnOffTimer = spec.turnOffTimer - dt
            end

            if spec.turnOffTimer <= 0 then
                spec.isActive = false
                spec.turnOffTimer = 0
                spec.lastRpm = 0
                spec.lastLoad = 0

                g_soundManager:stopSamples(spec.motorSamples)
                g_effectManager:stopEffects(spec.motorEffects)
                g_animationManager:stopAnimations(spec.animationNodes)
            end
        end
    end

    if spec.isActive then
        local targetRpm = spec.idleRpm + self:getStandaloneMotorTargetRpm() * (1-spec.idleRpm)
        spec.lastRpm = spec.lastRpm * 0.975 + targetRpm * 0.025

        local loadFactorSum, numLoadFactors = self:getStandaloneMotorLoad()
        local loadFactor = 0
        if numLoadFactors > 0 then
            loadFactor = loadFactorSum / numLoadFactors
        end

        spec.lastLoad = spec.idleLoad + loadFactor * (1-spec.idleLoad)

        g_soundManager:setSamplesLoopSynthesisParameters(spec.motorSamples, spec.lastRpm, spec.lastLoad)
        g_effectManager:setDensity(spec.motorEffects, spec.lastRpm)

        self:updateStandaloneMotorTemperature(dt)

        self:raiseActive()
    end
end


---
function StandaloneMotor:getNeedsStandaloneMotorRunning()
    return self:getRequiresPower()
end


---
function StandaloneMotor:getAllowsStandaloneMotorRunning()
    if self.getFoldAnimTime ~= nil then
        local spec = self.spec_standaloneMotor
        local time = self:getFoldAnimTime()
        if time < spec.foldMinLimit or time > spec.foldMaxLimit then
            return false
        end
    end

    return true
end


---
function StandaloneMotor:getStandaloneMotorTargetRpm()
    return 0
end


---
function StandaloneMotor:getStandaloneMotorLoad()
    return 0, 0
end


---
function StandaloneMotor:updateStandaloneMotorTemperature(dt)
    local spec = self.spec_standaloneMotor

    local delta = spec.motorTemperature.heatingPerMS * dt
    local factor = (1 + 4 * spec.lastLoad) / 5
    delta = delta * (factor + spec.lastRpm)
    spec.motorTemperature.value = math.min(spec.motorTemperature.valueMax, spec.motorTemperature.value + delta)

    -- cooling per fan
    if spec.motorTemperature.value > spec.motorFan.enableTemperature then
        spec.motorFan.enabled = true
    end
    if spec.motorFan.enabled then
        if spec.motorTemperature.value < spec.motorFan.disableTemperature then
            spec.motorFan.enabled = false
        end
    end
    if spec.motorFan.enabled then
        delta = spec.motorFan.coolingPerMS * dt
        spec.motorTemperature.value = math.max(spec.motorTemperature.valueMin, spec.motorTemperature.value - delta)
    end
end


---Returns if vehicle is operating
-- @return boolean isOperating is operating
function StandaloneMotor:getIsOperating(superFunc)
    return superFunc(self) or self.spec_standaloneMotor.isActive
end


---
function StandaloneMotor:loadDashboardGroupFromXML(superFunc, xmlFile, key, group)
    if not superFunc(self, xmlFile, key, group) then
        return false
    end

    group.isMotorRunning = xmlFile:getValue(key .. "#isMotorRunning")

    return true
end


---
function StandaloneMotor:getIsDashboardGroupActive(superFunc, group)
    if group.isMotorRunning then
        if not self.spec_standaloneMotor.isActive then
            return false
        end
    end

    return superFunc(self, group)
end


---
function StandaloneMotor:updateDebugValues(values)
    if self.isServer then
        local spec = self.spec_standaloneMotor

        local realRpm = 0
        if spec.motorSamples[1] ~= nil then
            if spec.motorSamples[1].isGlsFile then
                realRpm = getSampleLoopSynthesisRPM(spec.motorSamples[1].soundSample, false)
            end
        end

        table.insert(values, {name="RPM", value=string.format("%d%% %drpm", spec.lastRpm * 100, realRpm)})
        table.insert(values, {name="Load", value=string.format("%d%%", spec.lastLoad * 100)})
        table.insert(values, {name="turnOffTimer", value=string.format("%.1f sec", spec.turnOffTimer * 0.001)})
        table.insert(values, {name="temperature", value=string.format("%.1f °C", spec.motorTemperature.value)})
    end
end


---Returns standalone ignition state (Off: 0, Turning on: 1 Turned on: 2)
-- @return boolean isNeutral is neutral
function StandaloneMotor.getMotorIgnitionState(self)
    local spec = self.spec_standaloneMotor
    return spec.isActive and (spec.motorStartTime > g_time and 1 or 2) or 0
end
