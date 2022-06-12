----------------------------------------------------------------------
--[[ Integration settings (edit these first to get thing to work) ]]--
----------------------------------------------------------------------

-- First and most important, size and orientation (use custom not fitting bgColor to make sure display is aligned with texture space and your geometry).

local bgColor = rgbm.new('#62CD05')        -- Background color
local displaySize = vec2(1152, 172)        -- Size of the display in pixels
local displayRotationAngle = 90            -- Optional display rotation: use it if display is not horizontal on the texture
local displayRotationPivot = vec2(86, 86)  -- Pivot relative to display space

-- Then, text layout options, there are two rows of it, each row 20 symbols wide.

local font = 'pixelstack'         -- Main font (“pixelstack” was specially prepared for this script)
local letterSize = vec2(55, 88)   -- Size of each letter (that’s how `display.text()` works)
local offsetX = 24                -- Horizontal offset for everything to simplify positioning
local offsetY = 6                 -- Vertical offset for everything to simplify positioning
local rowHeight = 82              -- Height of each row (display consists of two rows)
local color = rgbm(0, 0, 0, 0.7)  -- Main font color, slightly transparent for more of that ghosting effect

-- After that, if you want to get all things perfectly aligned, search for SETUPME comment and change few things there if needed. Easier to do it in-place.
-- And here are parameters for car meshes and nodes that should move and glow. All are optional, but if you wouldn’t set RPM needle through here, it wouldn’t
-- work with the whole peak values thing.

local rpmNeedleName = 'RPM_NEEDLE'  -- Name of node with RPM needle, the one above the screen
local rpmNeedleOffsetRPM = 70       -- Needle offset (in RPMs for easy tuning)
local rpmNeedleLimitRPM = 8100      -- To stop needle from doing circles
local rpmNeedleMult = 0.0288        -- Needle scale

local warningLEDName = 'LIGHT_1'    -- Name of warning LED (on the left of the screen)
local rpmLEDName = 'LIGHT_2'        -- Name of RPM LED (on the right)

-- Switches. Display uses four of them around the screen. Switch #1 is in top right corner, switch #2 in bottom right corner, switch #3 is in left top corner,
-- switch #4 is in left bottom.

local extraButtonA = 'extraA'  -- Name of extra button (extraA, extraB, extraC, etc.) which would act like switch #3 for switching display layers.
local extraButtonB = 'extraB'
local extraButtonC = 'extraD'
local extraButtonD = 'extraC'



-- Settings for car meshes to act like switches when clicked with mouse (proper VR integration is coming later). Set a regular mesh filter
-- which would list all the clickable meshes (to use complex query with commas or symbols like | or &, as usual, use curly brackets at ends).
-- Also needed: four points and radiuses in car coordinates. Those would be used to determine which button was clicked (in case all of those
-- switches are in the same mesh, which makes sense).

local switchMeshes = '{ geo_switch_base, SWITCH_001, SWITCH_000, SWITCH_002, SWITCH_009 }' -- All meshes with switches that should be clickable
local switch1Position, switch1Radius = vec3(0.231, 0.869, 0.69), 0.02
local switch2Position, switch2Radius = vec3(0.232, 0.838, 0.679), 0.02
local switch3Position, switch3Radius = vec3(0.538, 0.908, 0.67), 0.06
local switch4Position, switch4Radius = vec3(0.532, 0.836, 0.68), 0.02

-- These settings are for switches to move when pressed. Not required, might make sense to save draw calls and join them in a single mesh, but if
-- you want for it to be extra dynamic, set their names and offset to move to when pressed here.

local switch1Name = 'SWITCH_000'
local switch2Name = 'SWITCH_009'
local switch3Name = 'SWITCH_001'
local switch4Name = 'SWITCH_002'
local switchAnimOffset = vec3(0, -0.01, -0.0025)

-- Emissive colors, needle settings.

