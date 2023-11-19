--[[
  Note: for simple left-right shifts there is a better system:
  https://github.com/ac-custom-shaders-patch/acc-extension-config/wiki/Cars-%E2%80%93-Driver-weight-shift

  This one might be more suited for bikes? Not sure.
]]

local vr = ac.getVR()

-- Storing shift so it could be smoothed out
local shiftingMassX = 0
local shiftingMassZ = 0

function script.update(dt)
  -- Weight offsets: left/right, forwards/backwards
  local offsetX = 0
  local offsetZ = 0

  -- How smooth the transition is
  local lag = 0

  if vr then
    -- If VR present, get offset from VR headset position:
    offsetX = vr.headTransform.position.x * 2
    offsetZ = vr.headTransform.position.z * 2
    lag = 0
  else
    -- Otherwise use gamepad or keyboard buttons:
    if ac.isGamepadButtonPressed(0, ac.GamepadButton.DPadLeft) or ac.isKeyDown(ui.KeyIndex.Left) then
      offsetX = offsetX - 1
    end 
    if ac.isGamepadButtonPressed(0, ac.GamepadButton.DPadRight) or ac.isKeyDown(ui.KeyIndex.Right) then
      offsetX = offsetX + 1
    end
    if ac.isGamepadButtonPressed(0, ac.GamepadButton.DPadUp) or ac.isKeyDown(ui.KeyIndex.Up) then
      offsetZ = offsetZ - 1
    end 
    if ac.isGamepadButtonPressed(0, ac.GamepadButton.DPadDown) or ac.isKeyDown(ui.KeyIndex.Down) then
      offsetZ = offsetZ + 1
    end
    lag = 0.8
  end

  -- Clamping offset to be reasonable:
  offsetX = math.clamp(offsetX, -1, 1)
  offsetZ = math.clamp(offsetZ, -1, 1)

  -- Outputting offsets to Lua Debug app so they could be tracked live (better to remove from public build
  -- to save a bit of time):
  ac.debug('offsetX', offsetX)
  ac.debug('offsetZ', offsetZ)

  -- Computing shifting mass based on offsets (note: I might have messed up signs here,
  -- might need a different value or sign)
  shiftingMassX = math.applyLag(shiftingMassX, offsetX * 50, lag, dt)
  shiftingMassZ = math.applyLag(shiftingMassZ, offsetZ * 50, lag, dt)

  -- Finally, adding four extra weights to the car and altering their mass based on offsets (weights
  -- can’t move but can have their mass changed, and because we don’t want to change the total mass
  -- we’re adding both weight and negative weight on the opposite side):
  ac.setExtraMass(vec3(-1, 0, 0), shiftingMassX)  -- a weight 1 m to the left
  ac.setExtraMass(vec3(1, 0, 0), -shiftingMassX)  -- a weight 1 m to the right with opposite mass
  ac.setExtraMass(vec3(0, 0, -1), shiftingMassZ)  -- a weight 1 m to the back
  ac.setExtraMass(vec3(0, 0, 1), -shiftingMassZ)  -- a weight 1 m to the front with opposite mass
end