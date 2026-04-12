-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.








---Animation value with one or multiple floats for AnimatedVehicle
DashboardValueType = {}
local DashboardValueType_mt = Class(DashboardValueType)


---
function DashboardValueType.new(specName, name, customMt)
    local self = setmetatable({}, customMt or DashboardValueType_mt)

    self.specName = specName
    self.name = name
    self.fullName = specName .. "." .. name

    self.pollUpdate = true

    self.valueObject = nil

    self.loadFunction = nil
    self.stateFunction = nil

    self.valueFactor = 1
    self.valueCompare = nil
    self.idleValue = nil

    self.getSourceValue = self.getDefaultValue
    self.getMinValue = self.getDefaultValue
    self.getMaxValue = self.getDefaultValue
    self.getCenterValue = self.getDefaultValue
    self.getInterpolationSpeed = self.getDefaultValue

    return self
end


---
function DashboardValueType:setXMLKey(xmlKey)
    self.xmlKey = xmlKey
end


---
function DashboardValueType:loadFromXML(xmlFile, vehicle)
    if self.xmlKey ~= nil then
        vehicle:loadDashboardsFromXML(xmlFile, self.xmlKey, self)
    else
        local rootName = xmlFile:getRootName()
        vehicle:loadDashboardsFromXML(xmlFile, rootName .. "." .. self.specName .. ".dashboards", self)
    end
end


---
function DashboardValueType:setPollUpdate(pollUpdate)
    self.pollUpdate = pollUpdate
end


---
function DashboardValueType:setAdditionalFunctions(loadFunction, stateFunction)
    self.loadFunction = loadFunction
    self.stateFunction = stateFunction
end


---
function DashboardValueType:setValueFactor(valueFactor)
    self.valueFactor = valueFactor
end


---
function DashboardValueType:setValueCompare(...)
    self.valueCompare = {}

    for i = 1, select("#", ...) do
        self.valueCompare[select(i, ...)] = true
    end
end


---
function DashboardValueType:setIdleValue(idleValue)
    self.idleValue = idleValue
end


---
function DashboardValueType:setValue(object, func)
    self.valueObject = object
    self:setFunction("getSourceValue", object, func)
end


---
function DashboardValueType:setCenter(centerFunc)
    self:setFunction("getCenterValue", self.valueObject, centerFunc)
end


---
function DashboardValueType:setRange(min, max)
    self:setFunction("getMinValue", self.valueObject, min)
    self:setFunction("getMaxValue", self.valueObject, max)
end


---
function DashboardValueType:setInterpolationSpeed(interpolationSpeed)
    self:setFunction("getInterpolationSpeed", self.valueObject, interpolationSpeed)
end


---
function DashboardValueType:getValue(dashboard)
    local value = self:getSourceValue(dashboard)

    if self.valueCompare ~= nil then
        value = self.valueCompare[value] == true
    end

    local isNumber = type(value) == "number"

    local min, max, center
    if isNumber then
        if self.valueFactor ~= nil then
            value = value * self.valueFactor
        end

        min = self:getMinValue(dashboard)
        max = self:getMaxValue(dashboard)

        center = self:getCenterValue(dashboard)
    end

    return value, min, max, center, isNumber
end


---
function DashboardValueType:setFunction(funcName, object, value)
    local func = nil

    if type(value) == "number" or type(value) == "boolean" then
        func = function(_self)
            return value
        end
    elseif type(value) == "function" then
        func = function(_self, dashboard)
            return value(object, dashboard)
        end
    elseif type(value) == "string" then
        if type(object[value]) == "number" or type(object[value]) == "boolean" then
            func = function(_self)
                return object[value]
            end
        elseif type(object[value]) == "function" then
            func = function(_self, dashboard)
                return object[value](object, dashboard)
            end
        end
    end

    if func ~= nil then
        self[funcName] = func
    end
end



---
function DashboardValueType:getDefaultValue()
    return nil
end
