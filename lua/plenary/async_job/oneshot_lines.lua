local uv = vim.loop

local async = require("plenary.async")
local channel = async.control.channel

local OneshotLines = {}
OneshotLines.__index = OneshotLines

function OneshotLines:new()
  return setmetatable({
    _closed = false,

    _read_tx = nil,
    _read_rx = nil,

    handle = uv.new_pipe(false),
  }, self)
end

function OneshotLines:start()
  self._read_tx, self._read_rx = channel.oneshot()

  self.handle:read_start(function(err, data)
    self.handle:read_stop()

    assert(not err, err)
    self._read_tx(data)
  end)
end

function OneshotLines:close()
  self.handle:read_stop()
  self.handle:close()

  async.util.scheduler()
  self._closed = true
  print("Closed!")
end

function OneshotLines:iter()
  local _text = nil
  local _index = nil

  local get_next_text = function(previous)
    _index = nil

    local read = self._read_rx()
    if previous == nil and read == nil then
      return
    end

    _text = (previous or '') .. (read or '')
    if _text == nil then
      return
    end

    self:start()
    return _text
  end

  local next_value = nil
  next_value = function()
    if not _text then
      return nil
    end

    local start = _index
    _index = string.find(_text, "\n", _index, true)

    if _index == nil then
      _text = get_next_text(string.sub(_text, start or 1)) or ''
      return next_value()
    end

    _index = _index + 1

    return string.sub(_text, start or 1, _index - 2)
  end

  get_next_text()

  return function()
    async.util.scheduler()

    return next_value()
  end
end


return OneshotLines