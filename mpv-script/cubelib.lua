-- net ids:
--
--             U: 1  2  3
--                4  5  6
--                7  8  9
--
-- L:10 11 12  F:19 20 21  R:28 29 30  B:37 38 39
--   13 14 15    22 23 24    31 32 33    40 41 42
--   16 17 18    25 26 27    34 35 36    43 44 45
--
--             D:46 47 48
--               49 50 51
--               52 53 54
--
--
-- local coordinates:
--
--   -1,+1   0,+1  +1,+1
--   -1, 0   0, 0  +1, 0
--   -1,-1   0,-1  +1,-1
--
-- global (cube) coordinates follow a left-handed system:
-- x increases to the right
-- y increases to the up
-- z increases to the back
-- (0,0,0) is the center of the cube
--
-- face strings and face IDs:
-- 1 = U, 2 = L, 3 = F, 4 = R, 5 = B, 6 = D

local function divmod(n, d)
  local mod = n % d
  return math.floor((n - mod) / d), mod
end

--------------------------------------------------------------------------------
-- [-1, +1]^3 coord <-> [1, 27] coord ID
--------------------------------------------------------------------------------

local function coord_of_id(id)
  local yz, x = divmod(id - 1, 3)
  local z, y = divmod(yz, 3)
  return {x - 1, y - 1, z - 1}
end

local function id_of_coord(coord)
  assert (math.abs(coord[1]) <= 1 and math.abs(coord[2]) <= 1 and math.abs(coord[3]) <= 1)
  return (coord[3] + 1) * 9 + (coord[2] + 1) * 3 + coord[1] + 2
end

for id = 1, 27 do
  local coord = coord_of_id(id)
  assert(id == id_of_coord(coord))
end

--------------------------------------------------------------------------------
-- [-1, +1]^2 face local coord <-> [1, 9] face local ID
--------------------------------------------------------------------------------

local function face_local_coord_of_face_local_id(face_local_id)
  local y, x = divmod(face_local_id - 1, 3)
  return x - 1, 1 - y
end

local function face_local_id_of_face_local_coord(local_x, local_y)
  assert (math.abs(local_x) <= 1 and math.abs(local_y) <= 1)
  return (1 - local_y) * 3 + local_x + 2
end

for local_id = 1, 9 do
  local local_x, local_y = face_local_coord_of_face_local_id(local_id)
  assert(local_id == face_local_id_of_face_local_coord(local_x, local_y))
end

--------------------------------------------------------------------------------
-- (face ID, face local ID) <-> net ID
--------------------------------------------------------------------------------

local function face_id_of_net_id(net_id)
  return math.floor((net_id - 1) / 9) + 1
end

local function face_local_id_of_net_id(net_id)
  return ((net_id - 1) % 9) + 1
end

local function net_id_of_face_id_and_face_local_id(face_id, face_local_id)
  return (face_id - 1) * 9 + face_local_id
end

for net_id = 1, 54 do
  local face_id = face_id_of_net_id(net_id)
  local face_local_id = face_local_id_of_net_id(net_id)
  assert(net_id_of_face_id_and_face_local_id(face_id, face_local_id) == net_id)
end

--------------------------------------------------------------------------------
-- (global coord, face ID) <-> net ID
--------------------------------------------------------------------------------

local function coord_of_face_id_and_face_local_coord(face_id, face_local_x, face_local_y)
  if face_id == 1 then return { face_local_x, 1, face_local_y } -- U
  elseif face_id == 2 then return { -1, face_local_y, -face_local_x } -- L
  elseif face_id == 3 then return { face_local_x, face_local_y, -1 } -- F
  elseif face_id == 4 then return { 1, face_local_y, face_local_x } -- R
  elseif face_id == 5 then return { -face_local_x, face_local_y, 1 } -- B
  elseif face_id == 6 then return { face_local_x, -1, -face_local_y } -- D
  else assert(false)
  end
end

