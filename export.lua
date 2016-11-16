---
-- Battle.net package management extension
-- Copyright (c) 2014-2016 Blizzard Entertainment
---

local p = premake
local findUses

p.exportRule    = p.container.newClass("exportRule",    p.rule,    { "config" })
p.exportProject = p.container.newClass("exportProject", p.project, { "config" })


function p.exportRule.new(name)
	return p.container.new(p.exportRule, name)
end


function p.exportProject.new(name)
	return p.container.new(p.exportProject, name)
end


local function validateName(name)
	if type(name) == "table" then
		if #name == 0 then
			return nil
		end
		if #name > 1 then
			error("exportsettings cannot take more than one argument", 1)
		end
		name = name[1]
	end

	if type(name) ~= "string" then
		error("exportsettings argument must be a string", 1)
	end

	if #name <= 0 then
		return nil
	end

	name = name:lower()
	if name ~= 'compile' and name ~= 'link' then
		error("exportsettings can only be 'compile' or 'link'.", 1)
	end

	return name
end


function exportsettings(name)
	name = validateName(name)

	local scope = premake.api.scope.current
	if scope then
		if scope.class == p.project then
			if not name then
				error('invalid name for export scope')
			end
			return p.api._setContainer(p.exportProject, name)
		end
		if scope.class == p.rule then
			if not name then
				error('invalid name for export scope')
			end
			return p.api._setContainer(p.exportRule, name)
		end
		if scope.class == p.exportProject then
			if not name then
				return p.api._setContainer(p.exportProject.parent)
			end
			return p.api._setContainer(p.exportProject, name)
		end
		if scope.class == p.exportRule then
			if not name then
				return p.api._setContainer(p.exportRule.parent)
			end
			return p.api._setContainer(p.exportRule, name)
		end

		error('not in a valid scope, current scope == ' .. scope.class.name)
	else
		error('not in a valid scope, current scope == nil')
	end
end


local function spairs(t)
	-- collect the keys
	local keys = {}
	for k in pairs(t) do
		table.insert(keys, k)
	end
	table.sort(keys)

	-- return the iterator function
	local i = 0
	return function()
		i = i + 1
		if keys[i] then
			return keys[i], t[keys[i]]
		end
	end
end


local function copyBlock(block)
	local clone = {}
	for k, v in pairs(block) do
		if k == "_criteria" then
			clone[k] = table.deepcopy(v)
		else
			clone[k] = v
		end
	end

	-- The blocks may have invalid infos reserved for the first ones
	if clone.filename then
		clone.filename = nil
		clone._basedir = clone.basedir
		clone.basedir = nil
	end

	return clone
end


local function applyBlocks(blocklist, ctx, blocks)
	for _, block in ipairs(blocks) do
		if criteria.matches(block._criteria, ctx.terms) then
			local newBlock = copyBlock(block)
			table.insert(blocklist, newBlock)
		end
	end
end


local function getpackage(ctx, name)
	local p = ctx.workspace.package_cache[name]
	if not p then
		error("Package '" .. name .. "' was not imported, but the project '" .. ctx.project.name .. "' has a dependency on it.")
	end
	return p
end

local function enumprojects(ctx, name)
	-- split import string.
	local packageName, projectName = name:match("([^.]+)%.([^.]+)")
	if not packageName then
		packageName = name
		projectName = '*'
	end

	-- find the package
	local pkg = getpackage(ctx, packageName)
	if #pkg.projects > 0 then
		local pattern = projectName:gsub('%*', '.*')

		local projects = {}
		for _, v in ipairs(pkg.projects) do
			if v.name:find(pattern) then
				table.insert(projects, v)
			end
		end

		-- return the iterator function
		local i = 0
		return function()
			i = i + 1
			if i <= #projects then
				return pkg, projects[i]
			end
		end
	else
		local i = 0
		return function()
			i = i + 1
			if i <= 1 then
				return pkg, nil
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Rules
-------------------------------------------------------------------------------

local function applyRuleBlocks(blocklist, ctx, name)
	local rule = p.global.getRule(name)
	if rule then
		for exp in p.container.eachChild(rule, p.exportRule) do
			applyBlocks(blocklist, ctx, exp.blocks)
		end
	end
end


local function findRules(blocklist, ctx, block)
	if block.rules and #block.rules > 0 then
		for _, v in ipairs(block.rules) do
			applyRuleBlocks(blocklist, ctx, v)
		end
	end
end


-------------------------------------------------------------------------------
-- Collection methods.
-------------------------------------------------------------------------------

