---
-- Battle.net package management extension
-- Copyright (c) 2014-2016 Blizzard Entertainment
---

	packageman = {}

	local project = premake.project
	local import_filter = {}

--
-- Api keywords
--
	premake.api.register {
		name = 'includedependencies',
		scope = 'config',
		kind = 'tableorstring'
	}

	premake.api.register {
		name = 'linkdependencies',
		scope = 'config',
		kind = 'tableorstring'
	}

	premake.api.register {
		name = 'bindirdependencies',
		scope = 'config',
		kind = 'tableorstring'
	}

	premake.api.register {
		name = 'copybindependencies',
		scope = 'config',
		kind = 'tableorstring',
	}

	premake.api.register {
		name = 'copybintarget',
		scope = 'config',
		kind = 'path',
		tokens = true,
		pathVars = true,
	}


--
-- New API.
--
	premake.api.register {
		name = 'use_exposed',
		scope = 'config',
		kind = 'list:string'
	}

	premake.api.register {
		name = 'use_private',
		scope = 'config',
		kind = 'list:string'
	}


--
-- packageman methods.
--
	local function packageman_getcache(pkg, name, cfg)
		local c = pkg._cache[name]
		if not c then
			return nil
		end
		return c[cfg.name]
	end

	local function packageman_setcache(pkg, name, cfg, value)
		pkg._cache[name] = pkg._cache[name] or {}
		pkg._cache[name][cfg.name] = value
	end


	local function packageman_setup(name, version, available_variants)
		local pkg = {
			name     = name,
			version  = version,
			variants = available_variants,
			projects = {},
			_cache   = {},
		}
		setmetatable(pkg, { __index = package })

		local function getproperties(pkg, name, cfg, join)
			local result = packageman_getcache(pkg, name, cfg)
			if result then
				return result
			end

			result = {}
			local cacheresult = true
			for _, v in ipairs(pkg:loadvariants(cfg)) do
				local items = v[name]
				if type(items) == "function" then
					items = items(cfg)
					cacheresult = false
				end
				if items then
					for _, value in ipairs(items) do
						value = premake.detoken.expand(value, cfg.environ, {pathVars=true}, v.location)
						if join then
							table.insert(result, path.join(v.location, value))
						else
							table.insert(result, value)
						end
					end
				end
			end

			if cacheresult then
				packageman_setcache(pkg, name, cfg, result)
			end

			return result
		end

		-- setup auto-resolve for includes.
		pkg.auto_includes = function(cfg)
			return getproperties(pkg, 'includes', cfg, true)
		end

		-- setup auto-resolve for includepath.
		pkg.auto_includepath = function(cfg)
			local r = pkg.auto_includes(cfg)
			if (r and #r > 0) then
				return r[1]
			end
			return nil
		end

		-- setup auto-resolve for links.
		pkg.auto_links = function(cfg)
			return getproperties(pkg, 'links', cfg, false)
		end

		-- setup auto-resolve for libdirs.
		pkg.auto_libdirs = function(cfg)
			return getproperties(pkg, 'libdirs', cfg, true)
		end

		-- setup auto-resolve for bindirs.
		pkg.auto_bindirs = function(cfg)
			return getproperties(pkg, 'bindirs', cfg, true)
		end

		-- setup auto-resolve for binpath.
		pkg.auto_binpath = function(cfg)
			local r = pkg.auto_bindirs(cfg)
			if (r and #r > 0) then
				return r[1]
			end
			return nil
		end

		return pkg
	end

---
-- Manually create a package
---
	local function packageman_createpackage(wks, name)
		local p = wks.package_cache[name]
		if p then
			error("Package '" .. name .. "' already exists in the solution.")
		end

		local variant = {}
		local pkg = packageman_setup(name, nil, {noarch = variant})
		wks.package_cache[name] = pkg

		variant.package  = pkg
		variant.location = _SCRIPT_DIR
		return pkg
	end


---
-- Load a single v2 package.
---
	local function packageman_loadpackage_v2(dir)
		if not dir or not os.isdir(dir) then
			error('invalid argument in loadpackage.')
		end

		if package.current then
			error('Packages cannot load other packages, only the top-level project can do that')
		end

		-- make dir absolute.
		dir = path.getabsolute(dir)

		-- load the meta data file.
		local env = {}
		local filename = path.join(dir, 'premake5-meta.lua');
		if not os.isfile(filename) then
			error('Package in folder "' .. dir .. '" does not have a premake5-meta.lua script.')
		end
		local untrusted_function, message = loadfile(filename, 't', env)
		if not untrusted_function then
			error(message)
		end

		-- now execute it, so we can get the data.
		local result, meta = pcall(untrusted_function)
		if not result then
			error(meta)
		end

		if not meta.name then
			error('meta data table needs to at least specify a name.')
		end
		-- create package in existing package system.
		local wks = premake.api.scope.workspace
		local pkg = packageman_createpackage(wks, meta.name)
		pkg.variants.noarch.includes = meta.includedirs
		pkg.variants.noarch.links    = meta.links
		pkg.variants.noarch.defines  = meta.defines
		pkg.variants.noarch.location = dir
		pkg.variants.noarch.script   = filename
		packageman._loaded = packageman._loaded or { }

		if meta.premake ~= nil then
			pkg.variants.noarch.initializer = function()
				if not packageman._loaded[dir] then
					packageman._loaded[dir] = true
				else
					premake.api._isIncludingExternal = true
				end
				dofile(meta.premake)
				premake.api._isIncludingExternal = nil
			end
		end

		return pkg
	end


---
-- Import a single package.
---
	local function packageman_importpackage(name, version)
		-- create the --use-<name> option.
		local optionname = 'use-' .. name
		premake.option.add({
			trigger     = optionname,
			value       = '<path>',
			default     = version,
			description = 'Path to ' .. name .. ' package.',
			category    = 'Packages'
		})

		-- option overrides version from table.
		version = _OPTIONS[optionname] or version

		-- first see if this is a version 2.0 package.
		local pkgv2_dir = cache.get_package_v2_folder(name, version)
		if (pkgv2_dir ~= nil) then
			local pkg = packageman_loadpackage_v2(pkgv2_dir)
			if (pkg.name ~= name) then
				error('Package "' .. name .. ' - ' .. version .. '" name does not match the name specified in the premake5-meta.lua script.')
			end
			return pkg
		end

		-- else try a version 1 package.
		local available_variants = cache.get_variants(name, version)
		if next(available_variants) == nil then
			error('Package "' .. name .. ' - ' .. version .. '" has no variants. It might not exist.')
		end

		local pkg = packageman_setup(name, version, available_variants)

		-- now load the noarch and/or universal variants.
		pkg:loadvariant('noarch')
		pkg:loadvariant('universal')

		return pkg
	end


---
-- Import a set of packages.
---
	function import(importTable)
		if not importTable then
			return nil
		end

		if package.current then
			error('Packages cannot import other package, only the top-level workspace can do that')
		end

		-- we always need to have a workspace.
		if not premake.api.scope.workspace then
			error("no workspace in scope.", 3)
		end

		-- Store current scope.
		local scope = premake.api.scope.current
		local wks = premake.api.scope.workspace

		-- import packages.
		local init_table = {}
		for name, version in pairs(importTable) do
			local alias_table = cache.aliases(name)
			local realname    = alias_table.realname
			local aliases     = alias_table.aliases

			if not wks.package_cache[realname] then
				local pkg = packageman_importpackage(realname, version)
				init_table[realname] = pkg;

				wks.package_cache[realname] = pkg
				for _, alias in ipairs(aliases) do
					verbosef("ALIAS: '%s' aliased to '%s'.", realname, alias)
					wks.package_cache[alias] = pkg
				end
			end
		end

		-- initialize.
		for _, p in pairs(init_table) do
			p:initialize('import')
		end

		-- restore current scope.
		premake.api.scope.current = scope
	end


---
-- Load & Import a v2 package.
---
	function loadpackage(dir)
		local pkg = packageman_loadpackage_v2(dir)
		pkg:initialize()
		return pkg
	end

---
-- Import lib filter for a set of packages.
---
	function importlibfilter(table)
		if not table then
			return nil
		end

		-- import packages.
		for name, filter in pairs(table) do
			if not import_filter[name] then
				import_filter[name] = filter
			end
		end
	end


---
--- Gets the default import filter
---
	local function default_import_filter(name)
		if import_filter[name] then
			return import_filter[name]
		end
		return nil
	end

---
--- resolve packages, internal method.
---
	local function packageman_resolvepackages(ctx)

		local function getpackage(wks, name)
			local p = wks.package_cache[name]
			if not p then
				local prjname = iif(ctx.project, ctx.project.name, ctx.name)
				error("Package '" .. name .. "' was not imported, but the project '" .. prjname .. "' has a dependency on it.")
			end
			return p
		end

		local function sortedpairs(t)
			-- collect all the keys for entries that are not numbers.
			-- and store the values for entries that are numbers.
			local keys = {}
			local values = {}
			for k, v in pairs(t) do
				if tonumber(k) ~= nil then
					table.insert(values, v)
				else
					table.insert(keys, k)
				end
			end

			-- sort the keys.
			table.sort(keys)

			-- return the iterator function
			local i = 0
			local n = #values
			return function()
				i = i + 1
				if (i <= n) then
					return values[i], nil
				else
					local k = keys[i-n]
					if k then
						return k, t[k]
					end
				end
			end
		end

		if ctx.packages_resolved then
			return
		end

		-- resolve package includes.
		if ctx.includedependencies then
			for name,_ in sortedpairs(ctx.includedependencies) do
				local p = getpackage(ctx.workspace, name)
				for _, dir in ipairs(p.auto_includes(ctx)) do
					table.insertkeyed(ctx.includedirs, dir)
				end
			end
		end

		-- resolve package binpath.
		if ctx.bindirdependencies then
			for name,_ in sortedpairs(ctx.bindirdependencies) do
				local p = getpackage(ctx.workspace, name)
				for _, dir in ipairs(p.auto_bindirs(ctx)) do
					table.insertkeyed(ctx.bindirs, dir)
				end
			end
		end

		-- resolve package includes.
		if ctx.copybindependencies then
			local seperator = package.config:sub(1,1)
			local info = premake.config.gettargetinfo(ctx)
			local targetDir = ctx.copybintarget or info.directory

			for name, value in sortedpairs(ctx.copybindependencies) do
				local p = getpackage(ctx.workspace, name)
				for _, dir in pairs(p.auto_bindirs(ctx)) do
					local src = project.getrelative(ctx.project, dir)
					local dst = project.getrelative(ctx.project, targetDir)

					local command = string.format('{COPY} "%s" "%s"',
						path.translate(src, seperator),
						path.translate(dst, seperator))

					table.insert(ctx.postbuildcommands, command)
				end
			end
		end

		-- resolve package links.
		if ctx.linkdependencies then
			for name, value in sortedpairs(ctx.linkdependencies) do
				local filter = nil
				if type(value) == 'table' then
					filter = _create_filter(value)
				else
					filter = _create_filter(default_import_filter(name))
				end

				local p = getpackage(ctx.workspace, name)

				local links = filter(p.auto_links(ctx))
				for _, link in ipairs(links) do
					table.insertkeyed(ctx.links, link)
				end
				table.insertflat(ctx.libdirs, p.auto_libdirs(ctx))
			end
		end

		ctx.packages_resolved = true
	end


---
--- inject package resolver into premake.action.call
---
	premake.override(premake.action, 'call', function(base, name)
		print('Resolving Packages...')
		verbosef('Package cache: %s', cache.get_folder())

		for sln in premake.global.eachSolution() do
			for prj in premake.solution.eachproject(sln) do
				if not prj.external then
					verbosef("Resolving '%s'...", prj.name)

					if _ACTION == 'xcode' then
						if not cfg then
							cfg = prj
						end
						packageman_resolvepackages(prj)
					end

					for cfg in project.eachconfig(prj) do
						packageman_resolvepackages(cfg)
					end
				end
			end
		end

		base(name)
	end)


---
-- shortcut for if you need both include & link dependencies
---
	function usedependencies(table)
		includedependencies(table)
		linkdependencies(table)
	end


---
-- get a previously imported package by name.
---
	function package.get(name)
		if not premake.api.scope.workspace then
			error("No workspace in scope.", 3)
		end

		local wks = premake.api.scope.workspace
		local p = wks.package_cache[name]
		if not p then
			error("Package was not imported; use 'import { ['" .. name .. "'] = 'version' }'.")
		end
		return p
	end


---
-- override 'workspace' so that we can initialize a package cache.
---
	premake.override(premake.workspace, 'new', function(base, name)
		local wks = base(name)
		wks.package_cache = wks.package_cache or {}
		return wks
	end)

---
-- override 'project' so that when a package defines a new project we initialize it with some default values.
---
	premake.override(premake.project, 'new', function(base, name, parent)
		local prj = base(name, parent)
		if not prj.package then
			if package.current then
				-- set package on project.
				prj.package = package.current.package
				table.insert(prj.package.projects, prj)

				-- set some default package values.
				prj.blocks[1].targetdir = bnet.lib_dir
				prj.blocks[1].objdir    = path.join(bnet.obj_dir, name)
				prj.blocks[1].location  = path.join(bnet.projects_dir, 'packages')

			elseif parent ~= nil then
				-- set package on project.
				prj.package = packageman_createpackage(parent, name)
				prj.package.variants.noarch.links = { name }

				table.insert(prj.package.projects, prj)
			end
		end
		return prj
	end)