local _coord_of_net_id = {}
local _net_id_of_coord_id_and_face_id = {}
for net_id = 1, 54 do
  local face_id = face_id_of_net_id(net_id)
  local face_local_x, face_local_y = face_local_coord_of_face_local_id(face_local_id_of_net_id(net_id))
  local coord = coord_of_face_id_and_face_local_coord(face_id, face_local_x, face_local_y)
  _coord_of_net_id[net_id] = coord
  local coord_id = id_of_coord(coord)
  _net_id_of_coord_id_and_face_id[coord_id] = _net_id_of_coord_id_and_face_id[coord_id] or {}
  _net_id_of_coord_id_and_face_id[coord_id][face_id] = net_id
end

local function coord_of_net_id(net_id)
  return _coord_of_net_id[net_id]
end

local function net_id_of_coord_and_face_id(coord, face_id)
  return _net_id_of_coord_id_and_face_id[id_of_coord(coord)][face_id]
end

--------------------------------------------------------------------------------
-- face ID <-> face normal
--------------------------------------------------------------------------------

local function face_normal_of_face_id(face_id)
  return coord_of_face_id_and_face_local_coord(face_id, 0, 0)
end

local _face_id_of_face_normal = {}
for face_id = 1, 6 do
  _face_id_of_face_normal[id_of_coord(face_normal_of_face_id(face_id))] = face_id
end

local function face_id_of_face_normal(face_normal)
  return _face_id_of_face_normal[id_of_coord(face_normal)]
end

--------------------------------------------------------------------------------
-- face ID <-> face string
--------------------------------------------------------------------------------

local _face_string_of_face_id = {"U", "L", "F", "R", "B", "D"}
local _face_id_of_face_string = {}
for face_id, face_string in ipairs(_face_string_of_face_id) do
  _face_id_of_face_string[face_string] = face_id
end

local function face_string_of_face_id(face_id)
  return _face_string_of_face_id[face_id]
end

local function face_id_of_face_string(face_string)
  return _face_id_of_face_string[face_string]
end

--------------------------------------------------------------------------------
-- net rotation
--------------------------------------------------------------------------------

local function rotate_cw(normal, coord)
  return {
    coord[3]*normal[2] - coord[2]*normal[3] + coord[1]*math.abs(normal[1]),
    coord[1]*normal[3] - coord[3]*normal[1] + coord[2]*math.abs(normal[2]),
    coord[2]*normal[1] - coord[1]*normal[2] + coord[3]*math.abs(normal[3])}
end

local function vec3_dot(coord1, coord2)
  return (coord1[1] * coord2[1] + coord1[2] * coord2[2] + coord1[3] * coord2[3])
end

local function vec3_sub(coord1, coord2)
  return {coord1[1] - coord2[1], coord1[2] - coord2[2], coord1[3] - coord2[3]}
end

local function rotate_net(net_id, move_string)
  -- parse move string
  local move_char = move_string:sub(1,1)
  local move_repetitions = 1
  if #move_string > 1 then
    if move_string:sub(2,2) == "2" then
      move_repetitions = 2
    elseif move_string:sub(2,2) == "'" then
      move_repetitions = 3
    else assert(false)
    end
  end

  local rotation_normal
  local face_offset = {0, 0, 0}
  local move_width = 1
  if true then
    local move_face_id = face_id_of_face_string(move_char:upper())
    if move_face_id ~= nil then
      if move_char == move_char:lower() then
        move_width = 2
      end
      rotation_normal = face_normal_of_face_id(move_face_id)
      face_offset = rotation_normal
    elseif move_char == "M" then
      rotation_normal = face_normal_of_face_id(face_id_of_face_string("L"))
    elseif move_char == "E" then
      rotation_normal = face_normal_of_face_id(face_id_of_face_string("D"))
    elseif move_char == "S" then
      rotation_normal = face_normal_of_face_id(face_id_of_face_string("F"))
    elseif move_char == "x" then
      rotation_normal = face_normal_of_face_id(face_id_of_face_string("R"))
      move_width = 3
    elseif move_char == "y" then
      rotation_normal = face_normal_of_face_id(face_id_of_face_string("U"))
      move_width = 3
    elseif move_char == "z" then
      rotation_normal = face_normal_of_face_id(face_id_of_face_string("F"))
      move_width = 3
    end
  end

  -- apply move
  local coord = coord_of_net_id(net_id)
  local function distance(x, y)
    return math.abs(x - y)
  end
  local distance_from_rotation_face = math.abs(vec3_dot(rotation_normal, vec3_sub(coord, face_offset)))
  if distance_from_rotation_face < move_width
  then
    local normal = face_normal_of_face_id(face_id_of_net_id(net_id))
    for _ = 1, move_repetitions do
      coord = rotate_cw(rotation_normal, coord)
      normal = rotate_cw(rotation_normal, normal)
    end
    return net_id_of_coord_and_face_id(coord, face_id_of_face_normal(normal))
  else
    return net_id
  end
