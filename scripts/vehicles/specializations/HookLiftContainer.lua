-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.







---Specialization for hooklift containers to be attached/loaded up on a hooklift trailer
-- @category Specializations
HookLiftContainer = {}


---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function HookLiftContainer.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(AnimatedVehicle, specializations) and SpecializationUtil.hasSpecialization(Attachable, specializations)
end


---Called on specialization initializing
function HookLiftContainer.initSpecialization()
    local schema = Vehicle.xmlSchema
    schema:setXMLSpecializationType("HookLiftContainer")

    schema:register(XMLValueType.BOOL, "vehicle.hookLiftContainer#tiltContainerOnDischarge", "Tilt container on discharge", true)

    schema:register(XMLValueType.NODE_INDEX, "vehicle.hookLiftContainer.visualRollReference#startNode", "Reference nodes that represent the bottom of the container")
    schema:register(XMLValueType.NODE_INDEX, "vehicle.hookLiftContainer.visualRollReference#endNode", "Reference nodes that represent the bottom of the container")

    ObjectChangeUtil.registerObjectChangeXMLPaths(schema, "vehicle.hookLiftContainer.containerLock")

    schema:setXMLSpecializationType()
end


---
function HookLiftContainer.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "onHookLiftContainerLockChanged", HookLiftContainer.onHookLiftContainerLockChanged)
end


---
function HookLiftContainer.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanDischargeToObject", HookLiftContainer.getCanDischargeToObject)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanDischargeToGround", HookLiftContainer.getCanDischargeToGround)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "isDetachAllowed", HookLiftContainer.isDetachAllowed)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "addToPhysics", HookLiftContainer.addToPhysics)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "removeFromPhysics", HookLiftContainer.removeFromPhysics)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getBrakeForce", HookLiftContainer.getBrakeForce)
end


---
function HookLiftContainer.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", HookLiftContainer)
    SpecializationUtil.registerEventListener(vehicleType, "onStartTipping", HookLiftContainer)
    SpecializationUtil.registerEventListener(vehicleType, "onStopTipping", HookLiftContainer)
end


---Called on loading
-- @param table savegame savegame
function HookLiftContainer:onLoad(savegame)
    local spec = self.spec_hookLiftContainer

    spec.tiltContainerOnDischarge = self.xmlFile:getValue("vehicle.hookLiftContainer#tiltContainerOnDischarge", true)

    spec.visualReferenceNodeStart = self.xmlFile:getValue("vehicle.hookLiftContainer.visualRollReference#startNode", nil, self.components, self.i3dMappings)
    spec.visualReferenceNodeEnd = self.xmlFile:getValue("vehicle.hookLiftContainer.visualRollReference#endNode", nil, self.components, self.i3dMappings)

    spec.containerLockChangeObjects = {}
    ObjectChangeUtil.loadObjectChangeFromXML(self.xmlFile, "vehicle.hookLiftContainer.containerLock", spec.containerLockChangeObjects, self.components, self)
    ObjectChangeUtil.setObjectChanges(spec.containerLockChangeObjects, false, self, self.setMovingToolDirty)

    if self.setConnectionHosesActive ~= nil then
        self:setConnectionHosesActive(false)
    end
end


---
function HookLiftContainer:getCanDischargeToObject(superFunc, dischargeNode)
    local attacherVehicle = self:getAttacherVehicle()
    if attacherVehicle ~= nil and attacherVehicle.getIsTippingAllowed ~= nil then
        if not attacherVehicle:getIsTippingAllowed() then
            return false
        end
    end

    return superFunc(self, dischargeNode)
end


---
function HookLiftContainer:getCanDischargeToGround(superFunc, dischargeNode)
    local attacherVehicle = self:getAttacherVehicle()
    if attacherVehicle ~= nil and attacherVehicle.getIsTippingAllowed ~= nil then
        if not attacherVehicle:getIsTippingAllowed() then
            return false
        end
    end

    return superFunc(self, dischargeNode)
end


---
function HookLiftContainer:isDetachAllowed(superFunc)
    local attacherVehicle = self:getAttacherVehicle()
    if attacherVehicle ~= nil and attacherVehicle.getCanDetachContainer ~= nil then
        if not attacherVehicle:getCanDetachContainer() then
            return false, nil
        end
    end

    return superFunc(self)
end


---
function HookLiftContainer:onStartTipping(tipSideIndex)
    local spec = self.spec_hookLiftContainer
    local attacherVehicle = self:getAttacherVehicle()
    if attacherVehicle ~= nil and attacherVehicle.startTipping ~= nil and spec.tiltContainerOnDischarge then
        attacherVehicle:startTipping()
    end
end


---
function HookLiftContainer:onStopTipping()
    local spec = self.spec_hookLiftContainer
    local attacherVehicle = self:getAttacherVehicle()

    if attacherVehicle ~= nil and attacherVehicle.stopTipping ~= nil and spec.tiltContainerOnDischarge then
        attacherVehicle:stopTipping()
    end
end


---
function HookLiftContainer:onHookLiftContainerLockChanged(state)
    local spec = self.spec_hookLiftContainer

    if self.setConnectionHosesActive ~= nil then
        local attacherVehicle = self:getAttacherVehicle()
        local implement = attacherVehicle:getImplementByObject(self)
        if implement ~= nil then
            self:setConnectionHosesActive(state)
        end
    end

    ObjectChangeUtil.setObjectChanges(spec.containerLockChangeObjects, state, self, self.setMovingToolDirty)
end


---
function HookLiftContainer:addToPhysics(superFunc)
    if not superFunc(self) then
        return false
    end

    local attacherVehicle = self:getAttacherVehicle()
    if attacherVehicle ~= nil and attacherVehicle.setHookLiftContainerPhysicsState ~= nil then
        attacherVehicle:setHookLiftContainerPhysicsState(self, true)
    end

    return true
end


---Add to physics
-- @return boolean success success
function HookLiftContainer:removeFromPhysics(superFunc)
    local attacherVehicle = self:getAttacherVehicle()
    if attacherVehicle ~= nil and attacherVehicle.setHookLiftContainerPhysicsState ~= nil then
        attacherVehicle:setHookLiftContainerPhysicsState(self, false)
    end

    if not superFunc(self) then
        return false
    end

    return true
end


---
function HookLiftContainer:getBrakeForce(superFunc)
    if self:getAttacherVehicle() ~= nil then
        return 0
    end

    return superFunc(self)
end