local warningLEDColor = rgb(100, 10, 1)
local rpmLEDColor = rgb(10, 100, 1)
local rpmNeedleRotationAxis = vec3(0, 0, 1)

-- General script consts.

local slowRefreshPeriod = 0.5
local fastRefreshPeriod = 0.12
local halfPosSeg = 11

---------------------------------------------------------------------------------
--[[ Actual script starts here. Feel free to poke through and modify things. ]]--
---------------------------------------------------------------------------------

-- Nodes and meshes in 3D model: RPM needle and LEDs
local rpmNeedle = ac.findNodes(rpmNeedleName)
local rpmNeedleOriginalMatrix = rpmNeedle:getTransformationRaw()
if rpmNeedleOriginalMatrix ~= nil then
  rpmNeedle:storeCurrentTransformation()
  rpmNeedleOriginalMatrix = rpmNeedleOriginalMatrix:clone()
else
  rpmNeedle = nil
end

local warningLED = ac.findMeshes(warningLEDName)
local rpmLED = ac.findMeshes(rpmLEDName)
warningLED:ensureUniqueMaterials()
rpmLED:ensureUniqueMaterials()

-- Small helper thing for animating switches
local function animatedMovingSwitch(nodeName, moveOffset)
  local s, r = 0, ac.findNodes(nodeName)
  local a, p = s, r:getPosition()
  return function(state, dt)
    s = math.applyLag(s, state and 1 or 0, 0.7, dt)
    if math.abs(a - s) > 0.01 then
      r:setPosition(p + moveOffset * s)
      a = s
    end
  end
end

-- Extra switches
local displayMesh = display.interactiveMesh{ mesh = switchMeshes, resolution = vec2(1, 1) }
local btnSwitch1 = (function (fn) return extraButtonB and car[extraButtonB] or fn() end):bind(
displayMesh.pressed(vec2(0, 0), vec2(1, 1), switch1Position, switch1Radius))
local btnSwitch2 = (function (fn) return extraButtonC and car[extraButtonC] or fn() end):bind(
displayMesh.pressed(vec2(0, 0), vec2(1, 1), switch2Position, switch2Radius))
local btnSwitch3 = (function (fn) return extraButtonA and car[extraButtonA] or fn() end):bind(
displayMesh.pressed(vec2(0, 0), vec2(1, 1), switch3Position, switch3Radius))
local btnSwitch4 = (function (fn) return extraButtonD and car[extraButtonD] or fn() end):bind(
displayMesh.pressed(vec2(0, 0), vec2(1, 1), switch4Position, switch4Radius))

local animSwitch1 = animatedMovingSwitch(switch1Name, switchAnimOffset)
local animSwitch2 = animatedMovingSwitch(switch2Name, switchAnimOffset)
local animSwitch3 = animatedMovingSwitch(switch3Name, switchAnimOffset)
local animSwitch4 = animatedMovingSwitch(switch4Name, switchAnimOffset)

-- User settings (stored between sessions)
local stored = ac.storage{
  activeDisplay = 1,  -- Index of active display (starting with 1)

  -- Display settings:
  peakPRMGate = 3000,
  peakPRMGateOn = true,
  shiftRPM = 7000,
  shiftRPMOn = true,
  barWidth = 0.45,   -- in seconds, at this delta time delta bar is fully filled

  -- Alerts:
  highWaterTemperature = 105,
  highWaterTemperatureOn = true,
  highOilTemperature = 100,
  highOilTemperatureOn = true,
  lowFuelPressure = 10,
  lowFuelPressureOn = true,
  lowOilPressure = 35,
  lowOilPressureOn = true,
  lowBatteryVoltage = 10,
  lowBatteryVoltageOn = true,

  -- Lap time popup:
  lapTimePopup = 8,
  lapTimePopupOn = true,

  -- Peak values:
  peakRPM = 0,
  peakSpeed = 0,
  peakOilPressure = 99.9,
  peakFuelPressure = 99.9,
  peakOilTemperature = 0,
  peakWaterTemperature = 0,
  peakBatteryVoltage = 26
}