end

assert(rotate_net(1, "R") == 1)
assert(rotate_net(2, "R") == 2)
assert(rotate_net(6, "R") == 40)
assert(rotate_net(9, "R") == 37)
assert(rotate_net(9, "R2") == 54)
assert(rotate_net(9, "R'") == 27)
assert(rotate_net(13, "R") == 13)
assert(rotate_net(1, "r") == 1)
assert(rotate_net(2, "r") == 44)
assert(rotate_net(1, "L") == 19)
assert(rotate_net(2, "L") == 2)
assert(rotate_net(1, "l") == 19)
assert(rotate_net(2, "l") == 20)
assert(rotate_net(3, "l") == 3)
assert(rotate_net(28, "l") == 28)
assert(rotate_net(41, "l") == 5)
assert(rotate_net(7, "F") == 28)
assert(rotate_net(7, "F2") == 48)
assert(rotate_net(6, "f2") == 49)
assert(rotate_net(37, "U") == 28)
assert(rotate_net(40, "u2") == 22)
assert(rotate_net(43, "D") == 16)
assert(rotate_net(14, "d") == 23)
assert(rotate_net(40, "B") == 38)
assert(rotate_net(1, "B") == 16)
assert(rotate_net(4, "M") == 4)
assert(rotate_net(5, "M") == 23)
assert(rotate_net(11, "E") == 11)
assert(rotate_net(14, "E") == 23)
assert(rotate_net(2, "S") == 2)
assert(rotate_net(5, "S") == 32)
assert(rotate_net(1, "x") == 45)
assert(rotate_net(9, "x") == 37)
assert(rotate_net(1, "y") == 3)
assert(rotate_net(9, "y") == 7)
assert(rotate_net(1, "z") == 30)
assert(rotate_net(9, "z") == 34)
for i = 1, 54 do
  for _, d2 in ipairs({"", "'", "2"}) do
    for face_id = 1, 6 do
      local d = face_string_of_face_id(face_id)
      assert(rotate_net(i, d .. d2) ~= nil)
      assert(rotate_net(i, d:lower() .. d2) ~= nil)
    end
    for _, d in ipairs({"M", "E", "S"}) do
      assert(rotate_net(i, d .. d2) ~= nil)
    end
    for _, d in ipairs({"x", "y", "z"}) do
      assert(rotate_net(i, d .. d2) ~= nil)
    end
  end
end

--------------------------------------------------------------------------------
-- net permutation
--------------------------------------------------------------------------------

local Permutation = {}
Permutation.__index = Permutation

function Permutation.new(o)
  local o = o or {}
  setmetatable(o, Permutation)
  for i = 1, 54 do
    o[i] = i
  end
  return o
end

function Permutation:invariant()
  local seen = {}
  for i = 1, 54 do
    assert(1 <= self[i] and self[i] <= 54)
    assert(not seen[self[i]])
    seen[self[i]] = true
  end
end

