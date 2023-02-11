local M = {}
local config = require("gwatch.config").options

M.term = {}
M.fw_handle = 0
M.term.opened = 0
M.term.buffer = -1
M.term.window_handle = 0
M.term.current_line = -1
M.term.chan = -1
M.borders = "single"

local namespace_name = "gwatch.nvim"

function M.fw_open(row, column, message, ok)
	M.fw_close()
	local namespace_id = vim.api.nvim_create_namespace(namespace_name)
	local w = 0
	local h = -1
	local bp = { row, column }
	local bufnr = vim.api.nvim_create_buf(false, true)
	for line in message:gmatch("([^\n]*)\n?") do
		h = h + 1
		w = math.max(w, string.len(line))
		vim.api.nvim_buf_set_lines(bufnr, h, h + 1, false, { line })
	end
	M.fw_handle = vim.api.nvim_open_win(bufnr, false, {
		relative = "win",
		width = w + 1,
		height = h,
		bufpos = bp,
		focusable = false,
		style = "minimal",
		border = M.borders,
	})
end

function M.term_open()
	if M.term.opened ~= 0 then
		return
	end
	local open_term_cmd = ":rightb" .. config.windowWidth .. "vsplit"
	vim.cmd(open_term_cmd)
	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, buf)
	local chan = vim.api.nvim_open_term(buf, {})
	vim.cmd("set scrollback=1")
	vim.cmd("setlocal nonu")
	vim.cmd("setlocal signcolumn=no")
	vim.keymap.set("n", "q", M.term_close, { silent = true, buffer = true, noremap = false })
	vim.keymap.set("t", "q", M.term_close, { silent = true, buffer = true, noremap = false })

	vim.cmd("wincmd p")
	M.term.opened = 1
	M.term.window_handle = win
	M.term.buffer = buf
	M.term.chan = chan
end

function M.write_to_term(message, ok)
	M.term_open()

	local h = M.term.current_line or -1

	for line in message:gmatch("([^\n]*)\n?") do
		h = h + 1
		vim.api.nvim_chan_send(M.term.chan, line)
		vim.api.nvim_chan_send(M.term.chan, "\n\r")
	end
	vim.api.nvim_chan_send(M.term.chan, "\n\r")
	M.term.current_line = h
end

function M.close_all()
	M.fw_close()
	M.clear_virtual_text()
	M.term_close()

	M.close_api()
end

function M.fw_close()
	if M.fw_handle == 0 then
		return
	end
	vim.api.nvim_win_close(M.fw_handle, true)
	M.fw_handle = 0
end

function M.clear_virtual_text()
	local ns = vim.api.nvim_create_namespace(namespace_name)
	vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
end

function M.term_close()
	if M.term.window_handle == 0 then
		return
	end
	vim.api.nvim_win_close(M.term.window_handle, true)
	M.term.opened = 0
	M.term.window_handle = 0
	M.term.buffer = -1
	M.term.current_line = 0
	M.term.chan = -1
end

function M.send_api(message, ok)
	local d = {}
	d.message = message
	if ok then
		d.status = "ok"
	else
		d.status = "error"
	end
	local listeners = require("sniprun.api").listeners

	if type(next(listeners)) == "nil" then
		print("Sniprun: No listener registered")
	end

	for _, f in ipairs(listeners) do
		f(d)
	end
end

function M.close_api()
	local listeners = require("sniprun.api").closers
	for _, f in ipairs(listeners) do
		f()
	end
end

-- M.term_open()
-- M.write_to_term("Hello, buf", true)
-- for i = 1, 1000 do
-- 	local l = i
-- 	M.write_to_term("Hello, buf" .. i, true)
-- end
return M