local function resetPeak()
  stored.peakRPM = 0
  stored.peakSpeed = 0
  stored.peakOilPressure = 99.9
  stored.peakFuelPressure = 99.9
  stored.peakOilTemperature = 0
  stored.peakWaterTemperature = 0
  stored.peakBatteryVoltage = 26
end

local function getPeak(key) -- returns peak value based on label
  if key == 'WATER' then return math.ceil(stored.peakWaterTemperature) end
  if key == 'SPEED' then return math.floor(stored.peakSpeed) end
  if key == 'OIL T' then return math.ceil(stored.peakOilTemperature) end
  if key == 'OILP' then return string.format('%.1f', stored.peakOilPressure) end
  if key == 'BATT' then return string.format('%.1f', stored.peakBatteryVoltage) end
  if key == 'FUELP' then return string.format('%.1f', math.min(stored.peakFuelPressure, 99.9)) end
  return nil
end

-- AC does not provide certain values, have to calculate them outselves
local fuelPressure = 56.8
local bestLapIndex = 0  -- 0 for no best lap
local prevLapCount = car.lapCount
local showPreviousLapFor = 0

local function updateCustomCarValues(dt)
  -- AC and CSP do not have fuel pressure, but we can estimate it here
  -- TODO: Of course, estimation should be done differently, I just thought of something random
  fuelPressure = math.applyLag(fuelPressure, 50 + car.rpm / 1000, 0.9, dt)

  -- Another value that’s missing is index of best lap. Easy enough to keep track of though
  if car.previousLapTimeMs == car.bestLapTimeMs then  -- if previous lap time matches best lap time
    bestLapIndex = car.lapCount                       -- we found the index of best lap! we want it 1-based, so no need to subtract 1 here
  end

  if car.lapCount ~= prevLapCount then
    showPreviousLapFor, prevLapCount = stored.lapTimePopup, car.lapCount
  elseif showPreviousLapFor > 0 then
    showPreviousLapFor = showPreviousLapFor - dt
  end
end

-- Mirrors original car state, but with slower refresh rate. Also a good place to convert units and do other preprocessing.
local slow = {}
local delaySlow = slowRefreshPeriod
local delayFast = fastRefreshPeriod

local function updateSlow(dt)
  delaySlow = delaySlow + dt
  if delaySlow > slowRefreshPeriod then
    delaySlow = 0
    slow.waterTemperature = math.ceil(car.waterTemperature)
    slow.rpm = math.floor(car.rpm)
    slow.speedKmh = math.floor(car.speedKmh)
    slow.oilTemperature = math.ceil(car.oilTemperature) + 14
    slow.oilPressure = math.ceil(car.oilPressure * 14.5038 * 10) / 10  -- convert from bar to PSI
    slow.batteryVoltage = math.ceil(car.batteryVoltage * 10) / 10
    slow.fuelPressure = math.ceil(fuelPressure * 10) / 10
  end

  delayFast = delayFast + dt
  if delayFast > fastRefreshPeriod then
    delayFast = 0
    slow.lapTimeMs = car.lapTimeMs
    slow.performanceMeter = car.performanceMeter
  end
end

-- Display logic, peak values, corner speeds, etc.
local peakGateTimer = 0 -- once it reaches 1 s, peak values start to update
local warningMsg = nil
local warningType = nil
local ignoredWarning = nil
local lastWarning = nil
local inCornerTimer = 0 -- for display #5 measurements, above zero when car is in a corner
local speedHold = nil   -- display #5: Speed at the moment when Switch 1 was last pressed (HOLD)
local speedMax = 0      -- display #5: Highest speed attained on the previous straight (MAX)
local speedMin = 0      -- display #5: Lowest speed attained in the previous corner (MIN)
local settingsDisplay = 0

