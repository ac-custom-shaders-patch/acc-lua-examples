-- Not doing anything for AIs
if car.isAIControlled then
  return nil
end

local ready = false
local handbrake = 0
local throttle = 0

function script.update(dt)
  local data = ac.accessCarPhysics()

  if not ready then
    data.isEngineStallEnabled = true
    data.rpm = 0
    data.handbrake = 1
    data.clutch = 1
    data.brake = 0
    data.gas = 0
    ac.setMessage('Move your H-shifter to 4th gear', 'This is your handbrake in fully engaged position')

    if data.requestedGearIndex == 5 then
      ac.setMessage('Car is ready to go', 'Use gear-clutch pedal on your left together with handbrake to start moving')
      data.isEngineStallEnabled = false
      ready = true
    end
    return
  end

  local clutchGearPedal = 1 - data.clutch
  local brakePedal = data.gas
  local reversePedal = data.brake
  if ac.isControllerGearUpPressed() then throttle = math.min(throttle + dt * 3, 1) end
  if ac.isControllerGearDownPressed() then throttle = math.max(throttle - dt * 3, 0) end
  handbrake = math.applyLag(handbrake, data.requestedGearIndex == 5 and 1 or data.requestedGearIndex == 4 and 0 or 0.5, 0.9, dt)

  data.isShifterSupported = true
  data.requestedGearIndex = 1
  data.gas = throttle
  data.brake = brakePedal

  local handbrakeReleased = handbrake < 0.01
  data.clutch = math.max(
    handbrakeReleased and math.abs(clutchGearPedal * 2 - 1) or math.max(clutchGearPedal * 2 - 1, 0),
    reversePedal)

  local handbrakeEngagingBrakes = math.lerpInvSat(handbrake, 0.5, 1)
  data.brake = math.lerp(data.brake, 1, handbrakeEngagingBrakes)
  data.clutch = math.lerp(data.clutch, 0, handbrakeEngagingBrakes)

  data.handbrake = math.lerpInvSat(handbrake, 0.5, 1)
  data.requestedGearIndex = reversePedal > 0.2 and 0 or handbrakeReleased and clutchGearPedal < 0.4 and 3 or clutchGearPedal > 0.6 and 2 or 1
end
