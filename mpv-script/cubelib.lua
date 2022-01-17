-- a permutation is a shuffle of sticker ids. sticker ids:
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
-- orientations:
-- 1 = U, 2 = L, 3 = F, 4 = R, 5 = B, 6 = D

function face_id_of_sticker_id(sticker_id)
  return math.floor((sticker_id - 1) / 9) + 1
end

function face_local_id_of_sticker_id(sticker_id)
  return ((sticker_id - 1) % 9) + 1
end

function face_local_coord_of_face_local_id(face_local_id)
  return (face_local_id - 1) % 3 + 1, math.floor((face_local_id - 1) / 3) + 1
end

function sticker_id_of_face_id_and_face_local_coord(face_id, face_local_x, face_local_y)
  return face_id * 9 + face_local_y * 3 + face_local_x
end

function coord_of_face_id_and_face_local_coord(face_id, face_local_x, face_local_y)
  if face_id == 1 then return { face_local_x, 1, face_local_y } -- U
  elseif face_id == 2 then return { 1, face_local_y, face_local_x } -- L
  elseif face_id == 3 then return { face_local_x, face_local_y, 3 } -- F
  elseif face_id == 4 then return { 3, face_local_y, 4 - face_local_x } -- R
  elseif face_id == 5 then return { 4 - face_local_x, face_local_y, 1 } -- B
  elseif face_id == 6 then return { face_local_x, 3, 4 - face_local_y } -- D
  else assert(false)
  end
end

function face_local_x_and_y_of_face_id_and_coord(face_id, coord)
  if face_id == 1 then return coord[1], coord[2]
  elseif face_id == 2 then return coord[3], coord[2]
  elseif face_id == 3 then return coord[1], coord[2]
  elseif face_id == 4 then return 4 - coord[3], coord[2]
  elseif face_id == 5 then return 4 - coord[1], coord[2]
  elseif face_id == 6 then return coord[1], 4 - coord[3]
  else assert(false)
  end
end

local coord_of_sticker_id = {}
local _sticker_id_of_coord_and_face_id = {}
for sticker_id = 1, 54 do
  face_id = face_id_of_sticker_id(sticker_id)
  face_local_x, face_local_y = face_local_coord_of_face_local_id(face_local_id_of_sticker_id(sticker_id))
  local coord = coord_of_face_id_and_face_local_coord(face_id, face_local_x, face_local_y)
  coord_of_sticker_id[sticker_id] = coord
  _sticker_id_of_coord_and_face_id[coord[1]] = _sticker_id_of_coord_and_face_id[coord[1]] or {}
  _sticker_id_of_coord_and_face_id[coord[1]][coord[2]] = _sticker_id_of_coord_and_face_id[coord[1]][coord[2]] or {}
  _sticker_id_of_coord_and_face_id[coord[1]][coord[2]][coord[3]] = _sticker_id_of_coord_and_face_id[coord[1]][coord[2]][coord[3]] or {}
  _sticker_id_of_coord_and_face_id[coord[1]][coord[2]][coord[3]][face_id] = sticker_id
end

function sticker_id_of_coord_and_face_id(coord, face_id)
  return _sticker_id_of_coord_and_face_id[coord[1]][coord[2]][coord[3]][face_id]
end

-- face_local_id_permutation[n][i] represents which index i ends up at after n
-- clockwise turns
face_local_id_permutation = {{ 3, 6, 9, 2, 5, 8, 1, 4, 7 }}
for n = 2, 3 do
  face_local_id_permutation[n] = {}
  for i = 1, 9 do
    face_local_id_permutation[n][i] =
      face_local_id_permutation[n - 1][face_local_id_permutation[1][i]]
  end
end

function face_normal_of_face_id(face_id)
  if face_id == 1 then return { 0, -1,  0} -- U
  elseif face_id == 2 then return {-1,  0,  0} -- L
  elseif face_id == 3 then return { 0,  0,  1} -- F
  elseif face_id == 4 then return { 1,  0,  0} -- R
  elseif face_id == 5 then return { 0,  0, -1} -- B
  elseif face_id == 6 then return { 0,  1,  0} -- D
  else assert(false)
  end
end

function face_id_of_face_normal(face_normal)
  assert(math.abs(face_normal[1]) + math.abs(face_normal[2]) + math.abs(face_normal[3]) == 1)
  if face_normal[2] == -1 then return 1
  elseif face_normal[1] == -1 then return 2
  elseif face_normal[3] == 1 then return 3
  elseif face_normal[1] == 1 then return 4
  elseif face_normal[3] == -1 then return 5
  elseif face_normal[2] == 1 then return 6
  else assert(false)
  end
end

function rotate_cw(normal, coord)
  return {
    coord[3]*normal[2] - coord[2]*normal[3] + coord[1]*math.abs(normal[1]),
    coord[1]*normal[3] - coord[3]*normal[1] + coord[2]*math.abs(normal[2]),
    coord[2]*normal[1] - coord[1]*normal[2] + coord[3]*math.abs(normal[3])}
end

function rotate_cw_coord(normal, coord)
  local normalised_coord = {coord[1] - 2, coord[2] - 2, coord[3] - 2}
  local normalised_rotated_coord = rotate_cw(normal, normalised_coord)
  return {normalised_rotated_coord[1] + 2,
          normalised_rotated_coord[2] + 2,
          normalised_rotated_coord[3] + 2}
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
  if move_char == "U" then move_face_id = 1
  elseif move_char == "L" then move_face_id = 2
  elseif move_char == "F" then move_face_id = 3
  elseif move_char == "R" then move_face_id = 4
  elseif move_char == "B" then move_face_id = 5
  elseif move_char == "D" then move_face_id = 6
  else assert(false)
  end
  local move_repetitions = 1
  if #move_string > 1 then
    if move_string:sub(2,2) == "2" then
      move_repetitions = 2
    elseif move_string:sub(2,2) == "'" then
      move_repetitions = 3
    else assert(false)
    end
  end

  local rotation_normal = face_normal_of_face_id(move_face_id)

  local coord = coord_of_sticker_id[sticker_id]
  function distance(x, y)
    return math.abs(x - y)
  end
  if (move_face_id == 1 and distance(coord[2], 1) < move_width)
    or (move_face_id == 2 and distance(coord[1], 1) < move_width)
    or (move_face_id == 3 and distance(coord[3], 3) < move_width)
    or (move_face_id == 4 and distance(coord[1], 3) < move_width)
    or (move_face_id == 5 and distance(coord[3], 1) < move_width)
    or (move_face_id == 6 and distance(coord[2], 3) < move_width)
  then
    local normal = face_normal_of_face_id(face_id_of_sticker_id(sticker_id))
    for _ = 1, move_repetitions do
      coord = rotate_cw_coord(rotation_normal, coord)
      normal = rotate_cw(rotation_normal, normal)
    end
    return sticker_id_of_coord_and_face_id(coord, face_id_of_face_normal(normal))
  else
    return sticker_id
  end

end

function permutation_identity()
  local permutation = {}
  for i = 1, 6 * 3 * 3 do
    permutation[i] = i
  end
  return permutation
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
for _, d in ipairs({"U", "L", "F", "R", "B", "D"}) do
  for _, d2 in ipairs({"", "'", "2"}) do
    for i = 1, 54 do
      assert(rotate_sticker(i, d .. d2) ~= nil)
    end
  end
end



return "hi"