local function updateDisplayVariables(dt)
  -- Calculate stuff for display #5. First, need to know if we are in a corner. Going to calculate it
  -- based on car steering. I have no idea how it works in reality.
  if inCornerTimer > 0 or math.abs(car.steer) > 20 then                                   -- if we already in corner or wheel is turned above 20°
    speedMin = inCornerTimer <= 0 and slow.speedKmh or math.min(slow.speedKmh, speedMin)  -- if not in corner before, reset min corner speed to current, otherwise find min value
    inCornerTimer = math.abs(car.steer) < 10 and inCornerTimer - dt or 1                  -- if steering is straight, count down inCornerTimer, otherwise reset to 1 second
  else
    speedMax = inCornerTimer ~= 0 and slow.speedKmh or math.max(slow.speedKmh, speedMax)
    inCornerTimer = 0
  end
  if stored.activeDisplay == 5 and btnSwitch1() then
    speedHold = slow.speedKmh
  end

  if settingsDisplay == 0 and stored.activeDisplay ~= 5 and btnSwitch1() and btnSwitch3() then
    resetPeak()
  end

  -- Update peak values
  if car.rpm < stored.peakPRMGate and stored.peakPRMGateOn then peakGateTimer = 0
  else peakGateTimer = peakGateTimer + dt end
  if peakGateTimer > 1 then
    if slow.rpm > stored.peakRPM then stored.peakRPM = slow.rpm end
    if slow.speedKmh > stored.peakSpeed then stored.peakSpeed = slow.speedKmh end
    if slow.oilPressure < stored.peakOilPressure then stored.peakOilPressure = slow.oilPressure end
    if fuelPressure < stored.peakFuelPressure then stored.peakFuelPressure = fuelPressure end
    if slow.oilTemperature > stored.peakOilTemperature then stored.peakOilTemperature = slow.oilTemperature end
    if slow.waterTemperature > stored.peakWaterTemperature then stored.peakWaterTemperature = slow.waterTemperature end
    if slow.batteryVoltage < stored.peakBatteryVoltage then stored.peakBatteryVoltage = slow.batteryVoltage end
  end

  if peakGateTimer > 1 or warningMsg then
    warningMsg, warningType = nil, nil
    if peakGateTimer > 1 and slow.waterTemperature > stored.highWaterTemperature and stored.highOilTemperatureOn then
      warningMsg, warningType = string.format('!! HIGH WATER %3.0f !!', slow.waterTemperature), 1
    end
    if peakGateTimer > 1 and slow.oilTemperature > stored.highOilTemperature and stored.highOilTemperatureOn then
      warningMsg, warningType = string.format('!! HIGH OIL T %3.0f !!', slow.oilTemperature), 2
    end
    if peakGateTimer > 1 and slow.fuelPressure < stored.lowFuelPressure and stored.lowFuelPressureOn then
      warningMsg, warningType = string.format('!! LOW FUEL P %3.0f !!', slow.fuelPressure), 3
    end
    if peakGateTimer > 1 and slow.batteryVoltage < stored.lowBatteryVoltage and stored.lowBatteryVoltageOn then
      warningMsg, warningType = string.format('!! LOW BATT %5.0f !!', slow.batteryVoltage), 4
    end
  end  
  if warningMsg == nil and slow.oilPressure < stored.lowOilPressure and stored.lowOilPressureOn then
    warningMsg, warningType = string.format('!! LOW OIL P %4.0f !!', slow.oilPressure), 5
  end
  if warningMsg == nil then ignoredWarning = nil
  else lastWarning = warningMsg end
end

-- Smooth interpolation for RPM value, to add needle a bit of weight (especially important with peak RPM value shown, can’t have it jumping around)
local rpmSmooth = ui.SmoothInterpolation(car.rpm, 0.8)  -- reduce second value to make needle faster

