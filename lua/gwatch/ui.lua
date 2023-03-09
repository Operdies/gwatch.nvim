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

local stdin_handler = function(_, _, _, _) end
function M.SetOnStdin(f)
	stdin_handler = f
end

function M.term_open()
	if M.term.opened ~= 0 then
		return
	end
	local options = require("gwatch.config").options()
	local width = options["window width"]
	local height = options["window height"]
	local pos = options["window position"]
	local openCmd = {
		left = ":lefta" .. width .. "vsplit",
		right = ":rightb" .. width .. "vsplit",
		top = ":abovel" .. height .. "split",
		bottom = ":belowr" .. height .. "split",
	}
	vim.cmd(openCmd[pos])
	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_get_current_win()

	vim.api.nvim_win_set_buf(win, buf)
	local term_opts = {}

	-- function OnInput(input, term, bufnr, data)
	term_opts.on_input = function(input, term, bufnr, data)
		stdin_handler(input, term, bufnr, data)
	end

	local chan = vim.api.nvim_open_term(buf, term_opts)
	vim.cmd("set scrollback=100")
	vim.cmd("setlocal nonu")
	vim.cmd("setlocal signcolumn=no")
	vim.cmd("norm G")

	vim.keymap.set("n", "<C-c>", M.close_all, { silent = true, buffer = true, noremap = false })

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

function M.dimensions()
	if M.term.window_handle == 0 then
		M.term_open()
	end
	return { width = vim.fn.winwidth(M.term.window_handle), height = vim.fn.winheight(M.term.window_handle)}
end

return M
