﻿-- status
-- Плагин для Tortilla mud client

local status = {}
function status.name()
  return 'Панель статусов'
end

local count = 0
function status.description()
  local p=props.cmdPrefix()
  local s = { 'Плагин создает панель с миниокнами, куда можно выводить дополнительную информацию.',
  'Добавляет команду '..p..'status {номер окна} {text} [{цвет}]',
  'Цвет - это не обязательный параметр. Он задается в формате клиента (см. справку #help color).',
  'Плагин повторяет функционал панели статусов мад-клиента jmc3.',
  'Он также умеет отчитывать время между тиками и выполнять команды за N секунд до тика.',
  'Количество миниокон: '..count..'.',
  'Настройки задаются в файле: '..getPath('config.lua')
  }
  return table.concat(s, '\r\n')
end

function status.version()
  return '1.07'
end

local r
local delta = 8
local panels = {}

local function render()
  local h = r:fontHeight()
  local w = (r:width() - delta*2 - (count-1)*delta) / count;
  local p = { x = delta, y = (r:height()-h)/2, height = h, width = w }
  for i=1,count do
    local t = panels[i]
    if t then
      p.color = t.color
      r:solidRect(p)
      r:textColor(t.tcolor)
      r:print(p, t.text)
    end
    p.x = p.x + w + delta
  end
end

local function cmdstr(t) 
  return "'"..props.cmdPrefix()..table.concat(t, " ").."'"
end

local function incparams(t)
  log("Некорретный набор параметров: "..cmdstr(t))
  return false
end

function status.syscmd(t)
  if t[1] ~= 'status' then
   return t
  end
  if #t ~= 3 and #t ~= 4 then
    return incparams(t)
  end
  local v = tonumber(t[2])
  if not v or v < 1 or v > count then
    return incparams(t)
  end
  local tcolor = props.paletteColor(7)
  local color = props.backgroundColor()
  if #t == 4 then
    tcolor, color = translateColors(t[4], tcolor, color)
    if not tcolor then
      return incparams(t)
    end
  end
  panels[v] = { text = tostring(t[3]), color = color, tcolor = tcolor }
  r:update()
  return nil
end

local ticker_on, ticker_window, ticker_seconds, ticker_restart
local ticker_panel = { text = '', tcolor = props.paletteColor(7), color = props.backgroundColor() }
local ticker_triggers = {}
local tickround_triggers = {}

local function set_ticker(t)
  if ticker_on then
    ticker_panel.text = t
    panels[ticker_window] = ticker_panel
    r:update()
  end
end

local counter, start_time

local function start_new_tick()
  tickround_triggers = {}
  for k,v in pairs(ticker_triggers) do
    tickround_triggers[k] = v
  end
  start_time = system.getTicks()
end

local function check_run_command(sec)
  if tickround_triggers[sec] then
    runCommand(tickround_triggers[sec])
    tickround_triggers[sec] = nil
  end
end

function status.tick()
  if start_time then
    local time = system.getTicks()
    if time >= start_time then
      counter = math.floor( (time - start_time) / 1000 )
      counter = ticker_seconds - counter
      if counter < 0 then counter = 0 end
    else
      counter = 0
    end
    check_run_command(counter+2)
    check_run_command(counter+1)
    check_run_command(counter)
    set_ticker(''..counter)
    if counter == 0 and ticker_restart then
      start_new_tick()
    end
  else
    counter = nil
  end
end

function status.connect()
  panels = {}
  set_ticker('ticker')
end

function status.disconnect()
  set_ticker('')
end

function status.init()
  local function term(t) terminate("Некорректый параметр '"..t.."', "..getPath('config.lua')) end
  ticker_on = false
  local t = loadTable('config.lua')
  if not t then terminate('Нет файла настроек '..getPath('config.lua')..'.') end
  if not t.position or (t.position ~= 'top' and t.position ~= 'bottom') then term('position') end
  if not t.count or type(t.count) ~= 'number' or t.count < 1 then term('count') end
  if t.ticker then
    if type(t.ticker) ~= 'string' and type(t.ticker) ~= 'table' then term('ticker') end
    if type(t.ticker) == 'string' and t.ticker == '' then term('ticker') end
    if type(t.ticker) == 'table' and #t.ticker == 0 then term('ticker') end
    if not t.ticker_seconds or type(t.ticker_seconds) ~= 'number' or t.ticker_seconds < 1 then term('ticker_seconds') end
    if not t.ticker_window or type(t.ticker_window) ~= 'number' or t.ticker_window < 1 or t.ticker_window > t.count then term('ticker_window') end
    if t.ticker_color and type(t.ticker_color) ~= 'string' then term('ticker_color') end
    local trigs = t.ticker
    if type(trigs) == 'string' then trigs = { trigs } end
    local fail = 0
    for _,s in pairs(trigs) do
      if not createTrigger(s, start_new_tick) then 
        log('Ошибка в триггере для тикера (работать не будет): '..s)
        fail = fail + 1
      end
    end
    if fail == #trigs then term('ticker') end
    ticker_restart = t.ticker_restart
    ticker_seconds = t.ticker_seconds
    ticker_window = t.ticker_window
    ticker_panel.tcolor, ticker_panel.color = translateColors(t.ticker_color, ticker_panel.tcolor, ticker_panel.color)
    ticker_on = true
  end
  if t.ticker_triggers then
    if type(t.ticker_triggers) ~= 'table' then term('ticker_triggers') end
    for sec,cmd in pairs(t.ticker_triggers) do
      if type(sec) ~= 'number' or type(cmd) ~= 'string' then
        log('Ошибка в триггере для тикера (работать не будет): '..tostring(s)..'->'..tostring(cmd))
      else
        ticker_triggers[sec] = cmd
      end
    end
  end
  count = t.count
  local font = props.currentFontHeight()+6
  local p = createPanel(t.position, font)
  r = p:setRender(render)
  r:setBackground(props.backgroundColor())
  r:textColor(props.paletteColor(7))
  r:select(props.currentFont())
  addCommand('status')
  set_ticker('ticker')
end

return status
