---
-- Battle.net package management extension
-- Copyright (c) 2014-2016 Blizzard Entertainment
---

package = package or {}

---
-- initializer.
---
function package:initialize(operation)
	-- Remember the current _SCRIPT and working directory so we can restore them.
	local cwd = os.getcwd()
	local script = _SCRIPT
	local scriptDir = _SCRIPT_DIR

	-- Store current scope.
	local scope = premake.api.scope.current

	-- go through each variant that is loaded, and execute the initializer.
	for name, variant in pairs(self.variants) do
		if type(variant) == 'table' and variant.initializer then
			-- Set the new _SCRIPT and working directory
			_SCRIPT     = variant.script
			_SCRIPT_DIR = variant.location
			os.chdir(variant.location)

			-- store current package context.
			local previous_package = package.current
			package.current = variant

			-- execute the callback
			verbosef('initialize(%s, %s, %s)', self.name, name, operation or 'nil')
			variant.initializer('project')

			-- and clear it, so we don't do it again in the future.
			variant.initializer = nil

			-- restore package context.
			package.current = previous_package
		end
	end

	-- restore current scope.
	premake.api.scope.current = scope

	-- Finally, restore the previous _SCRIPT variable and working directory
	_SCRIPT = script
	_SCRIPT_DIR = scriptDir
	os.chdir(cwd)
end


---
-- load all the variant compatible with a specific config.
---
function package:loadvariants(cfg)
	local options = self.variants
	local check   = { }

	-- Check if there is a build_custom_variant method, and use that.
	if type(bnet.build_custom_variant) == 'function' then
		table.insertflat(check, bnet.build_custom_variant(cfg, options))
	end

	-- Check the default variants.
	table.insert(check, _build_variant(cfg))						-- Check for [os]-[arch]-[compiler]-[config]
	table.insert(check, _build_variant(cfg, false, false, true))	-- Check for [os]-[arch]-[compiler]
	table.insert(check, _build_variant(cfg, false, true, false))	-- Check for [os]-[arch]-[config]
	table.insert(check, _build_variant(cfg, false, true, true))		-- Check for [os]-[arch]
	table.insert(check, _build_variant(cfg, true, true, true))		-- Check for [os]
	table.insert(check, 'noarch')
	table.insert(check, 'universal')

	-- load all those variants, if they exists.
	local result = {}
	for _, v in ipairs(check) do
		local r = self:loadvariant(v)
		if r then
			table.insert(result, r)
		end
	end

	-- we must initialize here, so newly loaded variants get a chance to initialize.
	self:initialize('loadvariants')

	return result
end


---
-- load a specific variant if not already loaded.
---
function package:loadvariant(variant)
	if self.variants[variant] == 1 then
		local directory = cache.download(self.name, self.version, variant)

		local v = {
			package  = self,
			location = directory
		}

		-- does it contain an include directory?
		local directory_include = path.join(directory, 'include')
		if os.isdir(directory_include) then
			verbosef(' INC ' .. directory_include)

			v.includes = v.includes or {}
			table.insert(v.includes, 'include')
		end

		-- does it contain an bin directory?
		local directory_bin = path.join(directory, 'bin')
		if os.isdir(directory_bin) then
			verbosef(' BIN ' .. directory_bin)
			_make_executable(directory_bin)

			v.bindirs = v.bindirs or {}
			table.insert(v.bindirs, 'bin')
		end

		-- does it contain an runtime directory?
		local directory_runtime = path.join(directory, 'runtime')
		if os.isdir(directory_runtime) then
			verbosef(' BIN ' .. directory_runtime)
			_make_executable(directory_runtime)

			v.bindirs = v.bindirs or {}
			table.insert(v.bindirs, 'runtime')
		end

		-- does it contain a library directory?
		local directory_lib = path.join(directory, 'lib')
		if os.isdir(directory_lib) then
			verbosef(' LIB ' .. directory_lib)

			v.libdirs = v.libdirs or {}
			table.insert(v.libdirs, 'lib')

			v.links = v.links or {}
			table.insertflat(v.links, _get_lib_files(directory_lib))
		end

		-- on mac does it contain a framework directory?
		if os.get() == 'macosx' then
			local directory_fw = path.join(directory, 'framework')
			if os.isdir(directory_fw) then
				verbosef(' FRAMEWORK ' .. directory_fw)

				v.libdirs = v.libdirs or {}
				table.insert(v.libdirs, 'framework')

				v.links = v.links or {}
				table.insertflat(v.links, _get_fw_folders(directory_fw))
			end
		end

		-- does it contain a package premake directive?
		local path_premake = path.join(directory, 'premake5-package.lua')
		if os.isfile(path_premake) then
			-- store current package context.
			local previous_package = package.current
			package.current = v

			-- load the script.
			verbosef('dofile(%s)', path_premake)
			v.script      = path_premake;
			v.initializer = dofile(path_premake)

			-- restore package context.
			package.current = previous_package
		end

		-- register result.
		self.variants[variant] = v
	end

	return self.variants[variant];
end


