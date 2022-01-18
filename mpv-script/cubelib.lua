-- sticker ids:
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

function divmod(n, d)
  local mod = n % d
  return math.floor((n - mod) / d), mod
end

--------------------------------------------------------------------------------
-- [-1, +1]^3 coord <-> [1, 27] coord ID
--------------------------------------------------------------------------------

function coord_of_id(id)
  local yz, x = divmod(id - 1, 3)
  local z, y = divmod(yz, 3)
  return {x - 1, y - 1, z - 1}
end

function id_of_coord(coord)
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

function face_local_coord_of_face_local_id(face_local_id)
  local y, x = divmod(face_local_id - 1, 3)
  return x - 1, 1 - y
end

function face_local_id_of_face_local_coord(local_x, local_y)
  assert (math.abs(local_x) <= 1 and math.abs(local_y) <= 1)
  return (1 - local_y) * 3 + local_x + 2
end

for local_id = 1, 9 do
  local local_x, local_y = face_local_coord_of_face_local_id(local_id)
  assert(local_id == face_local_id_of_face_local_coord(local_x, local_y))
end

--------------------------------------------------------------------------------
-- (global coord, face ID) <-> sticker ID
--------------------------------------------------------------------------------

function face_id_of_sticker_id(sticker_id)
  return math.floor((sticker_id - 1) / 9) + 1
end

function face_local_id_of_sticker_id(sticker_id)
  return ((sticker_id - 1) % 9) + 1
end

function coord_of_face_id_and_face_local_coord(face_id, face_local_x, face_local_y)
  if face_id == 1 then return { face_local_x, 1, face_local_y } -- U
  elseif face_id == 2 then return { -1, face_local_y, -face_local_x } -- L
  elseif face_id == 3 then return { face_local_x, face_local_y, -1 } -- F
  elseif face_id == 4 then return { 1, face_local_y, face_local_x } -- R
  elseif face_id == 5 then return { -face_local_x, face_local_y, 1 } -- B
  elseif face_id == 6 then return { face_local_x, -1, -face_local_y } -- D
  else assert(false)
  end
end

local _coord_of_sticker_id = {}
local _sticker_id_of_coord_id_and_face_id = {}
for sticker_id = 1, 54 do
  face_id = face_id_of_sticker_id(sticker_id)
  face_local_x, face_local_y = face_local_coord_of_face_local_id(face_local_id_of_sticker_id(sticker_id))
  local coord = coord_of_face_id_and_face_local_coord(face_id, face_local_x, face_local_y)
  _coord_of_sticker_id[sticker_id] = coord
  local coord_id = id_of_coord(coord)
  _sticker_id_of_coord_id_and_face_id[coord_id] = _sticker_id_of_coord_id_and_face_id[coord_id] or {}
  _sticker_id_of_coord_id_and_face_id[coord_id][face_id] = sticker_id
end

function coord_of_sticker_id(sticker_id)
  return _coord_of_sticker_id[sticker_id]
end

function sticker_id_of_coord_and_face_id(coord, face_id)
  return _sticker_id_of_coord_id_and_face_id[id_of_coord(coord)][face_id]
end

--------------------------------------------------------------------------------
-- face ID <-> face normal
--------------------------------------------------------------------------------

function face_normal_of_face_id(face_id)
  return coord_of_face_id_and_face_local_coord(face_id, 0, 0)
end

local _face_id_of_face_normal = {}
for face_id = 1, 6 do
  _face_id_of_face_normal[id_of_coord(face_normal_of_face_id(face_id))] = face_id
end

function face_id_of_face_normal(face_normal)
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

function face_string_of_face_id(face_id)
  return _face_string_of_face_id[face_id]
end

function face_id_of_face_string(face_string)
  return _face_id_of_face_string[face_string]
end

--------------------------------------------------------------------------------
-- sticker rotation
--------------------------------------------------------------------------------

