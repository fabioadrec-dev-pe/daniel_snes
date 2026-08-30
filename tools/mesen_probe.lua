-- Headless Mesen probe for title + Start. Writes dumps next to the ROM.

local out_dir = "/home/fabio/snes_game/build"
local log_path = out_dir .. "/mesen_probe.txt"
local logf = io.open(log_path, "w")

local function w(s)
  s = tostring(s)
  if logf then
    logf:write(s .. "\n")
    logf:flush()
  end
  if emu.log then
    emu.log(s)
  end
end

local function dump_enum(name, t)
  if type(t) ~= "table" then
    w(name .. " is " .. type(t))
    return
  end
  local keys = {}
  for k, v in pairs(t) do
    keys[#keys + 1] = tostring(k) .. "=" .. tostring(v)
  end
  table.sort(keys)
  w(name .. ":")
  for i = 1, #keys do
    w("  " .. keys[i])
  end
end

w("probe start")
dump_enum("emu.memType", emu.memType)
dump_enum("emu.eventType", emu.eventType)

local mem = nil
if emu.memType then
  mem = emu.memType.snesMemory
    or emu.memType.snesWorkRam
    or emu.memType.workRam
    or emu.memType.cpuDebug
    or emu.memType.cpu
end

local cg = nil
if emu.memType then
  cg = emu.memType.snesCgRam
    or emu.memType.snesCgram
    or emu.memType.cgram
    or emu.memType.palette
end

local vram = nil
if emu.memType then
  vram = emu.memType.snesVideoRam
    or emu.memType.snesVram
    or emu.memType.vram
end

w("picked mem=" .. tostring(mem) .. " cg=" .. tostring(cg) .. " vram=" .. tostring(vram))

local function rb(addr)
  if not mem then
    return -1
  end
  local ok, v = pcall(emu.read, addr, mem)
  if ok then
    return v
  end
  ok, v = pcall(emu.read, addr, mem, false)
  if ok then
    return v
  end
  return -1
end

local function rw(addr)
  local lo = rb(addr)
  local hi = rb(addr + 1)
  if lo < 0 or hi < 0 then
    return -1
  end
  return lo + hi * 256
end

local function save_png(name)
  local ok, png = pcall(emu.takeScreenshot)
  if not ok or type(png) ~= "string" or #png < 32 then
    w("screenshot failed for " .. name .. " type=" .. type(png))
    return
  end
  local path = out_dir .. "/" .. name
  local f = io.open(path, "wb")
  if not f then
    w("cannot write " .. path)
    return
  end
  f:write(png)
  f:close()
  w("wrote " .. path .. " bytes=" .. #png)
end

local function dump(tag)
  w("==== " .. tag .. " ====")
  w(string.format("game_state=%d cam_x=%d nmi_col_need=%d map_cols=%d pl_x=%d pl_y=%d n_enemies=%d",
    rb(2), rw(47), rb(51), rw(31), rw(56), rw(58), rb(35)))
  w(string.format("INIDISP($80)=$%02X TM($80)=$%02X NMITIMEN($80)=$%02X",
    rb(0x2100), rb(0x212C), rb(0x4200)))
  if cg then
    local c0 = pcall(function()
      return emu.read(0, cg) + emu.read(1, cg) * 256
    end)
    local ok, val = pcall(function()
      return emu.read(0, cg) + emu.read(1, cg) * 256
    end)
    if ok then
      w(string.format("CGRAM0=$%04X", val))
    else
      w("CGRAM0 read failed")
    end
  end
end

local frame = 0
local start_sent = false

local function on_frame()
  frame = frame + 1
  if frame == 120 then
    dump("title")
    save_png("mesen_title.png")
  end
  if frame >= 125 and frame <= 130 then
    pcall(emu.setInput, 0, { start = true })
    start_sent = true
  elseif frame == 131 then
    pcall(emu.setInput, 0, { start = false })
  end
  if frame == 200 then
    dump("after_start")
    save_png("mesen_play.png")
    if logf then
      logf:close()
    end
    emu.stop(0)
  end
end

local ev = emu.eventType and (emu.eventType.endFrame or emu.eventType.nmi or emu.eventType.startFrame)
if ev then
  emu.addEventCallback(on_frame, ev)
  w("callback registered ev=" .. tostring(ev))
else
  w("no eventType; stopping")
  emu.stop(2)
end
