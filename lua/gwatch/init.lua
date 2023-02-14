local M = {}
local cfg = require("gwatch.config")
local runner = require("gwatch.runner")
local ui = require("gwatch.ui")
local shown = false

local ll = vim.log.levels
local notify = function(msg, level)
	if level == nil then
		level = ll.INFO
	end
	vim.notify(msg, level)
end

local getGwatchPath = function()
	local path = vim.fn.exepath("gwatch")
	if path ~= "" then
		return path
	end
	local gobin = vim.fn.expand("$GOBIN")
	if gobin ~= "" then
		path = vim.fn.exepath(gobin .. "./gwatch")
		if path ~= "" then
			return path
		end
	end
	path = vim.fn.exepath(vim.fn.expand("$HOME") .. "/go/bin/gwatch")
	return path
end

local ensureGwatch = function()
	local config = require("gwatch.config").options
	if config.gwatchPath and config.gwatchPath ~= "" and vim.fn.exepath(config.gwatchPath) ~= "" then
		return true
	end

	config.gwatchPath = getGwatchPath()
	if config.gwatchPath ~= "" then
		return true
	end

	local gopath = vim.fn.exepath("go")
	if gopath == "" then
		notify("Failed to initialize Gwatch: Go is not installed.", ll.ERRRO)
		return false
	end
	local cmd = { gopath, "install", "github.com/operdies/gwatch@latest" }
	notify("Gwatch not installed. Installing with " .. vim.inspect(cmd))
	vim.fn.system(cmd)
	config.gwatchPath = getGwatchPath()
	if config.gwatchPath ~= "" then
		return true
	end
	notify("Failed to initialize Gwatch: Go install failed.", ll.ERROR)
	return false
end

local user_opts = nil
M.reload = function()
	runner.Stop()
	package.loaded["gwatch.runner"] = nil
	package.loaded["gwatch.ui"] = nil
	package.loaded["gwatch.config"] = nil
	package.loaded["gwatch"] = nil
	require("gwatch").setup(user_opts)
end

M.setup = function(options)
	user_opts = options
	cfg.setup(options)
end

-- Show or hide the window
M.toggle = function()
	if shown then
		M.stop()
	else
		M.start()
	end
end

-- Start gwatch in the current project root
M.start = function()
	runner.Watch()
	shown = true
end

-- Stop the current gwatch instance
M.stop = function()
	runner.Stop()
	ui.close_all()
	shown = false
end

ensureGwatch()

return M