local function updateSceneSmooth(dt)
  if rpmNeedle ~= nil then
    local rpmNeedleAngle = math.min(rpmNeedleLimitRPM,
      ((btnSwitch1() and settingsDisplay == 0 and stored.activeDisplay ~= 5 and stored.peakRPM or car.rpm) + rpmNeedleOffsetRPM) * rpmNeedleMult)
    rpmNeedle:getTransformationRaw():set(rpmNeedleOriginalMatrix)
    ac.debug('rpmNeedleAngle', rpmNeedleAngle)
    ac.debug('rpmSmooth(rpmNeedleAngle)', rpmSmooth(rpmNeedleAngle))
    rpmNeedle:rotate(rpmNeedleRotationAxis, math.rad(rpmSmooth(rpmNeedleAngle)))
  end

  animSwitch1(btnSwitch1(), dt)
  animSwitch2(btnSwitch2(), dt)
  animSwitch3(btnSwitch3(), dt)
  animSwitch4(btnSwitch4(), dt)
end

local function updateSceneRare(dt)
  warningLED:setMaterialProperty('ksEmissive', warningMsg and warningType ~= ignoredWarning and warningLEDColor or rgb.colors.black)
  rpmLED:setMaterialProperty('ksEmissive', car.rpm > stored.shiftRPM and stored.shiftRPMOn and rpmLEDColor or rgb.colors.black)
end

-- Helper functions
local function lapTimeToShortString(lapTimeMs, twoSymbolFraction)
  return string.format(twoSymbolFraction and '%05.2f' or '%02.1f', (lapTimeMs / 1000) % 60)
end

local function lapTimeToString(lapTimeMs, twoSymbolFraction)
  return string.format('%2.0f:%05.2f', math.floor(lapTimeMs / 60e3), (lapTimeMs / 1000) % 60)
end

-- General drawing functions
local function drawValue(name, value, posSegX, posSegY, widthSeg)  -- Draws left-aligned label and right-aligned value. Values posSegX, posSegY and widthSeg are in segments
  local pos = vec2(offsetX + posSegX * letterSize.x, offsetY + rowHeight * posSegY)
  if name then 
    display.text{ text = name, pos = pos, letter = letterSize, color = color, font = font } 
  end
  if value then 
    if btnSwitch1() then value = getPeak(name) or value end
    display.text{ text = value, pos = pos, letter = letterSize, color = color, font = font, width = (widthSeg or 9) * letterSize.x, alignment = 1 } 
  end
end

-- Extra optimization, reuse vectors instead of creating new ones in a loop.
-- Note: usually it’s not really necessary, and even here could go without it, but generally in a loop it might
-- be a good idea to reuse vectors. Just be careful to avoid conflicts using the same vector for different roles at once.
local barP1 = vec2()
local barP2 = vec2()
local barU1 = vec2()
local barU2 = vec2(1, 1)

