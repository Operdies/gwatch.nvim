local M = {}

M.term = {}
M.fw_handle = 0
M.term.opened = 0
M.term.buffer = -1
M.term.window_handle = 0
M.term.current_line = -1
M.term.chan = -1
M.borders = "single"

function M.fw_open(row, column)
	M.fw_close()
	local w = 0
	local h = -1
	local bp = { row, column }
	local bufnr = vim.api.nvim_create_buf(false, true)
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
	local config = require("gwatch.config")
	local width = config.options.windowWidth or 40
	local open_term_cmd = ":rightb" .. width .. "vsplit"
	vim.cmd(open_term_cmd)
	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, buf)
	local chan = vim.api.nvim_open_term(buf, {})
	vim.cmd("set scrollback=1")
	vim.cmd("setlocal nonu")
	vim.cmd("setlocal signcolumn=no")

	vim.keymap.set("n", "q", M.close_all, { silent = true, buffer = true, noremap = false })
	vim.keymap.set("t", "q", M.close_all, { silent = true, buffer = true, noremap = false })

	vim.cmd("wincmd p")
	M.term.opened = 1
	M.term.window_handle = win
	M.term.buffer = buf
	M.term.chan = chan
end

local function nilOrWhitespace(s)
	return s == nil or string.match(s, "^%s*(.-)%s*$") == ""
end

function M.write_to_term(message)
	if nilOrWhitespace(message) then
		return
	end
	M.term_open()
	vim.api.nvim_chan_send(M.term.chan, message)
end

function M.close_all()
	M.term_close()
	M.fw_close()
end

function M.fw_close()
	if M.fw_handle == 0 then
		return
	end
	vim.api.nvim_win_close(M.fw_handle, true)
	M.fw_handle = 0
end

function M.term_close()
	if M.term.window_handle == 0 then
		return
	end
	require("gwatch.runner").Stop()
	vim.api.nvim_win_close(M.term.window_handle, true)
	M.term.opened = 0
	M.term.window_handle = 0
	M.term.buffer = -1
	M.term.current_line = 0
	M.term.chan = -1
end

return M