function Permutation:clone()
  local o = {}
  setmetatable(o, Permutation)
  for i = 1, 54 do
    assert(1 <= self[i] and self[i] <= 54)
    o[i] = self[i]
  end
  return o
end

function Permutation:invert()
  local o = {}
  setmetatable(o, Permutation)
  for i = 1, 54 do
    assert(o[self[i]] == nil)
    o[self[i]] = i
  end
  return o
end

function Permutation.__mul(first, second)
  local o = {}
  setmetatable(o, Permutation)
  for i = 1, 54 do
    o[i] = second[first[i]]
  end
  return o
end

function Permutation.__eq(first, second)
  for i = 1, 54 do
    if first[i] ~= second[i] then return false end
  end
  return true
end

local _permutation_of_move_string = {}
local _permutation_of_move_string_invert = {}
if true then
  local function f(move_string)
    local p = Permutation.new()
    _permutation_of_move_string[move_string] = p
    for i = 1, 54 do
      p[i] = rotate_net(i, move_string)
    end
    p:invariant()
    _permutation_of_move_string_invert[move_string] = p:invert()
  end
  for _, d2 in ipairs({"", "'", "2"}) do
    for face_id = 1, 6 do
      local face_string = face_string_of_face_id(face_id)
      f(face_string .. d2)
      f(face_string:lower() .. d2)
    end
    for _, d in ipairs({"M", "E", "S", "x", "y", "z"}) do
      f(d .. d2)
    end
  end
end

function Permutation.of_move_string(move_string)
  return _permutation_of_move_string[move_string]
end

function Permutation.of_move_string_invert(move_string)
  return _permutation_of_move_string_invert[move_string]
end

for face_id = 1, 6 do
  local face_string = face_string_of_face_id(face_id)
  assert(Permutation.of_move_string(face_string) * Permutation.of_move_string(face_string .. "'") == Permutation.new())
  assert(Permutation.of_move_string(face_string):invert() == Permutation.of_move_string(face_string .. "'"))
  assert(Permutation.of_move_string(face_string) * Permutation.of_move_string(face_string) == Permutation.of_move_string(face_string .. "2"))
end
assert(Permutation.of_move_string("M") ==
       Permutation.of_move_string("L'") *
       Permutation.of_move_string("R") *
       Permutation.of_move_string("x'"))
if true then
  local function test(move)
    assert(Permutation.of_move_string_invert(move) == Permutation.of_move_string(move .. "'"))
    assert(Permutation.of_move_string_invert(move .. "'") == Permutation.of_move_string(move))
    assert(Permutation.of_move_string_invert(move .. "2") == Permutation.of_move_string(move .. "2"))
  end
  for face_id = 1, 6 do
    local d = face_string_of_face_id(face_id)
    test(d)
    test(d:lower())
  end
  for _, d in ipairs({"M", "E", "S", "x", "y", "z"}) do
    test(d)
  end
end

--------------------------------------------------------------------------------
-- public interface
--------------------------------------------------------------------------------

return {
  coord_of_id = coord_of_id,
  id_of_coord = id_of_coord,

  face_local_coord_of_face_local_id = face_local_coord_of_face_local_id,
  face_local_id_of_face_local_coord = face_local_id_of_face_local_coord,

  face_id_of_net_id = face_id_of_net_id,
  face_local_id_of_net_id = face_local_id_of_net_id,
  net_id_of_face_id_and_face_local_id = net_id_of_face_id_and_face_local_id,

  coord_of_face_id_and_face_local_coord = coord_of_face_id_and_face_local_coord,
  coord_of_net_id = coord_of_net_id,
  net_id_of_coord_and_face_id = net_id_of_coord_and_face_id,

  face_normal_of_face_id = face_normal_of_face_id,
  face_id_of_face_normal = face_id_of_face_normal,

  face_string_of_face_id = face_string_of_face_id,
  face_id_of_face_string = face_id_of_face_string,

  rotate_net = rotate_net,

  Permutation = Permutation,
}