local function drawBar(value, posSegY)
  value = value / stored.barWidth

  -- Uncomment these lines to debug bar alignment
  -- value = car.steer / 200
  -- drawValue('WWWWWWWWWWWWWWWWWWWWWWWWWWW', nil, 0, 0)
  -- drawValue('WWWWWWWWWWWWWWWWWWWWWWWWWWW', nil, 0, 1)

  -- SETUPME: Performance delta bar configuration
  -- Two versions: one uses solid rects to draw elements, another uses extra element in font for perfect alignment and pixel grid

  -- Version #1:
  --[[ local barXOffset = 0  -- horizontal offset
  local barYOffset = 9  -- vertical offset of a bar from its text line, depends on font
  local barHeight = 63  -- height of a bar in pixels, depends on font (change symbols like “+”, “<” and “>” in fourth display to “W” for easy matching)
  local barSpacing = 4  -- space to left and right of each bar element
  local barSubDivs = 5  -- each element would be subdivided into squares each of that side, ideally should somehow match font grid
  local barX = offsetX + letterSize.x * 10 + barXOffset
  local barY = offsetY + posSegY * rowHeight + barYOffset
  for i = 0, 8 do
    local x = math.min(math.floor((math.abs(value) * 9 - i) * barSubDivs) / barSubDivs, 1)
    if x <= 0 then break end
    local p1 = i * letterSize.x + barSpacing
    local p2 = p1 + x * (letterSize.x - barSpacing * 2)
    if value < 0 then p1, p2 = -p2, -p1 end
    ui.drawRectFilled(barP1:set(barX + p1, barY), barP2:set(barX + p2, barY + barHeight), rgbm.colors.black, 1)
  end ]]

  -- Version #2:
  local barFlipOffset = 1  -- optional offset for horizontal flip
  local barOffset1 = 5     -- first offset for element to jump to actual segments
  local barOffset2 = 8     -- second offset to sync segments with text grid
  local barUV1 = 0.92659   -- UV coordinate of the special symbol in font image
  local barUVW = 0.00973   -- UV size of the special symbol in font image
  local barSubDivs = 5     -- each element would be subdivided into squares each of that side, ideally should somehow match font grid
  local barImage = 'pixelstack.png' -- font image with special symbol
  ui.setShadingOffset(0, 0, 0, 0) -- activating special sampling mode
  ui.beginScale()
  local barX = offsetX + letterSize.x * 10
  barP1.y = offsetY + posSegY * rowHeight
  barP2.y = barP1.y + letterSize.y
  for i = 0, 8 do
    local x = math.min(math.floor((math.abs(value) * 9 - i) * barSubDivs) / barSubDivs, 1)
    if x <= 0 then break end
    local pieceW = barOffset1 + x * (letterSize.x - barOffset2)
    barP1.x, barP2.x = barX + i * letterSize.x, barX + i * letterSize.x + pieceW 
    barU1.x, barU2.x = barUV1, barUV1 + barUVW * pieceW / letterSize.x
    ui.drawImage(barImage, barP1, barP2, color, barU1, barU2)
  end
  ui.endPivotScale(barP1:set(math.sign(value), 1), vec2(barX + barFlipOffset, 0))
  ui.resetShadingOffset()
end

-- Page in settings (0 if settings are not active)
local pressedFor = 0
local settingsDisplayInfos = {
  { label = 'Gate RPM', key = 'peakPRMGate', clampMin = 0, clampMax = 99999 },
  { label = 'Shift RPM', key = 'shiftRPM', clampMin = 0, clampMax = 99999 },
  { label = 'High WaterT', key = 'highWaterTemperature', clampMin = 0, clampMax = 999 },
  { label = 'High Oil T', key = 'highOilTemperature', clampMin = 0, clampMax = 999 },
  { label = 'Low Fuel P', key = 'lowFuelPressure', clampMin = 0, clampMax = 99.9, format = '%.1f', stepMult = 0.1 },
  { label = 'Low Oil P', key = 'lowOilPressure', clampMin = 0, clampMax = 99.9, format = '%.1f', stepMult = 0.1 },
  { label = 'Low Batt', key = 'lowBatteryVoltage', clampMin = 0, clampMax = 99.9, format = '%.1f', stepMult = 0.1 },
  { group = 'EDIT POPUP', label = 'Lap Time', key = 'lapTimePopup', clampMin = 0, clampMax = 99.9, format = '%.1f', stepMult = 0.1 },
  { group = 'EDIT SCALE', label = 'Bar Width', key = 'barWidth', clampMin = 0.05, clampMax = 9.99, format = '%.2f s', stepMult = 0.01 },
}
local function drawSettingsDisplay(displayInfo, dt)
  drawValue(displayInfo.group or 'EDIT TEST', nil, 0, 0)

  local currentValue = stored[displayInfo.key]
  local activeKey = displayInfo.key .. 'On'
  local switchable = ac.storageHasKey(stored, activeKey)
  if switchable then
    drawValue(displayInfo.label, displayInfo.format and string.format(displayInfo.format, currentValue) or currentValue, 0, 1, 15)
    drawValue(nil, stored[activeKey] and 'on' or 'off', 0, 1, 19)
  else
    drawValue(displayInfo.label, displayInfo.format and string.format(displayInfo.format, currentValue) or currentValue, 0, 1, 19)
  end

  local delta = (displayInfo.stepMult or 1) * 2 ^ math.clamp(math.floor(pressedFor), 0, 5)
  if btnSwitch1() and btnSwitch2() then
    if pressedFor ~= -1 then 
      pressedFor = -1
      if switchable then stored[activeKey] = not stored[activeKey] end
    end
  elseif pressedFor >= 0 and btnSwitch1() then 
    stored[displayInfo.key] = math.clamp(currentValue - delta, displayInfo.clampMin, displayInfo.clampMax)
    pressedFor = pressedFor + dt * 3 
  elseif pressedFor >= 0 and btnSwitch2() then 
    stored[displayInfo.key] = math.clamp(currentValue + delta, displayInfo.clampMin, displayInfo.clampMax)
    pressedFor = pressedFor + dt * 3 
  else
    pressedFor = 0 
  end
