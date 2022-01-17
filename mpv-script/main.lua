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
    events_moves, -- { {time=3,moves={"U","D"}}, ...}
    events_stickers, -- { {time=0, stickers={"WRGBOY?" x 9 for U,"WRGBOY?" x 9 for L, ...FRBD...}} }
    cached_permutation, -- sticker is events_stickers[time][cached_permutation[time][position]]
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
  state.events_moves = {{time = 0, moves = {}}}
  state.events_stickers = {}
  state.cached_permutation = {{time = 0, permutation = {}}}
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
  local idx = binary_search_last_le(state.events_moves, state.playback_time)
  local was_present = state.events_moves[idx] and state.events_moves[idx].time == state.playback_time
  if not was_present then
    idx = idx + 1
    table.insert(state.events_moves, idx, {time = state.playback_time, moves = {}})
  end
  local moves = state.events_moves[idx].moves
  if move == "BS" then
    if was_present then
      if #moves > 0 then
        table.remove(moves)
      else
        table.remove(state.events_moves, idx)
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
end

local keymap = {}
function add_keystring(name, str)
  for i = 1, #str do
    local c = str:sub(i,i)
    keymap[c] = keymap[c] or {}
    table.insert(keymap[c], name)
    keymap[c][name] = true
  end
  msg.info(utils.to_string(keymap))
end

function escape_ass(s)
  return s:gsub("\\n", " "):gsub("\\$", ""):gsub("{","\\{")
end

function rerender()
  msg.trace("rerender")

  -- debug info
  state.osd.data =
    "\n{\\pos(320,240)\\fs10\\bord2\\c&HB0B0B0&}mode: " ..
    utils.to_string(state.mode) ..
    "\\Nevents: " ..
    escape_ass(utils.to_string(state.events_moves))

  -- moves
  if state.playback_time then
    state.osd.data = state.osd.data .. "\n{\\pos(0,0)}"
    local moves_idx = binary_search_last_le(state.events_moves, state.playback_time)
    if state.events_moves[moves_idx] then
      if state.events_moves[moves_idx].time == state.playback_time then
        state.osd.data = state.osd.data .. "{\\c&HFFFF00&}"
      else
        state.osd.data = state.osd.data .. "{\\c&HB0B0B0&}"
      end
      state.osd.data = state.osd.data .. table.concat(state.events_moves[moves_idx].moves, " ") .. " |"
    end
  end

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
