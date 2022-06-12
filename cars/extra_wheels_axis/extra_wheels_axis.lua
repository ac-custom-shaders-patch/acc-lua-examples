--[[
  Simple script to move additional wheels in a semi-beliveable way. Nothing particularly fancy.
]]

-- Point #1: for things to work nicely, we need to move some objects around (for example, move
-- wheels from TRANSMISSION_… into separate nodes), but to keep things compatible with non-CSP AC
-- we need to do it without editing KN5 and instead doing changes live. This is where this function
-- comes in: it takes name of a node, finds a node with such name in given parent node and if none
-- were found, creates new node with that name and moves children to it.
---@param parent ac.SceneReference
---@param name string
---@param children string
---@return ac.SceneReference
local function createNewParent(parent, name, children)
  local ret = parent:findNodes(name)
  if #ret == 0 then 
    ret = parent:createNode(name, true)  -- `true` for second parameter to keep node existing when script reloads
    parent:findAny(children):setParent(ret)
  end
  return ret
end

-- Find root nodes for LODs A and B
local parentA = ac.findNodes('{ TRANSMISSION_R_0 & lod:A }'):getParent()
local parentB = ac.findNodes('{ TRANSMISSION_R_0 & lod:B }'):getParent()

-- Point #2: we need to do some things with extra wheels: move them accordingly, raycast surface and keep track
-- of vertical offset, add up overall rotation, update material properties. With that, let’s make a very simple
-- class which would keep track of the state.
---@class WheelHolder
local WheelHolder = class()

function WheelHolder:initialize(wheelIndex, postfix, search)
  self.wheel = car.wheels[wheelIndex]
  self.tyreA = createNewParent(parentA, 'TYRE_NEW_A_'..postfix, search)
  self.tyreB = createNewParent(parentB, 'TYRE_NEW_B_'..postfix, search)
  self.matA = self.tyreA:getTransformationRaw()
  self.matB = self.tyreB:getTransformationRaw()
  self.tyresMaterial = self.tyreA:findMeshes('shader:ksTyres'):append(self.tyreB:findMeshes('shader:ksTyres'))
  self.tyresMaterial:ensureUniqueMaterials()
  self.rotation = 0
  self.offset = 0
end

function WheelHolder:update(dt)
  self.rotation = self.rotation + self.wheel.angularSpeed * dt
  local mat, tyre = self.matA, self.tyreA
  if car.activeLOD == 1 then
    mat, tyre = self.matB, self.tyreB
  end
  car.worldToLocal:transformPointTo(mat.position, self.wheel.position)
  mat.position.y = self.wheel.tyreRadius + 0.03
  mat.position.z = mat.position.z - 0.496 -- distance between wheels
  tyre:setOrientation((car.worldToLocal:transformVector(self.wheel.look) + vec3(0, 0, 0.3)):normalize())
  tyre:rotate(vec3(1, 0, 0), self.rotation)

  local rayPos = self.wheel.position - car.look * 0.496
  local rayDistance = physics.raycastTrack(rayPos, vec3(0, -1, 0), 1)
  if rayDistance == -1 then rayDistance = 1e9 end
  local targetOffset = math.clamp(self.wheel.tyreRadius - rayDistance, -0.05, 0.05)
  self.offset = targetOffset > self.offset and targetOffset or math.applyLag(self.offset, targetOffset, 0.9, dt)
  mat.position.y = mat.position.y + self.offset

  self.tyresMaterial:setMaterialProperty('blurLevel', math.min(1, math.abs(self.wheel.angularSpeed * 0.1)))
  self.tyresMaterial:setMaterialProperty('dirtyLevel', math.saturateN(self.wheel.tyreDirty))
end

local wheelL = WheelHolder(0, 'LF', 'parent:TRANSMISSION_L_0') ---@type WheelHolder
local wheelR = WheelHolder(1, 'RF', 'parent:TRANSMISSION_R_0') ---@type WheelHolder

local suspLPos = vec3(0.485, 0.25, 0.87)
local suspRPos = vec3(-0.485, 0.25, 0.87)
local suspL1 = createNewParent(parentA, 'SUSP_LF2_NEW0', 'CUSTOM_LF_0___alt_cut_')
local suspL2 = createNewParent(parentA, 'SUSP_LF2_NEW1', 'CUSTOMF_FRONT_SUSP_L___alt_cut_')
local suspL3 = createNewParent(parentA, 'SUSP_LF2_NEW2', 'CUSTOM_LF_1___alt_cut_')
local suspR1 = createNewParent(parentA, 'SUSP_RF2_NEW0', 'CUSTOM_RF_0___alt_cut_')
local suspR2 = createNewParent(parentA, 'SUSP_RF2_NEW1', 'CUSTOMF_FRONT_SUSP_R___alt_cut_')
local suspR3 = createNewParent(parentA, 'SUSP_RF2_NEW2', 'CUSTOM_RF_1___alt_cut_')

local function setSuspension(offsetL, offsetR)
  suspL1:setPosition(vec3(0, 0.07 + offsetL * 0.08, 0.2):add(suspLPos))
  suspL1:setOrientation(vec3(0, 0, 1), vec3(-offsetL, 1, 0))
  suspL2:setPosition(vec3(0, -0.04 + offsetL * 0.08, 0.25):add(suspLPos))
  suspL2:setOrientation(vec3(0, 0, 1), vec3(-offsetL, 1, 0))
  suspL3:setPosition(vec3(0, -0.14 + offsetL * 0.1, 0.2):add(suspLPos))
  suspL3:setOrientation(vec3(0, 0, 1), vec3(-offsetL, 1, 0))

  suspR1:setPosition(vec3(0, 0.07 + offsetR * 0.08, 0.2):add(suspRPos))
  suspR1:setOrientation(vec3(0, 0, 1), vec3(offsetR, 1, 0))
  suspR2:setPosition(vec3(0, -0.04 + offsetR * 0.08, 0.25):add(suspRPos))
  suspR2:setOrientation(vec3(0, 0, 1), vec3(offsetR, 1, 0))
  suspR3:setPosition(vec3(0, -0.14 + offsetR * 0.1, 0.2):add(suspRPos))
  suspR3:setOrientation(vec3(0, 0, 1), vec3(offsetR, 1, 0))

  -- This thing could be rewritten differently to work faster (avoid recreating vectors anew, set
  -- orientation once per side and orientation vectors to other nodes, update only if offset 
  -- noticeably changed, etc.), but in this case it doesn’t really matter, seems to work fast
  -- enough for something as simple as this. And optimizing it might make code less readable.
end

function script.update(dt)
  wheelL:update(dt)
  wheelR:update(dt)

  if car.activeLOD == 0 then
    setSuspension(wheelL.offset * 6, wheelR.offset * 6)
  end

  -- for debugging we can use wave for offset and tweak coordinates to look acceptable
  -- setSuspension(math.sin(sim.time / 100) * 0.2, math.sin(sim.time / 100) * 0.2)
end