function rotate_cw(normal, coord)
  return {
    coord[3]*normal[2] - coord[2]*normal[3] + coord[1]*math.abs(normal[1]),
    coord[1]*normal[3] - coord[3]*normal[1] + coord[2]*math.abs(normal[2]),
    coord[2]*normal[1] - coord[1]*normal[2] + coord[3]*math.abs(normal[3])}
end

function dot_product(coord1, coord2)
  return (coord1[1] * coord2[1] + coord1[2] * coord2[2] + coord1[3] * coord2[3])
end

function rotate_sticker(sticker_id, move_string)
  -- parse move string
  local move_char = move_string:sub(1,1)
  local move_width = 1
  if move_char == move_char:lower() then
    move_width = 2
    move_char = move_char:upper()
  end
  local move_face_id
  move_face_id = face_id_of_face_string(move_char)
  local move_repetitions = 1
  if #move_string > 1 then
    if move_string:sub(2,2) == "2" then
      move_repetitions = 2
    elseif move_string:sub(2,2) == "'" then
      move_repetitions = 3
    else assert(false)
    end
  end

  -- apply move
  local rotation_normal = face_normal_of_face_id(move_face_id)
  local coord = coord_of_sticker_id(sticker_id)
  function distance(x, y)
    return math.abs(x - y)
  end
  local distance_from_rotation_face = 1 - dot_product(face_normal_of_face_id(move_face_id), coord)
  if distance_from_rotation_face < move_width
  then
    local normal = face_normal_of_face_id(face_id_of_sticker_id(sticker_id))
    for _ = 1, move_repetitions do
      coord = rotate_cw(rotation_normal, coord)
      normal = rotate_cw(rotation_normal, normal)
    end
    return sticker_id_of_coord_and_face_id(coord, face_id_of_face_normal(normal))
  else
    return sticker_id
  end
end

assert(rotate_sticker(1, "R") == 1)
assert(rotate_sticker(2, "R") == 2)
assert(rotate_sticker(6, "R") == 40)
assert(rotate_sticker(9, "R") == 37)
assert(rotate_sticker(9, "R2") == 54)
assert(rotate_sticker(9, "R'") == 27)
assert(rotate_sticker(13, "R") == 13)
assert(rotate_sticker(1, "r") == 1)
assert(rotate_sticker(2, "r") == 44)
assert(rotate_sticker(1, "L") == 19)
assert(rotate_sticker(2, "L") == 2)
assert(rotate_sticker(1, "l") == 19)
assert(rotate_sticker(2, "l") == 20)
assert(rotate_sticker(3, "l") == 3)
assert(rotate_sticker(28, "l") == 28)
assert(rotate_sticker(41, "l") == 5)
assert(rotate_sticker(7, "F") == 28)
assert(rotate_sticker(7, "F2") == 48)
assert(rotate_sticker(6, "f2") == 49)
assert(rotate_sticker(37, "U") == 28)
assert(rotate_sticker(40, "u2") == 22)
assert(rotate_sticker(43, "D") == 16)
assert(rotate_sticker(14, "d") == 23)
assert(rotate_sticker(40, "B") == 38)
assert(rotate_sticker(1, "B") == 16)
for _, d in ipairs({"U", "L", "F", "R", "B", "D"}) do
  for _, d2 in ipairs({"", "'", "2"}) do
    for i = 1, 54 do
      assert(rotate_sticker(i, d .. d2) ~= nil)
      assert(rotate_sticker(i, d:lower() .. d2) ~= nil)
    end
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

  face_id_of_sticker_id = face_id_of_sticker_id,
  face_local_id_of_sticker_id = face_local_id_of_sticker_id,
  coord_of_face_id_and_face_local_coord = coord_of_face_id_and_face_local_coord,
  coord_of_sticker_id = coord_of_sticker_id,
  sticker_id_of_coord_and_face_id = sticker_id_of_coord_and_face_id,

  face_normal_of_face_id = face_normal_of_face_id,
  face_id_of_face_normal = face_id_of_face_normal,

  face_string_of_face_id = face_string_of_face_id,
  face_id_of_face_string = face_id_of_face_string,

  rotate_sticker = rotate_sticker,
}