end

-- Display functions
local function display1()
  drawValue('WATER', slow.waterTemperature, 0, 0)
  drawValue('SPEED', slow.speedKmh, 0, 1)
  drawValue('OIL T', slow.oilTemperature, halfPosSeg, 0)
  drawValue('OILP', string.format('%.1f', slow.oilPressure), halfPosSeg, 1)
end

local function display2()
  drawValue('BATT', string.format('%.1f', slow.batteryVoltage), 0, 0, 10)
  drawValue('FUELP', string.format('%.1f', slow.fuelPressure), 0, 1, 10)
  drawValue('OIL T', slow.oilTemperature, halfPosSeg, 0)
  drawValue('OILP', string.format('%.1f', slow.oilPressure), halfPosSeg, 1)
end

local function display3()
  drawValue('LAP No', math.min(car.lapCount, 99), 0, 0)
  drawValue('BEST', bestLapIndex, 0, 1)
  drawValue(nil, lapTimeToString(car.previousLapTimeMs), halfPosSeg, 0)
  drawValue(nil, lapTimeToString(car.bestLapTimeMs), halfPosSeg, 1)
end

local function display4()
  drawValue(nil, lapTimeToString(car.bestLapTimeMs), 0, 0, 8)
  if car.bestLapTimeMs == 0 then
    drawValue(nil, lapTimeToString(slow.lapTimeMs), halfPosSeg, 0, 8)
  else
    drawValue(nil, lapTimeToShortString(slow.lapTimeMs), halfPosSeg - 6, 0, 8)
    drawValue(nil, car.bestLapTimeMs == 0 and '-.--' or lapTimeToShortString(car.bestLapTimeMs + slow.performanceMeter * 1e3, true), halfPosSeg, 0)
  end

  drawValue('-', '>', 0, 1, 10)
  drawValue('<', '+', halfPosSeg - 1, 1, 10)
  drawBar(car.performanceMeter, 1)
end

local function display5()
  drawValue('SPEED', slow.speedKmh, 0, 0)
  drawValue('HOLD', speedHold and math.floor(speedHold) or '-', 0, 1)
  drawValue('MAX', speedMax and math.floor(speedMax) or '-', halfPosSeg, 0)
  drawValue('MIN', speedMin and math.floor(speedMin) or '-', halfPosSeg, 1)
end

-- Let’s collect all displays into a nice list
local displays = { display1, display2, display3, display4, display5 }

-- Switches to true when settings opening buttons are pressed, to go to settings on release
local goingToSettings = false

