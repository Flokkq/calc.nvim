local M = {}

local MAX_HISTORY = 1000
local persist_path = vim.fn.stdpath('data') .. '/calc_history.json'
local var_persist_path = vim.fn.stdpath('data') .. '/calc_vars.json'

local ns = vim.api.nvim_create_namespace('calculator')

M.history       = {}
M.history_index = 0
M.last_result   = nil

local function load_history()
  if vim.fn.filereadable(persist_path) == 1 then
    local lines = vim.fn.readfile(persist_path)
    local ok, tbl = pcall(vim.fn.json_decode, lines[1])
    if ok and type(tbl) == 'table' then
      M.history = tbl
      M.history_index = #tbl + 1
    end
  end
end
load_history()

local reserved_symbols = {}
for k in pairs(math) do
  reserved_symbols[k] = true
end
reserved_symbols.random = true
reserved_symbols.math   = true

local sandbox = {}
setmetatable(sandbox, {
  __index = function(_, k)
    if math[k] then
      return math[k]
    end
    if k == 'random' then
      return math.random
    end
    return rawget(sandbox, k)
  end,
  __newindex = function(_, k, v)
    rawset(sandbox, k, v)
  end,
})
sandbox.math   = math
sandbox.random = math.random

local function load_vars()
  if vim.fn.filereadable(var_persist_path) == 1 then
    local lines = vim.fn.readfile(var_persist_path)
    local ok, tbl = pcall(vim.fn.json_decode, lines[1])
    if ok and type(tbl) == 'table' then
      for k, v in pairs(tbl) do
        sandbox[k] = v
      end
    end
  end
end
load_vars()

local function save_history()
  local json = vim.fn.json_encode(M.history)
  vim.fn.writefile({json}, persist_path)
end

local function save_vars()
  local tbl = {}
  for k, v in pairs(sandbox) do
    if not reserved_symbols[k] then
      tbl[k] = v
    end
  end
  vim.fn.writefile({vim.fn.json_encode(tbl)}, var_persist_path)
end

vim.api.nvim_create_autocmd('VimLeavePre', { callback = save_history })
vim.api.nvim_create_autocmd('VimLeavePre', { callback = save_vars })

local function eval_live(buf)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local expr = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ''
  if expr == '' then return end

  if expr:match('^%s*[%a_][%w_]*%s*=') then
    return
  end

  local fn, err = load('return ' .. expr, 'calculator', 't', sandbox)
  if not fn then
    vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
      virt_text     = {{' Error: ' .. err, 'ErrorMsg'}},
      virt_text_pos = 'eol',
    })
    return
  end

  local ok, result = pcall(fn)
  if not ok then
    vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
      virt_text     = {{' Error: ' .. result, 'ErrorMsg'}},
      virt_text_pos = 'eol',
    })
  else
    M.last_result = result
    vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
      virt_text     = {{'= ' .. tostring(result), 'Comment'}},
      virt_text_pos = 'eol',
    })
  end
end

local function eval_commit(buf, win)
  local expr = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ''
  if expr == '' then return end

  local var_name = expr:match('^%s*([%a_][%w_]*)%s*=')
  if var_name and reserved_symbols[var_name] then
    vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
      virt_text     = {{' Error: cannot override reserved symbol "'..var_name..'"', 'ErrorMsg'}},
      virt_text_pos = 'eol',
    })
    return
  end

  local is_assign = var_name ~= nil

  local chunk, err
  if is_assign then
    chunk, err = load(expr, 'calculator', 't', sandbox)
  else
    chunk, err = load('return ' .. expr, 'calculator', 't', sandbox)
  end

  if not chunk then
    vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
      virt_text     = {{' Error: ' .. err, 'ErrorMsg'}},
      virt_text_pos = 'eol',
    })
    return
  end

  local ok, result = pcall(chunk)
  if not ok then
    vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
      virt_text     = {{' Error: ' .. result, 'ErrorMsg'}},
      virt_text_pos = 'eol',
    })
  else
    if not is_assign then
      M.last_result = result
      vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
        virt_text     = {{'= ' .. tostring(result), 'Comment'}},
        virt_text_pos = 'eol',
      })
    end

    table.insert(M.history, expr)
    if #M.history > MAX_HISTORY then
      table.remove(M.history, 1)
    end
    M.history_index = #M.history + 1

    vim.schedule(function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {''})
      vim.api.nvim_buf_set_option(buf, 'modified', false)
      vim.api.nvim_win_set_cursor(win, {1, 0})
    end)
  end
end

local function show_history(buf, step)
  if #M.history == 0 then return end
  M.history_index = M.history_index + step
  if M.history_index < 1 then
    M.history_index = #M.history
  elseif M.history_index > #M.history then
    M.history_index = 1
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { M.history[M.history_index] })
  vim.api.nvim_win_set_cursor(0, {1, #M.history[M.history_index]})
  vim.api.nvim_buf_set_option(buf, 'modified', true)
end

function M.open()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, 'buftype',   'nofile')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'swapfile',  false)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {''})

  local width = math.floor(vim.o.columns * 0.5)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    style    = 'minimal',
    border   = 'rounded',
    width    = width,
    height   = 1,
    row      = math.floor((vim.o.lines - 1) / 2),
    col      = math.floor((vim.o.columns - width) / 2),
  })
  vim.api.nvim_win_set_option(win, 'winfixheight', true)
  vim.cmd('startinsert')

  vim.api.nvim_buf_attach(buf, false, {
    on_lines = function()
      eval_live(buf)
    end,
  })

  vim.keymap.set('i', '<CR>', function()
    eval_commit(buf, win)
  end, {buffer = buf, noremap = true})

  vim.keymap.set('n', '<Tab>',   function() show_history(buf,  1) end,
    {buffer = buf, noremap = true})
  vim.keymap.set('n', '<S-Tab>', function() show_history(buf, -1) end,
    {buffer = buf, noremap = true})

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  vim.keymap.set({'i','n'}, '<C-c>', close, {buffer = buf, nowait = true})
  vim.keymap.set('n', 'q',           close, {buffer = buf, noremap = true})

  vim.keymap.set({'i','n'}, '<C-y>', function()
    if M.last_result == nil then
      vim.api.nvim_echo({{'No result to yank', 'ErrorMsg'}}, false, {})
    else
      vim.fn.setreg('"', tostring(M.last_result))
      vim.api.nvim_echo({{'Yanked: ' .. tostring(M.last_result), 'None'}}, false, {})
    end
  end, {buffer = buf, noremap = true})
end

function M.fuzzy_history()
  vim.ui.select(M.history, { prompt = 'Calculator History' }, function(item)
    if not item then return end
    M.open()
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { item })
    vim.api.nvim_win_set_cursor(0, { 1, #item })
    vim.api.nvim_buf_set_option(buf, 'modified', true)
  end)
end

return M
