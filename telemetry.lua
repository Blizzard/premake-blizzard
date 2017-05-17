---
-- Battle.net package management extension
-- Copyright (c) 2014-2016 Blizzard Entertainment
---

local p = premake

if http == nil then
	return
end

local function _get_version()
	return _PREMAKE_VERSION .. " (" .. _PREMAKE_COMMIT .. ")"
end


local function _get_user()
	return telemetry.getusername() or os.getenv('USERNAME') or os.getenv('LOGNAME') or '<unknown>'
end


local function _get_computer()
	return telemetry.gethostname() or os.getenv('COMPUTERNAME') or os.getenv('HOSTNAME') or '<unknown>'
end


local function _get_workspace()
	if p.api and p.api.scope and p.api.scope.workspace then
		return p.api.scope.workspace.name
	end
	return '<unknown>'
end


p.override(p.main, "preBake", function (base)
	local url = "http://***REMOVED***/api/v1/telemetry"

	-- if it's semver, then add entry into 'official' channel.
	if premake.isSemVer(_PREMAKE_VERSION) then
		url = url .. "?app=premake&version=" .. http.escapeUrlParam(_PREMAKE_VERSION)
	else
		-- otherwise add it to the 'test' channel.
		url = url .. "?app=premake-test&version=" .. http.escapeUrlParam(_get_version())
	end

	local data = {
		"Content-Type: application/json",
		"Accept: application/json",
		"X-Premake-User: "      .. _get_user(),
		"X-Premake-Machine: "   .. _get_computer(),
		"X-Premake-Workspace: " .. _get_workspace(),
		"X-Premake-Platform: "  .. os.host(),
		"X-Premake-WorkDir: "   .. _WORKING_DIR,
		"X-Premake-CmdLine: "   .. table.concat(_ARGV, ' '),
	}
	p.__telemetry = telemetry.send(url, data)

	-- run base function.
	base()
end)

p.override(p.main, "postAction", function (base)
	base()
	if p.__telemetry ~= nil then
		telemetry.wait(p.__telemetry)
	end
end)
