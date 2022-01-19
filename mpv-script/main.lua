local assdraw = require('mp.assdraw')
local msg = require('mp.msg')
local utils = require('mp.utils')
local cubelib = require('cubelib')

local MODE_EDIT_MOVES = "EDIT_MOVES"
local MODE_EDIT_STICKERS = "EDIT_STICKERS"

local state =
  {
    osd = mp.create_osd_overlay("ass-events"),
    media_filename,
    playback_time,
    label_filename,
    label_file,
    mode,
    sticker_cursor,
    events, -- { {time=3,moves={"U","D"},permutation={},stickers={}}, ...}. permutation[sticker_id] = net_id where that sticker is right now
  }

function state_reset()
  state.media_filename = nil
  state.playback_time = nil
  state.label_filename = nil
  if state.label_file then
    state.label_file:close()
  end
  state.label_file = nil
  state.mode = MODE_EDIT_MOVES
  state.sticker_cursor = 23
  state.events = {{time = -1, moves = {}, permutation = cubelib.Permutation.new(), stickers = {}}}
end

state_reset()

function binary_search_last_le(events, time)
  local lo, hi = 0, #events
  while lo < hi do
    local mid = hi - math.floor((hi - lo) / 2)
    if mid == 0 or events[mid].time <= time then
      lo = mid
    else
      hi = mid - 1
    end
  end
  return lo
end

function state_load(media_filename)
  state_reset()
  if media_filename then
    state.media_filename = media_filename
    state.label_filename = media_filename .. ".cube-labels.json"
    -- TODO: load json
  end
end

function process_playback_time(name, val)
  local media_filename = mp.get_property("filename")
  msg.trace("process_playback_time", name, val, media_filename)
  if media_filename ~= state.media_filename then
    msg.info("reset state: change of filename")
    state_load(media_filename)
  end
  state.playback_time = val
  rerender()
end

