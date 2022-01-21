local assdraw = require('mp.assdraw')
local msg = require('mp.msg')
local utils = require('mp.utils')
local cubelib = require('cubelib')

local MODE_EDIT_MOVES = "EDIT_MOVES"
local MODE_EDIT_STICKERS = "EDIT_STICKERS"

local MOVE_RESET = "*"

local function divmod(n, d)
  local mod = n % d
  return math.floor((n - mod) / d), mod
end

local function time_ms_of_time_float(float)
  if float == nil then return nil end
  return math.floor(float * 1000 + 0.5)
end

local function time_float_of_time_ms(ms)
  if ms == nil then return nil end
  return ms / 1000
end

local state =
  {
    osd = mp.create_osd_overlay("ass-events"),
    tick_timer = nil,
    tick_last_time = 0,                     -- when the last tick() was run
    media_filename,
    playback_time_ms,
    label_filename,
    label_file,
    mode,
    net_cursor,
    events, -- { {time_ms=3,moves={"U","D"},permutation={},colours={}}, ...}. permutation[net_id] = sticker_id at that net position right now
  }

local function colours_new()
  local colours = {}
  local colour_of_face_id = {"W", "O", "G", "R", "B", "Y"}
  for net_id = 1, 54 do
    --colours[net_id] = colour_of_face_id[cubelib.face_id_of_net_id(net_id)]
    colours[net_id] = ""
  end
  return colours
end

local function state_reset()
  state.media_filename = nil
  state.playback_time_ms = nil
  state.label_filename = nil
  if state.label_file then
    state.label_file:close()
  end
  state.label_file = nil
  state.mode = MODE_EDIT_MOVES
  state.net_cursor = 1
  state.events = {
    { time_ms = -1,
      moves = {},
      permutation = cubelib.Permutation.new(),
      colours = colours_new() }}
end

state_reset()

local function serialise_events(events)
  local permutation_id_of_permutation = {}
  local colours_id_of_colours = {}
  local serialisation = {permutations = {}, colours = {}, events = {}}
  for _, event in ipairs(events) do
    local permutation_id = permutation_id_of_permutation[event.permutation]
    if permutation_id == nil then
      table.insert(serialisation.permutations, event.permutation)
      permutation_id_of_permutation[event.permutation] = #serialisation.permutations
      permutation_id = #serialisation.permutations
    end
    local colours_id = colours_id_of_colours[event.colours]
    if colours_id == nil then
      table.insert(serialisation.colours, event.colours)
      colours_id_of_colours[event.colours] = #serialisation.colours
      colours_id = #serialisation.colours
    end
    table.insert(serialisation.events,
                 { time = time_float_of_time_ms(event.time_ms),
                   moves = event.moves,
                   permutation_id = permutation_id,
                   colours_id = colours_id })
  end
  return utils.format_json(serialisation)
end

local function deserialise_events(serial_string)
  local serialisation = utils.parse_json(serial_string)
  if serialisation == nil then return nil end
  local events = {}
  for _, sevent in ipairs(serialisation.events) do
    table.insert(events,
                 { time_ms = time_ms_of_time_float(sevent.time),
                   moves = sevent.moves,
                   permutation = serialisation.permutations[sevent.permutation_id],
                   colours = serialisation.colours[sevent.colours_id] })
  end
  local function event_time_ms_lt(e1, e2)
    return e1.time_ms < e2.time_ms
  end
  table.sort(events, event_time_ms_lt)
  return events
end

local function handle_load()
  if state.label_filename then
    local file = io.open(state.label_filename, "r")
    if file ~= nil then
      local serial_string = file:read("*all")
      file:close()
      local events = deserialise_events(serial_string)
      if events ~= nil then
        state.events = events
      end
    end
  end
end

local function handle_save()
  if state.label_filename then
    local serial_string = serialise_events(state.events)
    local file = io.open(state.label_filename, "w")
    if file ~= nil then
      mp.osd_message("Saved", 1.0)
      file:write(serial_string)
      file:close()
    end
  end
end

local function binary_search_last_le(events, time_ms)
  local lo, hi = 0, #events
  while lo < hi do
    local mid = hi - math.floor((hi - lo) / 2)
    if mid == 0 or events[mid].time_ms <= time_ms then
      lo = mid
    else
      hi = mid - 1
    end
  end
  return lo
end

