-- A simple script allowing admin to teleport people around with a bunch of comments.
-- Please feel free to use it as an example for something more complex.

-- It might be a good idea generally to keep reference to sim state nearby. Not that it’s that
-- important for opmitization, but it helps a tiny bit and makes code nicer:
local sim = ac.getSim()

-- The way it would work is by using `ac.OnlineEvent`. Remember: online scripts ran on clients,
-- not knowing what other scripts are up to. This is a simple way to allow them to exchange
-- messages.
-- • At “backend” it uses certain hidden chat messages to exchange data. Might look a bit messy
--   if somebody would to join without CSP, although even then messages would not be that visible.
--   And with custom AC server implementations a more direct and optimized way might be used. But
--   in any way, don’t spam those events too much.
-- • When defining online event like this, you need to specify its data layout (what fields it would
--   have and what types those fields are). Generally it’s a good idea to keep types smaller where
--   possible, but for smaller data packets it doesn’t really matter that much.
-- • Second parameter is a function which will be ran when this client receives an event. Also,
--   important thing to note: currently events work in broadcasting manner, if sent, everybody
--   receives it.
-- • Created `ac.OnlineEvent()` acts like a function. Simply call it and fill out the table with data
--   to send out the message.
-- • It’s important to keep data layout the same between all clients. This is how ID of an event
--   is generated.
local jumpEvent = ac.OnlineEvent({
  key = ac.StructItem.key('jumpSomewhere'),  -- to make sure there would be no collisions with other events, it’s a good idea to use a unique key
  targetSessionID = ac.StructItem.int32(),   -- since messages are broadcasted to everybody, we need to specify who we mean
  targetPosition = ac.StructItem.vec3(),     -- 3-dimensional vector for target position
  targetDirection = ac.StructItem.vec3()     -- 3-dimensional vector for target orientation
}, function (sender, message)
  -- This is the function that will be called when this client receives an event message. First argument,
  -- `sender`, points to `ac.StateCar` of the sender or set to `nil` if message has come from server. Second
  -- argument is the message itself.
  if message.targetSessionID == ac.getCar(0).sessionID then
    -- Note: online, each car has two identifiers. One is its regular index, the one that’s always 0 for current player. First car
    -- is always player’s car. Second is `sessionID`: that is the index in online entry list. So, while first-ID-car-index will
    -- vary for the same cars on different clients, `sessionID` is always synced. That line above this comment simply makes sure
    -- `targetSessionID` from the message matches with `sessionID` for player’s car.

    -- And this is where movement occurs. Notice that we’re moving player’s car. Online, there is absolutely no point in moving
    -- anything else: physics for remote cars runs on their corresponding PCs and there is no way we can affect it directly.
    physics.setCarPosition(0, message.targetPosition, message.targetDirection)
  end
end)

-- This is all for “client” side of things, now let’s add some UI to be able to be able to emit that event message and
-- pick a car and a destination point. For that, we’ll use `ui.registerOnlineExtra()` function. Usually online scripts
-- are UI-less: you can create HUD, but without many interactive elements (unless you’d track mouse coordinates and state
-- manually). But with `ui.registerOnlineExtra()` you can create new items in lightbulb section or admin section of
-- the new chat app.

-- First, let’s define some variables related to HUD state. Here is selected car:
local selectedCar = nil ---@type ac.StateCar

-- And selected destination, relative to map.png, 0…1 range
local teleportPoint = vec2(0.5, 0.5)

-- And let’s load some info about track map. That’s where it’s image is:
local mapFilename = ac.getFolder(ac.FolderID.ContentTracks)..'/'..ac.getTrackFullID('/')..'/map.png'

-- This is how its parameters can be read. Just load `ac.INIConfig` and map it into a simple and neat table.
-- It would even have full documentation support with that VSCode plugin:
local mapParams = ac.INIConfig.load(ac.getFolder(ac.FolderID.ContentTracks)..'/'..ac.getTrackFullID('/')..'/data/map.ini'):mapSection('PARAMETERS', {
  X_OFFSET = 0,  -- by providing default values script also specifies type, so that values can be parsed properly
  Z_OFFSET = 0,
  WIDTH = 600,
  HEIGHT = 600
})

-- And last, size of the map. We could calculate it each frame, but it’s nicer if done this way:
local mapSize = vec2(mapParams.WIDTH / mapParams.HEIGHT * 200, 200)

-- A simple helper function which would take a 2-dimensional vector relative to map.png and turn it into world coordinates:
local function getWorldPosFromRelativePos(relativePos)
  -- Doing X and Z is not a problem, but vertical Y axis is a bit trickier. Set it to 0 for now:
  local ret = vec3(relativePos.x * mapParams.WIDTH - mapParams.X_OFFSET, 0, relativePos.y * mapParams.HEIGHT - mapParams.Z_OFFSET)

  -- Convert resulting coordinates to track spline progress from 0 to 1:
  local trackProgress = ac.worldCoordinateToTrackProgress(ret)

  -- Convert track spline progress back to world coordinates:
  local nearestOnTrack = ac.trackProgressToWorldCoordinate(trackProgress)

  -- And let’s just grab Y value from there. Not the best approach, but should work for most cases:
  ret.y = nearestOnTrack.y
  return ret
