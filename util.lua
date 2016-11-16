---
-- Battle.net package management extension
-- Copyright (c) 2014-2016 Blizzard Entertainment
---

newoption {
	trigger = "compiler",
	value	 = "gcc44",
	description = "Select which compiler to use for package system"
}


if not _OPTIONS['compiler'] then
	if os.get() == 'linux' then
		_OPTIONS['compiler'] = 'gcc44'
	elseif os.get() == 'windows' then
		_OPTIONS['compiler'] = 'vc2010'
	else
		_OPTIONS['compiler'] = 'clang'
	end
end


function _build_os(ctx)
	local var = ctx.system or premake.action.current().os or os.get()

	if var == 'windows' then
		var = "win32"
	elseif var == 'macosx' then
		var = "darwin"
	end

	return var
end


function _build_compiler(ctx)
	local var = _ACTION

	if var == "vs2010" then
		return "vc100"
	elseif var == "vs2012" then
		return "vc110"
	elseif var == "vs2013" then
		return "vc120"
	elseif var == "vs2015" then
		return "vc140"
	elseif var == "vs2017" then
		return "vc141"
	end

	if _OPTIONS['compiler'] then
		return _OPTIONS['compiler']
	elseif os.get() == 'linux' then
		return "gcc44"
	elseif os.get() == 'macosx' then
		return "clang"
	end

	return var
end


function _build_arch(ctx)
	local var = ctx.architecture

	if ctx.architecture == 'x86' then
		var = "i386"
	end

	if ctx.system == 'orbis' or ctx.system == 'durango' then
		return nil
	end

	return var
end


function _build_config(ctx)
	local var = ctx.buildcfg

	if var == "Debug" then
		var = "debug"
	elseif var == "Release" then
		var = "release"
	elseif var == "Public" then
		var = "public"
	end

	return var
end


function _build_variant(ctx, dontIncludeArch, dontIncludCompiler, dontIncludeConfig)

	local var = _build_os(ctx)

	local compiler = _build_compiler(ctx)
	local arch = _build_arch(ctx)
	local config = _build_config(ctx)

	if not dontIncludeArch and arch and #arch > 0 then
		var = var .. "-" .. arch
	end

	if not dontIncludCompiler and compiler and #compiler > 0 then
		var = var .. "-" .. compiler
	end

	if not dontIncludeConfig and config and #config > 0 then
		var = var .. "-" .. config
	end

	return var
end


function _copy_to_bin(cfg, file)
	local file_name = path.getname(file)
	local dest = path.join(bnet.bin_dir, file_name)

	dest = premake.detoken.expand(dest, cfg.environ, {paths=true,pathVars=true}, cfg._basedir)

	local dir = path.getdirectory(dest)
	os.mkdir(dir)

	--print("Copying file " .. file .. " to " .. dest)
	os.copyfile(file, dest)

	return dest
end


function _make_executable(directory_bin)
	if os.get() == "linux" or os.get() == 'macosx' then
		for num, file in pairs(os.matchfiles(path.join(directory_bin, '*'))) do
			os.execute("chmod +x " .. file)
		end
	end
end

---
-- private helper function
---
function _match_link(filename, match)
	if type(match) == 'function' then
		return match(filename)
	end
	return string.match(filename, match:lower())
end


---
-- help filter to link only those libs that are mentioned.
---
function _create_filter(t)
	if t then
		return function(l)
			local matches = {}
			local nonmatches = {}
			local all_index = nil

			for k, link in ipairs(l) do
				local filename = path.getname(link):lower()
				for index, match in ipairs(t) do
					if match == '*' then
						all_index = index
					elseif _match_link(filename, match) then
						if matches[index] then
							table.insert(matches[index], link)
						else
							matches[index] = {link}
						end
						break
					else
						table.insert(nonmatches, link)
					end
				end
			end

			if all_index then
				matches[all_index] = nonmatches
			end

			local linres = {}

			for key, val in ipairs(matches) do
				if t[key] == '*' then
					table.insertflat(linres, val)
				elseif #val > 0 then
					table.insert(linres, val[1])
				end
			end

			return linres;
		end
	else
		return function(l)
			return l
		end
	end
end


function _get_so_searchstring(val)
	if os.get() == 'windows' then
		return path.join(val, "*.dll")
	elseif os.get() == 'linux' then
		return path.join(val, "*.so*")
	else
		return path.join(val, "*.dylib")
	end
end


function _get_lib_files(dir)
	if type(dir) == 'string' then
		if os.get() == 'windows' then
			return os.matchfiles(path.join(dir, '*.lib'))
		elseif os.get() == 'linux' then
			return table.join(os.matchfiles(path.join(dir, 'lib*.a')), os.matchfiles(path.join(dir, 'lib*.so*')))
		else
			return table.join(os.matchfiles(path.join(dir, 'lib*.a')), os.matchfiles(path.join(dir, 'lib*.dylib*')))
		end
	elseif type(dir) == 'table' then
		local result = {}
		for _, val in ipairs(dir) do
			result = table.join(result, _get_lib_files(val))
		end
		return result
	else
		return {}
	end
end


function _get_fw_folders(dir)
	if os.get() == 'macosx' then
		local pattern = path.join(dir, '*.framework')
		return os.matchdirs(pattern)
	else
		return {}
	end
end



--
-- TableOrString data kind.
--
	local function mergeTableOrString(field, current, value, processor)
		result = {}
		for k, v in pairs(current) do
			if type(v) == 'string' then
				table.insert(result, v)
			elseif type(v) == 'table' then
				result[k] = v
			end
		end

		for k, v in pairs(value) do
			if type(v) == 'string' then
				table.insert(result, v)
			elseif type(v) == 'table' then
				result[k] = v
			end
		end

		return result
	end

	local function storeTableOrString(field, current, value, processor)
		if type(value) ~= "table" then
			return { value }
		end
		if current then
			return mergeTableOrString(field, current, value, processor)
		else
			return value
		end
	end

	premake.field.kind("tableorstring", {
		store = storeTableOrString,
		merge = mergeTableOrString,
		compare = function(field, a, b, processor)
			if a == nil or b == nil or #a ~= #b then
				return false
			end
			for k, v in pairs(a) do
				if not processor(field, a[k], b[k]) then
					return false
				end
			end
			return true
		end
	})
