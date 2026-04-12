-- StelagClickControl.lua
-- AnimatedObject "Stelag":
-- клик -> старт
-- клик -> стоп
-- клик -> продолжить
-- на краях меняет направление

StelagClickControl = {}
StelagClickControl.DEBUG = true

local function dbg(fmt, ...)
    if StelagClickControl.DEBUG then
        print(string.format("[StelagClickControl] " .. fmt, ...))
    end
end

function StelagClickControl.isTarget(animatedObject)
    if animatedObject == nil then
        return false
    end

    if animatedObject.saveId == "Stelag" then
        return true
    end

    local controls = animatedObject.controls
    if controls ~= nil and controls.posActionText == "action_openStelag" then
        return true
    end

    return false
end

function StelagClickControl.ensureState(animatedObject)
    if animatedObject.stelagClickState == nil then
        animatedObject.stelagClickState = {
            moveDir = 1
        }
    end

    return animatedObject.stelagClickState
end

function StelagClickControl.getNextDirection(animatedObject, state)
    local t = animatedObject.animation.time

    if t <= 0.0001 then
        state.moveDir = 1
        return 1
    end

    if t >= 0.9999 then
        state.moveDir = -1
        return -1
    end

    return state.moveDir
end

function StelagClickControl.applyDirection(animatedObject, direction)
    animatedObject.stelagAllowDirectionChange = true
    animatedObject:setDirection(direction)
    animatedObject.stelagAllowDirectionChange = false
end

-- Блокируем чужие setDirection для Stelag
local oldSetDirection = AnimatedObject.setDirection
function AnimatedObject:setDirection(direction)
    if StelagClickControl.isTarget(self) then
        if not self.stelagAllowDirectionChange then
            dbg("BLOCK external setDirection(%s) time=%.4f currentDir=%d",
                tostring(direction),
                self.animation and self.animation.time or -1,
                self.animation and self.animation.direction or -99)
            return
        end
    end

    return oldSetDirection(self, direction)
end

function StelagClickControl.onClick(self, actionName, inputValue)
    local animatedObject = self.animatedObject
    if animatedObject == nil or animatedObject.animation == nil then
        return
    end

    -- Срабатываем только на нажатие
    if inputValue == 0 then
        return
    end

    local anim = animatedObject.animation
    local state = StelagClickControl.ensureState(animatedObject)

    -- Если сейчас едет -> стоп
    if anim.direction ~= 0 then
        state.moveDir = anim.direction
        dbg("CLICK %s -> STOP at %.4f dir=%d", tostring(actionName), anim.time, anim.direction)
        StelagClickControl.applyDirection(animatedObject, 0)
        return
    end

    -- Если стоит -> поехали
    local dir = StelagClickControl.getNextDirection(animatedObject, state)
    dbg("CLICK %s -> START dir=%d time=%.4f", tostring(actionName), dir, anim.time)
    StelagClickControl.applyDirection(animatedObject, dir)
end

-- Свой input только для Stelag
local oldRegisterCustomInput = AnimatedObjectActivatable.registerCustomInput
function AnimatedObjectActivatable:registerCustomInput(inputContext)
    local animatedObject = self.animatedObject

    if not StelagClickControl.isTarget(animatedObject) then
        return oldRegisterCustomInput(self, inputContext)
    end

    local controls = animatedObject.controls
    if controls == nil or controls.posAction == nil then
        return oldRegisterCustomInput(self, inputContext)
    end

    g_inputBinding:removeActionEventsByTarget(self)
    controls.posActionEventId = nil
    controls.negActionEventId = nil

    local _, eventId = g_inputBinding:registerActionEvent(
        controls.posAction,
        self,
        StelagClickControl.onClick,
        false,
        true,
        false,
        true
    )

    controls.posActionEventId = eventId

    if eventId ~= nil then
        g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_VERY_HIGH)
        g_inputBinding:setActionEventTextVisibility(eventId, true)

        if controls.posActionText ~= nil then
            g_inputBinding:setActionEventText(eventId, controls.posActionText)
        end
    end

    dbg("Custom click input registered for Stelag")
end

-- Глушим ванильный toggle
local oldOnAnimationInputToggle = AnimatedObjectActivatable.onAnimationInputToggle
function AnimatedObjectActivatable:onAnimationInputToggle(...)
    if StelagClickControl.isTarget(self.animatedObject) then
        dbg("Blocked vanilla toggle for Stelag")
        return
    end

    return oldOnAnimationInputToggle(self, ...)
end

-- Обновляем направление на краях
local oldAnimatedObjectUpdate = AnimatedObject.update
function AnimatedObject:update(dt)
    oldAnimatedObjectUpdate(self, dt)

    if not StelagClickControl.isTarget(self) then
        return
    end

    if self.animation == nil then
        return
    end

    local state = StelagClickControl.ensureState(self)
    local t = self.animation.time

    if t <= 0.0001 and self.animation.direction == 0 then
        state.moveDir = 1
    elseif t >= 0.9999 and self.animation.direction == 0 then
        state.moveDir = -1
    end
end