end

-- This is the function that will create UI for the teleporting tool. Something very basic:
local function teleportHUD()
  -- Firstly, let’s show the list of players:
  ui.text('Select somebody:')

  -- A simple way to do a scrolling list, 120 pixels in height. Make sure ID (first argument) is unique
  -- within your script:
  ui.childWindow('##drivers', vec2(ui.availableSpaceX(), 120), function ()
    -- Iterate through all cars:
    for i = 1, sim.carsCount do
      -- Get a car (`ac.getCar()` works with 0-based indices):
      local car = ac.getCar(i - 1)

      -- Only offer to teleport connected cars:
      if car.isConnected then

        -- This function creates a selectable item. When clicked, it returns `true`, that’s where
        -- we change selected car:
        if ui.selectable(ac.getDriverName(i - 1), selectedCar == car) then
          selectedCar = car
        end

      end
    end

    -- Note: we could also use dropdown list with `ui.combo()`, but those extra online things can’t draw
    -- them yet unless you’d use `ui.OnlineExtraFlags.Tool` flag. To combine both Tool and Admin flag, use
    -- bit library: `bit.bor(ui.OnlineExtraFlags.Admin, ui.OnlineExtraFlags.Tool)` (or just sum them, but
    -- in more complicated cases it might not work, so might be a good idea to get used to bit library).
  end)

  -- Next, let’s draw a nice interactive map. Something simple but informative:
  ui.text('Select point on a map:')

  -- Remember where we are and draw relative to that:
  local drawFrom = ui.getCursor()

  -- Just draw the map itself:
  ui.drawImage(mapFilename, drawFrom, drawFrom + mapSize)

  -- Go through all the cars:
  for i = 1, sim.carsCount do

    -- Again, 0-based indices and, again, only connected ones
    local car = ac.getCar(i - 1)
    if car.isConnected then

      -- Simple transformation from world to relative coordinates:
      local posX = (car.position.x + mapParams.X_OFFSET) / mapParams.WIDTH
      local posY = (car.position.z + mapParams.Z_OFFSET) / mapParams.HEIGHT

      -- And just draw a filled circle there. In blue if car is selected:
      ui.drawCircleFilled(drawFrom + vec2(posX, posY) * mapSize, 4, car == selectedCar and rgbm.colors.blue or rgbm.colors.red)

    end

  end

  -- All `ui.draw…` functions don’t actually move cursor, so we’re still where we were when started drawing stuff. Let’s move with
  -- map size, so that window size would extend and include map:
  ui.dummy(mapSize)

  -- Using `ui.dummy()` like that also allows to easily track if map was clicked:
  if ui.itemClicked() then
    -- If it was, let’s update destination point:
    teleportPoint = (ui.mouseLocalPos() - drawFrom) / mapSize
  end

  -- And draw destination point in green:
  ui.drawCircleFilled(drawFrom + teleportPoint * mapSize, 4, rgbm.colors.green)
end

-- This last function is the one that will be called when “OK” is pressed. Note: if you were to change call and add flag
-- `ui.OnlineExtraFlags.Tool`, there wouldn’t be an “OK” button, you’d have to add one yourself with `ui.button()` or something.
local function teleportHUDClosed(okClicked)
  -- Function will be called if tool is closed with cancellation too, in case we’d want to dispose of something. But we’re
  -- only interested in it closing with “OK”, and if something was selected:
  if okClicked and selectedCar then

    -- Let’s get world coordinates using that simple function. Or, you can just use something like
    -- `ac.trackProgressToWorldCoordinate(trackProgress)` to teleport car on track, not where the click was (just move
    -- the line defining `teleportPoint` above).
    local worldCoordinates = getWorldPosFromRelativePos(teleportPoint)

    -- And calculate direction in a sort of similar way. Just find nearest point on track and nearest point on track one meter in front, and
    -- use the difference as direction:
    local trackProgress = ac.worldCoordinateToTrackProgress(worldCoordinates)
    local worldDirection = (ac.trackProgressToWorldCoordinate(trackProgress + 1 / sim.trackLengthM) - ac.trackProgressToWorldCoordinate(trackProgress)):normalize()

    -- And emit the event:
    jumpEvent({
      targetSessionID = selectedCar.sessionID,
      targetPosition = worldCoordinates,
      targetDirection = worldDirection
    })
  end
end

-- And, finally, register the tool:
ui.registerOnlineExtra(ui.Icons.FastForward, 'Teleport somebody', nil, teleportHUD, teleportHUDClosed, ui.OnlineExtraFlags.Admin)


-- Also, one last thing. 0.1.77 and a lot of 0.1.78-preview builds have this problem where sometimes tool wouldn’t appear
-- when opened. That’ll be fixed with 0.1.78.
