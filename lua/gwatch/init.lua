local M = {}
local config = require("gwatch.config")
local shown = false
local GWATCH_PATH = ""

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
	if GWATCH_PATH ~= "" and vim.fn.exepath(GWATCH_PATH) ~= "" then
		return true
	end

	GWATCH_PATH = getGwatchPath()
	if GWATCH_PATH ~= "" then
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
	GWATCH_PATH = getGwatchPath()
	if GWATCH_PATH ~= "" then
		return true
	end
	notify("Failed to initialize Gwatch: Go install failed.", ll.ERROR)
	return false
end

M.reload = function()
	package.loaded["gwatch.config"] = nil
	package.loaded["gwatch"] = nil
	require("gwatch")
end

M.setup = function(options)
	config.setup(options)
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
	if shown then
		return
	end
	shown = true
	-- What are the defaults?
	notify("Start gwatch", ll.INFO)
end

-- Stop the current gwatch instance
M.stop = function()
	if not shown then
		return
	end
	shown = false
	notify("Stop gwatch", ll.INFO)
end

ensureGwatch()

return M
