---
-- Battle.net package management extension
-- Copyright (c) 2014-2016 Blizzard Entertainment
---

cache = {}
cache.folders           = { '.' }
cache.location_override = nil
cache.package_hostname  = nil
cache.package_servers   = {
	'http://***REMOVED***',
	'http://***REMOVED***'
}

newoption {
	trigger = 'no-http',
	description = 'Disable http queries to package server.'
}


function cache.use_env_var_location()
	local folder = os.getenv('PACKAGE_CACHE_PATH')

	if folder and os.isdir(folder) then
		cache.location_override = folder
		return true
	end

	return false
end


function cache.get_servers()
	if cache.package_hostname then
		return { cache.package_hostname }
	end
	return cache.package_servers
end


function cache.get_folder()
	if cache.location_override then
		return cache.location_override
	end

	local folder = os.getenv('PACKAGE_CACHE_PATH')
	if folder then
		return folder
	else
		return path.join(bnet.build_dir, 'package_cache')
	end
end


local function _package_location(...)
	local location = path.join(...)

	location = path.normalize(location)
	location = location:gsub('%s+', '_')
	location = location:gsub('%(', '_')
	location = location:gsub('%)', '_')
	return location
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
	if premake.api and premake.api.scope and premake.api.scope.workspace then
		return premake.api.scope.workspace.name
	end
	return '<unknown>'
end


function cache.get_package_v2_folder(name, version)
	-- test if version is a folder name.
	if os.isdir(version) then
		local filename = path.join(version, 'premake5-meta.lua')
		if os.isfile(filename) then
			verbosef(' LOCAL: %s', version)
			return version
		end
	end

	-- test if we have the package locally.
	for i, folder in ipairs(cache.folders) do
		local location = _package_location(folder, name, version)
		local filename = path.join(location, 'premake5-meta.lua')
		if os.isfile(filename) then
			verbosef(' LOCAL: %s', location)
			return location
		end
	end

	-- test if we downloaded it already.
	local location = _package_location(cache.get_folder(), name, version)
	local filename = path.join(location, 'premake5-meta.lua')
	if os.isfile(filename) then
		verbosef(' CACHED: %s', location)
		return location
	end

	-- if we don't want server queries, we stop here.
	if (_OPTIONS['no-http']) then
		return nil
	end

	-- ask if any of the servers has it? First hit gets it.
	for _, hostname in ipairs(cache.get_servers()) do
		local link_url = '/api/v1/link/' .. http.escapeUrlParam(name) .. '/' .. http.escapeUrlParam(version)
		local content, result_str, result_code = http.get(hostname .. link_url)
		if content then
			local info_tbl = json.decode(content)
			if info_tbl.url then

				if type(info_tbl.state) == "string" and info_tbl.state:lower() ~= 'active' then
					premake.warn('"%s/%s" is marked "%s", consider upgrading to a known good version.', name, version, info_tbl.state)
				end

				-- create destination folder.
				os.mkdir(location)

				-- download to packagecache/name-version.zip.
				local destination = _package_location(cache.get_folder(), name .. '-' .. version .. '.zip')

				print(' DOWNLOAD: ' .. info_tbl.url)
				local result_str, response_code = http.download(info_tbl.url, destination,
				{
					headers  = {
						'X-Premake-Version: '   .. _get_version(),
						'X-Premake-User: '      .. _get_user(),
						"X-Premake-Machine: "   .. _get_computer(),
						'X-Premake-Workspace: ' .. _get_workspace()
					},
					progress = iif(_OPTIONS.verbose, http.reportProgress, nil)
				})

				if result_str ~= "OK" then
					premake.error('Download of %s failed (%d)\n%s', info_tbl.url, response_code, result_str)
				end

				-- Unzip it
				verbosef(' UNZIP   : %s', destination)
				zip.extract(destination, location)
				os.remove(destination)
				return location
			end
		end
	end

	return nil
end