local function drawActiveDisplay(switchDisplay, dt)
  if settingsDisplay ~= 0 then
    if btnSwitch4() then
      settingsDisplay = 0
      return true
    end
    if switchDisplay then 
      settingsDisplay = settingsDisplay % #settingsDisplayInfos + 1
      return true
    end
    drawSettingsDisplay(settingsDisplayInfos[settingsDisplay], dt)
    return
  end

  if btnSwitch1() and btnSwitch2() then
    -- Information about the display
    if not goingToSettings then
      goingToSettings = true  -- for nice animation on appearing
      return true
    end
    drawValue('STACK 8100', 'V5.20', 0, 0, 20)
    drawValue('ST901273', '17/10/11', 0, 1, 20)
    return
  elseif goingToSettings then
    settingsDisplay = 1
    goingToSettings = false
    return true
  end

  if showPreviousLapFor > 0 then
    drawValue('    LAP', lapTimeToString(car.previousLapTimeMs), 0, 0, 16)
    return
  end

  if warningMsg and warningType ~= ignoredWarning then
    if btnSwitch2() or btnSwitch3() then
      ignoredWarning = warningType
    else
      drawValue(warningMsg, nil, 0, 0)
      return
    end
  end

  if btnSwitch2() then
    drawValue(lastWarning ~= nil and lastWarning or 'NO WARNINGS TO SHOW', nil, 0, 0)
    return
  end

  -- Call function for active display
  if switchDisplay then 
    stored.activeDisplay = stored.activeDisplay % #displays + 1
    return true
  end
  displays[stored.activeDisplay]()
end

-- Previous state of Extra A switch: once it changes, it’ll go to the next display
local prevSwitch3 = btnSwitch3()

-- If above 0 and there is no user input going on, skip a frame
local skipFrames = 0

-- This value is used for fading of rows on display switch, second rowfades in a bit slower
local lagRow = 0

local function drawActualThings(dt)
  -- Draw background using transparent version of bgColor
  bgColor.mult = 0.35
  ui.drawRectFilled(vec2(0, 0), displaySize, bgColor)

  -- Increments activeDisplay each time Extra A is pressed, goes from number of displays (#displays) to 1
  local switchDisplay = false
  if (btnSwitch3() and not btnSwitch1()) ~= prevSwitch3 then 
    switchDisplay = btnSwitch3()
    prevSwitch3 = switchDisplay
  end

  -- Draw display itself with whatever logic it has
  if drawActiveDisplay(switchDisplay, dt) then
    lagRow = 0.3
  end

  if lagRow > 0 then
    lagRow = lagRow - dt
    
    -- Draw rects for lagging lines
    bgColor.mult = math.lerpInvSat(lagRow, 0.1, 0.3)
    ui.drawRectFilled(vec2(0, 0), vec2(displaySize.x, displaySize.y / 2), bgColor)
    bgColor.mult = math.lerpInvSat(lagRow, 0, 0.2)
    ui.drawRectFilled(vec2(0, displaySize.y / 2), vec2(displaySize.x, displaySize.y), bgColor)
  end
end

-- This function will be called each time texture is updating
function script.update(dt)
  -- Skip two frames, draw on third
  local skipThisFrame = skipFrames > 0
  skipFrames = skipThisFrame and skipFrames - 1 or 2

  -- Update scene objects every frame for extra smoothness
  updateSceneSmooth(dt)

  if skipThisFrame then
    -- Not only it helps with performance, but, more importantly, such display feels more display-ish without
    -- smoothest 60 FPS refresh rate
    ac.skipFrame()
    return
  end

  -- Multiplying by 3, becase two out of three frames are skipped
  dt = dt * 3

  -- AC does not provide certain values, have to calculate them outselves
  updateCustomCarValues(dt)

  -- Update other scene objects once every three frames, they’re not as important
  updateSceneRare(dt)

  -- Update things that are meant to update slowly, to reflect slower sampling rate of original display
  updateSlow(dt)

  -- Update display variables: those rely on slowly updated values, so processing should be done with a bit of a delay
  updateDisplayVariables(dt)

  -- To fix orientation, surround `drawActualThings()` with begin/end rotation
  ui.beginRotation()
  drawActualThings(dt)
  ui.endPivotRotation(displayRotationAngle - 90, displayRotationPivot)
end