local function getCompileUses(result, ctx, block)
	-- forward declarations.
	local findExposedUsesIn
	local findUses

	local function apply(pkg, prj)
		local n = pkg.name
		if prj ~= nil then
			n = n .. '.' .. prj.name
		end
		if not result[n] then
			result[n] = {
				package = pkg,
				project = prj
			}
			if prj ~= nil then
				for _, block in ipairs(prj.blocks) do
					if criteria.matches(block._criteria, ctx.terms) then
						findUses(ctx, block.use_exposed)
					end
				end
			end
		end
	end

	function findExposedUsesIn(ctx, name)
		for pkg, prj in enumprojects(ctx, name) do
			apply(pkg, prj)
		end
	end

	function findUses(ctx, blocks)
		if blocks then
			for _, v in ipairs(blocks) do
				findExposedUsesIn(ctx, v)
			end
		end
	end

	-- recursively go through all the uses blocks.
	findUses(ctx, block.use_exposed)
	findUses(ctx, block.use_private)
end


local function getLinkUses(result, ctx, block)

	local function apply(pkg, prj)
		local n = pkg.name
		if prj ~= nil then
			n = n .. '.' .. prj.name
		end
		if not result[n] then
			result[n] = {
				package = pkg,
				project = prj
			}
			if prj ~= nil then
				for _, block in ipairs(prj.blocks) do
					if criteria.matches(block._criteria, ctx.terms) then
						getLinkUses(result, ctx, block)
					end
				end
			end
		end
	end

	local function findUsesIn(ctx, name)
		for pkg, prj in enumprojects(ctx, name) do
			apply(pkg, prj)
		end
	end

	if block.use_exposed then
		for _, v in ipairs(block.use_exposed) do
			findUsesIn(ctx, v)
		end
	end

	if block.use_private then
		for _, v in ipairs(block.use_private) do
			findUsesIn(ctx, v)
		end
	end
end


-------------------------------------------------------------------------------
-- Apply methods.
-------------------------------------------------------------------------------


local function applyPackageCompiles(blocklist, ctx, pkg)
	if not ctx.__compileImports[pkg] then
		ctx.__compileImports[pkg] = true

		block = {}
		block._origin     = blocklist
		block.includedirs = pkg.auto_includes(ctx)
		block.bindirs     = pkg.auto_bindirs(ctx)
		if #block.includedirs > 0 or #block.bindirs > 0 then
			table.insert(blocklist, block)
		end
	end
end


local function applyPackageLinks(blocklist, ctx, pkg)
	if not ctx.__linkImports[pkg] then
		ctx.__linkImports[pkg] = true

		block = {}
		block._origin   = blocklist
		block.links     = pkg.auto_links(ctx)
		block.libdirs   = pkg.auto_libdirs(ctx)

		if #block.links > 0 or #block.libdirs > 0 then
			table.insert(blocklist, block)
		end
	end
end


local function applyProjectExports(blocklist, ctx, prj, mode)
	for exp in p.container.eachChild(prj, p.exportProject) do
		if exp.name == mode then
			applyBlocks(blocklist, ctx, exp.blocks)
		end
	end
end

-------------------------------------------------------------------------------
-- premake override.
-------------------------------------------------------------------------------

premake.override(p.oven, "finishConfig", function(base, ctx)
	-- run base first.
	base(ctx)

	-- add all our import blocks.
	if ctx.project then
		ctx.hasLinkStep   = (ctx.kind == p.SHAREDLIB) or (ctx.kind == p.CONSOLEAPP) or (ctx.kind == p.WINDOWEDAPP)

		local blocksCopy = table.shallowcopy(ctx._cfgset.blocks)
		local blocklist = ctx._cfgset.blocks

		local compileUses = {}
		local linkUses    = {}

		for _, block in pairs(blocksCopy) do
			if ctx.hasLinkStep and block.use_exposed and #block.use_exposed > 0 then
				local key = "use_exposed." .. ctx.project.name
				p.warnOnce(key, 'Project "' .. ctx.project.name .. '" has a linkstep, but uses use_exposed to define its dependencies.')
			end

			getCompileUses(compileUses, ctx, block)

			if ctx.hasLinkStep then
				getLinkUses(linkUses, ctx, block)
			end

			findRules(blocklist, ctx, block)
		end

		ctx.__compileImports = {}
		for _, u in spairs(compileUses) do
			applyPackageCompiles(blocklist, ctx, u.package)
			if u.project then
				applyProjectExports(blocklist, ctx, u.project, 'compile')
			end
		end

		if ctx.hasLinkStep then
			ctx.__linkImports    = {}
			for _, u in spairs(linkUses) do
				applyPackageLinks(blocklist, ctx, u.package)
				if u.project then
					applyProjectExports(blocklist, ctx, u.project, 'link')
				end
			end
		end
	end
end)
