---
-- Battle.net package management extension
-- Copyright (c) 2014-2016 Blizzard Entertainment
---

cache = {}
cache.package_hostname = '***REMOVED***'
cache.folders  = { '.' }
cache.location_override = nil

local JSON = assert(loadfile 'json.lua')()

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


local function _get_user()
	if os.is('windows') then
		return os.getenv('USERNAME') or 'UNKNOWN'
	else
		return os.getenv('LOGNAME') or 'UNKNOWN'
	end
end


local function _get_workspace()
	if premake.api and premake.api.scope and premake.api.scope.workspace then
		return premake.api.scope.workspace.name
	end
	return 'unknown'
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

	-- ask if the server has it.
	local link_url = '/api/v1/link/' .. http.escapeUrlParam(name) .. '/' .. http.escapeUrlParam(version)
	local content, result_str, result_code = http.get(cache.package_hostname .. link_url)
	if not content then
		return nil
	end

	local info_tbl = JSON:decode(content)
	if not info_tbl.url then
		return nil
	end

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
			'X-Premake-Version: '   .. _PREMAKE_VERSION,
			'X-Premake-User: '      .. _get_user(),
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


function cache.get_variants(name, version)
	local result = {}

	-- test if version is a folder name.
	if os.isdir(version) then
		for i, dir in pairs(os.matchdirs(version .. '/*')) do
			local n, variant = string.match(dir, '(.+)[\\|/](.+)')
			result[variant] = 1
		end
		return result
	end

	-- test if we have the package locally.
	for i, folder in ipairs(cache.folders) do
		local location = _package_location(folder, name, version)
		if os.isdir(location) then
			for i, dir in pairs(os.matchdirs(location .. '/*')) do
				local n, variant = string.match(dir, '(.+)[\\|/](.+)')
				result[variant] = 1
			end
			return result
		end
	end

	-- if we don't want server queries, just return the local results.
	if (_OPTIONS['no-http']) then
		return result
	end

	-- Query the server for variant information.
	local file = '/archives?name=' .. http.escapeUrlParam(name) .. '&version=' .. http.escapeUrlParam(version)

	local content, result_str, result_code = http.get(cache.package_hostname .. file)
	if content then
		-- load content as json object.
		local variant_tbl = JSON:decode(content)

		for i, variant in pairs(variant_tbl) do
			variant = path.getbasename(variant)
			if (result[variant] ~= 1) then
				verbosef('Adding variant: ' .. variant)
				result[variant] = 1
			end
		end
	else
		premake.warn('A problem occured trying to contact %s.\n%s(%d).', cache.package_hostname, result_str, result_code)
	end

	return result
end


function cache.aliases(name)
	-- if we don't want server queries, just return the local results.
	if (_OPTIONS['no-http']) then
		return { realname = name, aliases  = {} }
	end

	-- querie server for alias information.
	local link = '/aliases?name=' .. http.escapeUrlParam(name)
	local content, result_str, result_code = http.get(cache.package_hostname .. link)
	if content then
		local alias_tbl = JSON:decode(content)
		return {
			realname = alias_tbl['RealName'],
			aliases  = alias_tbl['Aliases'],
		}
	else
		return {
			realname = name,
			aliases  = {}
		}
	end
end


function cache.download(name, version, variant)
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

	-- calculate standard file_url.
	local destination = location .. '.zip'
	local file        = http.escapeUrlParam(name) .. '/' .. http.escapeUrlParam(version) .. '/' .. http.escapeUrlParam(variant) .. '.zip'
	local file_url    = cache.package_hostname .. '/' .. file

	-- get link information from server.
	local link_url = '/link?name=' .. http.escapeUrlParam(name) .. '&version=' .. http.escapeUrlParam(version) .. '&variant=' .. http.escapeUrlParam(variant)
	local content, result_str, result_code = http.get(cache.package_hostname .. link_url)
	if content then
		local info_tbl = JSON:decode(content)
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
			'X-Premake-Version: '   .. _PREMAKE_VERSION,
			'X-Premake-User: '      .. _get_user(),
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