function cache.get_variants(name, version)
	local result = {}

	-- test if version is a folder name.
	if os.isdir(version) then
		for i, dir in pairs(os.matchdirs(version .. '/*')) do
			local n, variant = string.match(dir, '(.+)[\\|/](.+)')
			result[variant] = {
				location = dir
			}
		end
		return result
	end

	-- test if we have the package locally.
	for i, folder in ipairs(cache.folders) do
		local location = _package_location(folder, name, version)
		if os.isdir(location) then
			for i, dir in pairs(os.matchdirs(location .. '/*')) do
				local n, variant = string.match(dir, '(.+)[\\|/](.+)')
				result[variant] = {
					location = dir
				}
			end
			return result
		end
	end

	-- if we don't want server queries, just return the local results.
	if (_OPTIONS['no-http']) then
		return result
	end

	-- Query the server for variant information.
	for _, hostname in ipairs(cache.get_servers()) do
		local file = '/archives?name=' .. http.escapeUrlParam(name) .. '&version=' .. http.escapeUrlParam(version)

		local content, result_str, result_code = http.get(hostname .. file)
		if content then
			-- load content as json object.
			local variant_tbl = json.decode(content)

			for i, variant in pairs(variant_tbl) do
				variant = path.getbasename(variant)
				if not result[variant] then
					verbosef('Adding variant: ' .. variant .. ' from ' .. hostname)
					result[variant] = {
						server = hostname
					}
				end
			end
		else
			premake.warn('A problem occured trying to contact %s.\n%s(%d).', hostname, result_str, result_code)
		end
	end

	return result
end


function cache.aliases(name)
	-- if we don't want server queries, just return the local results.
	if (_OPTIONS['no-http']) then
		return { realname = name, aliases  = {} }
	end

	-- querie servers for alias information.
	for _, hostname in ipairs(cache.get_servers()) do
		local link = '/aliases?name=' .. http.escapeUrlParam(name)
		local content, result_str, result_code = http.get(hostname .. link)
		if content then
			local alias_tbl = json.decode(content)
			return {
				realname = alias_tbl['RealName'],
				aliases  = alias_tbl['Aliases'],
			}
		end
	end

	return {
		realname = name,
		aliases  = {}
	}
end


function cache.download(hostname, name, version, variant)
	-- first see if we can find the package locally.
	for i, folder in pairs(cache.folders) do
		local location = _package_location(folder, name, version, variant)
		if os.isdir(location) then
			verbosef('LOCAL: %s', location)
			return location
		end
	end

	-- then try the package cache.
	local location = _package_location(cache.get_folder(), name, version, variant)
	if os.isdir(location) then
		verbosef('CACHED: %s', location)
		return location
	end

	-- if we don't have a host name, we can't download it.
	if not hostname then
		premake.error("Package '" .. name .. "/" .. version .. "' not found on any server.")
	end

	-- calculate standard file_url.
	local destination = location .. '.zip'
	local file        = http.escapeUrlParam(name) .. '/' .. http.escapeUrlParam(version) .. '/' .. http.escapeUrlParam(variant) .. '.zip'
	local file_url    = hostname .. '/' .. file

	-- get link information from server.
	local link_url = '/link?name=' .. http.escapeUrlParam(name) .. '&version=' .. http.escapeUrlParam(version) .. '&variant=' .. http.escapeUrlParam(variant)
	local content, result_str, result_code = http.get(hostname .. link_url)
	if content then
		local info_tbl = json.decode(content)
		if info_tbl.url then
			file_url = info_tbl.url
		end

		if type(info_tbl.state) == "string" and info_tbl.state:lower() ~= 'active' then
			premake.warn('"%s/%s" is marked "%s", consider upgrading to a known good version.', name, version, info_tbl.state)
		end
	end

	-- Download file.
	print(' DOWNLOAD: ' .. file_url)
	os.mkdir(path.getdirectory(destination))
	local result_str, response_code = http.download(file_url, destination,
	{
		headers  = {
			'X-Premake-Version: '   .. _get_version(),
			'X-Premake-User: '      .. _get_user(),
			"X-Premake-Machine: "   .. _get_computer(),
			'X-Premake-Workspace: ' .. _get_workspace()
		},
		progress = iif(_OPTIONS.verbose, http.reportProgress, nil)
	})

	if result_str ~= "OK" then
		premake.error('Download of %s failed (%d)\n%s', file_url, response_code, result_str)
	end

	-- Unzip it
	verbosef(' UNZIP   : %s', destination)
	zip.extract(destination, location)
	os.remove(destination)
	return location
end


-- execute some telemetry...

premake.override(premake.main, "preBake", function (base)
	if http then
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
		cache.telemetry = telemetry.send(url, data)
	end

	base()
end)

premake.override(premake.main, "postAction", function (base)
	if cache.telemetry ~= nil then
		telemetry.wait(cache.telemetry)
	end

	base()
end)