function events_moves_append(move)
  if not state.playback_time then
    return nil
  end
  local idx = binary_search_last_le(state.events, state.playback_time)
  local was_present = state.events[idx] and state.events[idx].time == state.playback_time
  if not was_present then
    table.insert(state.events,
                 idx + 1,
                 { time = state.playback_time,
                   moves = {},
                   permutation = state.events[idx].permutation,
                   stickers = state.events[idx].stickers })
    idx = idx + 1
  end

  assert(idx >= 2 and idx <= #state.events)

  local moves = state.events[idx].moves
  if move == "BS" then
    if was_present then
      if #moves > 0 then
        table.remove(moves)
      else
        table.remove(state.events, idx)
      end
    end
  elseif move == "'" or move == "2" then
    if was_present then
      if #moves > 0 then
        if moves[#moves]:sub(2,2) == move then
          moves[#moves] = moves[#moves]:sub(1,1)
        else
          moves[#moves] = moves[#moves]:sub(1,1) .. move
        end
      end
    end
  else
    table.insert(moves, move)
  end

  -- update future permutations
  local i = idx
  while i <= #state.events do
    local permutation = state.events[i - 1].permutation
    for _, move in ipairs(state.events[i].moves) do
      local p2 = cubelib.Permutation.of_move_string(move)
      assert(p2 ~= nil)
      permutation = permutation * p2
    end
    state.events[i].permutation = permutation
    i = i + 1
  end
end

local keymap = {}
local function add_keystring(name, str)
  for i = 1, #str do
    local c = str:sub(i,i)
    keymap[c] = keymap[c] or {}
    table.insert(keymap[c], name)
    keymap[c][name] = true
  end
  msg.info(utils.to_string(keymap))
end

local function escape_ass(s)
  return s:gsub("\\n", " "):gsub("\\$", ""):gsub("{","\\{")
end

local _face_net_position_of_face_id = {{1, 2}, {0, 1}, {1, 1}, {2, 1}, {3, 1}, {1, 0}}
local _face_id_of_face_net_position = {}
for face_id, face_net_position in ipairs(_face_net_position_of_face_id) do
  _face_id_of_face_net_position[face_net_position[2] * 4 + face_net_position[1] + 1] = face_id
end
local function face_net_position_of_face_id(face_id)
  local p = _face_net_position_of_face_id[face_id]
  return p[1], p[2]
end
local function face_id_of_face_net_position(x, y)
  if x < 0 or x >= 4 then return nil end
  return _face_id_of_face_net_position[y * 4 + x + 1]
end
for i = 1, 6 do
  local x, y = face_net_position_of_face_id(i)
  assert(i == face_id_of_face_net_position(x, y))
end

function rerender()
  msg.trace("rerender")

  -- debug info
  local ass_debug = assdraw.ass_new()
  ass_debug:pos(0, 240)
  ass_debug:append(
    "{\\fnMonospace\\fs10\\q1\\bord2\\c&HB0B0B0&}"
  )
  ass_debug:append(string.format("mode: %s\\Nevents: %s",
                                 utils.to_string(state.mode),
                                 escape_ass(utils.to_string(state.events))))

  local ass_moves = assdraw.ass_new()
  local ass_sticker_cursor = assdraw.ass_new()
  local ass_stickers = assdraw.ass_new()
  if state.playback_time then
    local idx = binary_search_last_le(state.events, state.playback_time)

    assert(idx >= 1 and idx <= #state.events)

    -- moves
    ass_moves:pos(0, 0)
    if state.events[idx].time == state.playback_time then
      ass_moves:append("{\\c&HFFFF00&}")
    else
      ass_moves:append("{\\c&HB0B0B0&}")
    end
    ass_moves:append(table.concat(state.events[idx].moves, " "))
    ass_moves:append(" |")

    -- stickers
    for sticker_id = 1, 54 do
      local net_id = state.events[idx].permutation[sticker_id]
      local net_face_id = cubelib.face_id_of_net_id(net_id)
      local net_face_local_id = cubelib.face_local_id_of_net_id(net_id)
      local net_face_local_x, net_face_local_y = cubelib.face_local_coord_of_face_local_id(net_face_local_id)
      local net_face_net_x, net_face_net_y = face_net_position_of_face_id(net_face_id)
      local screen_x = 640 + 15 * ((net_face_net_x - 4) * 4 + net_face_local_x)
      local screen_y = 15 * ((2 - net_face_net_y) * 4 + 3 - net_face_local_y)
      if net_id == state.sticker_cursor then
        ass_sticker_cursor:append("{\\c&H00FFFF&\\alpha&H80&\\bord0}")
        ass_sticker_cursor:draw_start()
        ass_sticker_cursor:rect_cw(screen_x - 7, screen_y - 7, screen_x + 7, screen_y + 7)
        ass_sticker_cursor:draw_stop()
      end
      ass_stickers:new_event()
      ass_stickers:pos(screen_x, screen_y)
      ass_stickers:append("{\\fs10\\an5}")
      ass_stickers:append(string.format("%d", sticker_id))
    end
  end

  local ass = assdraw.ass_new()
  ass:append(ass_debug.text)
  ass:new_event()
  ass:append(ass_moves.text)
  ass:new_event()
  ass:append(ass_sticker_cursor.text)
  ass:new_event()
  ass:append(ass_stickers.text)

  state.osd.data = ass.text
  state.osd.z = 500
  state.osd:update()
end

add_keystring("colour", "wrgboyWRGBOY")
add_keystring("cursor_move", "hjkl")
add_keystring("face", "furbldFURBLD")
add_keystring("slice", "mesMES")
add_keystring("move_modifier", "'2")
add_keystring("help", "?")
keymap["BS"] = {}
keymap["ESC"] = {}
keymap["TAB"] = {}

for key, map in pairs(keymap) do
  for ctrl = 0, 1 do
    local ctrl = ctrl == 1
    for alt = 0, 1 do
      local alt = alt == 1
      local keystring = key
      if alt then
        keystring = "alt+" .. keystring
      end
      if ctrl then
        keystring = "ctrl+" .. keystring
      end
      function handler (e)
        msg.info("process_key", keystring, utils.to_string(map))
        if state.mode == MODE_EDIT_MOVES then
          if key == "TAB" then
            state.mode = MODE_EDIT_STICKERS
          elseif (map["face"] or map["slice"] or map["move_modifier"] or key == "BS") and not ctrl and not alt then
            events_moves_append(key)
          end
        elseif state.mode == MODE_EDIT_STICKERS then
          if key == "TAB" then
            state.mode = MODE_EDIT_MOVES
          end
        end
        rerender()
      end
      mp.add_forced_key_binding(keystring, nil, handler)
    end
  end
end

function process_mbtn_left(e)
  --msg.info("process_mbtn_left")
end

function process_mouse_move(e)
  --msg.info("process_mouse_move")
end

mp.add_forced_key_binding("mbtn_left", nil, process_mbtn_left, {complex = true})
mp.add_forced_key_binding("mouse_move", nil, process_mouse_move)
mp.observe_property("playback-time", "number", process_playback_time)

local f = io.open("foo", "r")
msg.info(f:read())
f:close()
