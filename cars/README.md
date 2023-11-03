Some short snippers:

### Getting body roll

```lua
local bodyRoll = math.atan2(car.transform.side.y, #vec2(car.transform.side.x, car.transform.side.z)) * 180 / math.pi
```

### Using UVFlow shader for animating a belt linked to car RPM

```lua
local meshes = ac.findMeshes('MESH_NAME')
local texOffset = 0

function script.update(dt)
  texOffset = (texOffset + dt * car.rpm * 0.01) % 1
  meshes:setMaterialProperty('uvOffsetX', texOffset)
end
```

### Playing an animation for a second

```lua
local root = ac.findNodes('luaRoot:yes')
local progress = 0
local animation  -- split like that, function passed to `setInterval()` will be able to clear it too
animation = setInterval(function() 
  progress = progress + sim.dt
  root:setAnimation('rpm_startup.ksanim', math.saturate(progress))
  if progress > 1 then clearInterval(animation) end
end, 0)
```

Note: minimum interval for both `setTimeout()` and `setInterval()` is a frame duration (callbacks won’t be called more than once per frame), so passing 0 is a great way to make sure your callback will be called once each frame.