local function events_moves_append(move)
  if not state.playback_time_ms then return nil end
  local idx = binary_search_last_le(state.events, state.playback_time_ms)
  local was_present = state.events[idx] and state.events[idx].time_ms == state.playback_time_ms
  if not was_present then
    table.insert(state.events,
                 idx + 1,
                 { time_ms = state.playback_time_ms,
                   moves = {},
                   permutation = state.events[idx].permutation,
                   colours = state.events[idx].colours })
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
    if was_present and moves[#moves] ~= MOVE_RESET then
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
  local function update_future_permutations()
    local i = idx
    while i <= #state.events do
      local colours = state.events[i - 1].colours
      local permutation = state.events[i - 1].permutation
      for _, move in ipairs(state.events[i].moves) do
        if move == MOVE_RESET then
          if i > idx then return end
          colours = colours_new()
          permutation = cubelib.Permutation.new()
        else
          local p2 = cubelib.Permutation.of_move_string_invert(move)
          assert(p2 ~= nil)
          permutation = p2 * permutation
        end
      end
      state.events[i].permutation = permutation
      state.events[i].colours = colours
      i = i + 1
    end
  end
  update_future_permutations()
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

local net_cursor_move_offsets = {h = {-1, 0}, j = {0, -1}, k = {0, 1}, l = {1, 0}}
local function net_cursor_move(key)
  local move_offset = net_cursor_move_offsets[key]
  assert(move_offset ~= nil)
  local net_id = state.net_cursor
  local net_face_id = cubelib.face_id_of_net_id(net_id)
  local net_face_net_x, net_face_net_y = face_net_position_of_face_id(net_face_id)
  local net_face_local_id = cubelib.face_local_id_of_net_id(net_id)
  local net_face_local_x, net_face_local_y = cubelib.face_local_coord_of_face_local_id(net_face_local_id)

  local new_net_x = net_face_net_x * 3 + net_face_local_x + 1 + move_offset[1]
  local new_net_y = net_face_net_y * 3 + net_face_local_y + 1 + move_offset[2]

  local new_net_face_net_x, new_net_face_local_x = divmod(new_net_x, 3)
  local new_net_face_net_y, new_net_face_local_y = divmod(new_net_y, 3)

  new_net_face_local_x = new_net_face_local_x - 1
  new_net_face_local_y = new_net_face_local_y - 1

  local new_net_face_id = face_id_of_face_net_position(new_net_face_net_x, new_net_face_net_y)
  if new_net_face_id == nil then return nil end
  local new_net_face_local_id = cubelib.face_local_id_of_face_local_coord(new_net_face_local_x, new_net_face_local_y)

  state.net_cursor = cubelib.net_id_of_face_id_and_face_local_id(new_net_face_id, new_net_face_local_id)
end

local function net_colour(key)
  if not state.playback_time_ms then return nil end
  local idx = binary_search_last_le(state.events, state.playback_time_ms)
  local event = state.events[idx]
  local new_colour = key:upper()
  event.colours[event.permutation[state.net_cursor]] = new_colour
  local new_net_cursor = state.net_cursor + 1
  while new_net_cursor <= 54 do
    if event.colours[event.permutation[new_net_cursor]] == "" then break end
    new_net_cursor = new_net_cursor + 1
  end
  if new_net_cursor <= 54 then
    state.net_cursor = new_net_cursor
  end
end

local function handle_seek(key)
  if not state.playback_time_ms then return nil end
  local idx = binary_search_last_le(state.events, state.playback_time_ms)
  if key == "<" then
    if state.events[idx].time_ms == state.playback_time_ms then
      idx = idx - 1
    end
  elseif key == ">" then
    idx = idx + 1
  else assert(false)
  end
  if state.events[idx] ~= nil then
    mp.set_property_number("playback-time", time_float_of_time_ms(state.events[idx].time_ms))
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

local ass_of_colour = { W = "FFFFFF", R = "0000FF", G = "00FF00", B = "FF0000", O = "0080FF", Y = "00FFFF" }

local function tick()
  msg.trace("tick")

  -- debug info
  local ass_debug = assdraw.ass_new()
  ass_debug:pos(0, 240)
  ass_debug:append(
    "{\\fnMonospace\\fs10\\q1\\bord2\\c&HB0B0B0&}"
  )
  ass_debug:append(string.format("mode: %s", utils.to_string(state.mode)))

  local ass_moves = assdraw.ass_new()
  local ass_net_cursor = assdraw.ass_new()
  local ass_stickers = assdraw.ass_new()
  if state.playback_time_ms then
    local idx = binary_search_last_le(state.events, state.playback_time_ms)

    assert(idx >= 1 and idx <= #state.events)

    ass_debug:append(string.format("\\Ncur time = %d ms, evt time = %d ms",
                                   state.playback_time_ms,
                                   state.events[idx].time_ms))

    -- moves
    if state.mode == MODE_EDIT_MOVES then
      ass_moves:new_event()
      ass_moves:pos(0, 0)
      ass_moves:append("{\\fs16\\an7\\bord2}")
      ass_moves:append("{\\alpha&HFF&}")
      ass_moves:append(table.concat(state.events[idx].moves, " "))
      if state.events[idx].time_ms == state.playback_time_ms then
        ass_moves:append("{\\1c&HFFFF00&}")
      else
        ass_moves:append("{\\1c&HFF00FF&}")
      end
      ass_moves:append("{\\1a&H80&\\bord0}")
      ass_moves:draw_start()
      ass_moves:rect_cw(-10000, 2, 5, 16)
      ass_moves:draw_stop()
    end
    ass_moves:new_event()
    ass_moves:pos(0, 0)
    ass_moves:append("{\\fs16\\an7\\bord2}")
    if state.events[idx].time_ms == state.playback_time_ms then
      ass_moves:append("{\\1c&HFFFF00&}")
    else
      ass_moves:append("{\\1c&HB0B0B0&}")
    end
    ass_moves:append(table.concat(state.events[idx].moves, " "))

    -- stickers
    for net_id = 1, 54 do
      local sticker_id = state.events[idx].permutation[net_id]
      local net_face_id = cubelib.face_id_of_net_id(net_id)
      local net_face_local_id = cubelib.face_local_id_of_net_id(net_id)
      local net_face_local_x, net_face_local_y = cubelib.face_local_coord_of_face_local_id(net_face_local_id)
      local net_face_net_x, net_face_net_y = face_net_position_of_face_id(net_face_id)
      local screen_x = 640 + 15 * ((net_face_net_x - 4) * 4 + net_face_local_x)
      local screen_y = 15 * ((2 - net_face_net_y) * 4 + 3 - net_face_local_y)
      if state.mode == MODE_EDIT_STICKERS and net_id == state.net_cursor then
        ass_net_cursor:new_event()
        ass_net_cursor:pos(screen_x, screen_y)
        ass_net_cursor:append("{\\3c&HFF00FF&\\1a&HFF&\\bord2}")
        ass_net_cursor:draw_start()
        ass_net_cursor:rect_cw(-7, -7, 7, 7)
        ass_net_cursor:draw_stop()
      end
      local colour = state.events[idx].colours[sticker_id]
      if colour ~= "" then
        ass_stickers:new_event()
        ass_stickers:pos(screen_x, screen_y)
        ass_stickers:append(string.format("{\\1c&H%s&\\1a&H40&\\bord0}", ass_of_colour[colour]))
        ass_stickers:draw_start()
        ass_stickers:rect_cw(-7, -7, 7, 7)
        ass_stickers:draw_stop()
      end
      ass_stickers:new_event()
      ass_stickers:pos(screen_x, screen_y)
      ass_stickers:append("{\\fs10\\an5\\1c&H808080\\bord0}")
      ass_stickers:append(string.format("%d", sticker_id))
    end
  end

  local ass = assdraw.ass_new()
  ass:append(ass_debug.text)
  ass:new_event()
  ass:append(ass_moves.text)
  ass:new_event()
  ass:append(ass_stickers.text)
  ass:new_event()
  ass:append(ass_net_cursor.text)

  state.osd.data = ass.text
  state.osd.z = 500
  state.osd:update()

  state.tick_last_time = mp.get_time()
end

local tick_delay = 0.03

-- Request that tick() is called (which typically re-renders the OSC).
-- The tick is then either executed immediately, or rate-limited if it was
-- called a small time ago.
function request_tick()
  if state.tick_timer == nil then
    state.tick_timer = mp.add_timeout(0, tick)
  end

  if not state.tick_timer:is_enabled() then
    local now = mp.get_time()
    local timeout = tick_delay - (now - state.tick_last_time)
    if timeout < 0 then
      timeout = 0
    end
    state.tick_timer.timeout = timeout
    state.tick_timer:resume()
  end
end

add_keystring("colour", "wrgboyWRGBOY")
add_keystring("cursor_move", "hjkl")
add_keystring("face", "furbldFURBLD")
add_keystring("slice", "MES")
add_keystring("rotate", "xyz")
add_keystring("move_reset", MOVE_RESET)
add_keystring("move_modifier", "'2")
add_keystring("help", "?")
add_keystring("seek", "<>")
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
        if map["seek"] then
          handle_seek(key)
        elseif state.mode == MODE_EDIT_MOVES then
          if key == "TAB" then
            state.mode = MODE_EDIT_STICKERS
          elseif (map["face"] or
                  map["slice"] or
                  map["rotate"] or
                  map["move_modifier"] or
                  map["move_reset"] or
                  key == "BS") and not ctrl and not alt then
            events_moves_append(key)
          end
        elseif state.mode == MODE_EDIT_STICKERS then
          if key == "TAB" then
            state.mode = MODE_EDIT_MOVES
          elseif map["cursor_move"] then
            net_cursor_move(key)
          elseif map["colour"] then
            net_colour(key)
          elseif key == "BS" or key == "x" then
            net_colour("")
          end
        end
        request_tick()
      end
      mp.add_forced_key_binding(keystring, nil, handler)
    end
  end
end

mp.add_forced_key_binding("Ctrl+s", nil, handle_save)

local function process_mbtn_left(e)
  --msg.info("process_mbtn_left")
end

local function process_mouse_move(e)
  --msg.info("process_mouse_move")
end

local function process_playback_time(name, val)
  local media_filename = mp.get_property("filename")
  msg.trace("process_playback_time", name, val, media_filename)
  if media_filename ~= state.media_filename then
    msg.info("reset state: change of filename")
    state_reset()
    if media_filename then
      state.media_filename = media_filename
      state.label_filename = media_filename .. ".cube-labels.json"
      handle_load()
    end
  end
  state.playback_time_ms = time_ms_of_time_float(val)
  request_tick()
end

mp.add_forced_key_binding("mbtn_left", nil, process_mbtn_left, {complex = true})
mp.add_forced_key_binding("mouse_move", nil, process_mouse_move)
mp.observe_property("playback-time", "number", process_playback_time)
