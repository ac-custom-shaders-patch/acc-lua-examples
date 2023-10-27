Some short snippers:

### Animating a semaphore

Glowing red for 30 seconds, then green for 2, then back to red:

```lua
local semaphore = ac.findMeshes('Loft009')
semaphore:setMaterialProperty('ksEmissive', rgb(10, 0, 0))
setInterval(function () 
  semaphore:setMaterialProperty('ksEmissive', rgb(0, 10, 0))
  setTimeout(function () semaphore:setMaterialProperty('ksEmissive', rgb(10, 0, 0)) end, 2)
end, 32)
```
