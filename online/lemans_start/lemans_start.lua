---@type ac.GrabbedCamera
local cameraMotion = nil

local sessionWasStarted = nil
local sessionStarting = 0

local waitingPos = vec3(5, 1, 5)
local gettingInCarPos = vec3(0.2, 1, 0)

function script.update(dt)
  if true then return end

  if sim.cameraMode == ac.CameraMode.Start then
    -- no need for that start camera here
    ac.setCurrentCamera(ac.CameraMode.Cockpit)
  end

  if sessionWasStarted ~= sim.isSessionStarted then
    sessionWasStarted = sim.isSessionStarted

    -- grab camera
    if cameraMotion then cameraMotion:dispose() end
    cameraMotion = ac.grabCamera('lemans start')
    if cameraMotion ~= nil then
      cameraMotion.transform.up = vec3(0, 1, 0)
      cameraMotion.fov = 65
    end

    -- stall engine for now
    physics.setCarNoInput(true)
    physics.setEngineRPM(0, 0)
    physics.setEngineStallEnabled(0, true)

    -- hide drivers, open doors
    for i = 0, sim.carsCount - 1 do
      ac.setDriverDoorOpen(i, true)
      ac.setDriverVisible(i, false)
    end

    if sessionWasStarted then
      sessionStarting = 1
    end
  end

  if sessionStarting > 0 then
    sessionStarting = sessionStarting - dt / 3 -- /3 means transition will take 3 seconds

    if cameraMotion then
      local localPos = math.lerp(waitingPos, gettingInCarPos, (1 - sessionStarting) ^ 1.4) -- 1.4 for starting to move slower
      cameraMotion.transform.position = car.transform:transformPoint(localPos)
      cameraMotion.transform.look = -car.transform:transformVector(localPos)

      -- hide the fact that driver model is popping in
      cameraMotion.transform.look.y = cameraMotion.transform.look.y + 2 * math.saturate(1 - math.abs(sessionStarting - 0.2) * 4) ^ 2

      -- slowly transitioning to regular camera
      cameraMotion.ownShare = math.smoothstep(math.lerpInvSat(sessionStarting, 0, 0.5))
    end

    if sessionStarting < 0.2 then
      -- show driver models when camera is tilted up
      for i = 0, sim.carsCount - 1 do
        ac.setDriverVisible(i, true)
      end
    end
    if sessionStarting <= 0 then
      -- close doors
      for i = 0, sim.carsCount - 1 do
        ac.setDriverDoorOpen(i, false)
      end

      -- turn on engine
      physics.setEngineStallEnabled(0, false)
      physics.setCarNoInput(false)
    end
  elseif cameraMotion then
    cameraMotion.transform.position = car.transform:transformPoint(waitingPos)
    cameraMotion.transform.look = car.transform:transformVector(-waitingPos)
  end
end
