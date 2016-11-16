---
-- Battle.net package management extension
-- Copyright (c) 2014-2016 Blizzard Entertainment
---

local p = premake


p.api.register {
		name = "unity",
		scope = "project",
		kind = "number"
	}


function _write_unity_file(prj, id, files)
	local filename = path.join(prj.location, prj.name, string.format("Unity%02d.cpp", id))
	local location = path.getdirectory(filename)

	local buf = buffered.new()
	buffered.writeln(buf, "// GENERATED, DON'T MODIFY")
	buffered.writeln(buf, "")

	local pch = {}
	for cfg in p.project.eachconfig(prj) do
		if not cfg.flags.NoPCH and not pch[cfg.pchheader] then
			buffered.writeln(buf, '#include "' .. cfg.pchheader .. '"')
			pch[cfg.pchheader] = true
		end
	end

	for _, file in ipairs(files) do
		local fn = path.getrelative(location, file)
		buffered.writeln(buf, '#include "' .. fn .. '"')
	end

	buffered.writeln(buf, "")
	local content = buffered.tostring(buf)
	buffered.close(buf)

	os.mkdir(location)
	local f, err = os.writefile_ifnotequal(content, filename);
	if (f < 0) then
		error(err, 0)
	elseif (f > 0) then
		printf("Generated %s...", p.project.getrelative(prj, filename))
	end

	return filename
end


function _generate_unity_files(prj, files, count)

	local id = 1
	local fileList = {}

	local addFile = function(cfg, fname)
		if not files[fname] then
			local fcfg = p.fileconfig.new(fname, prj)
			fcfg.vpath = path.join("Unity Files", fcfg.name)

			files[fname] = fcfg
			table.insert(files, fcfg)
		end
		p.fileconfig.addconfig(files[fname], cfg)
	end

	table.foreachi(files, function(file)
		-- only process compile units.
		if not path.iscppfile(file.abspath) then
			return
		end

		for cfg in p.project.eachconfig(prj) do
			local fcfg = p.fileconfig.getconfig(file, cfg)

			-- any file that has any file settings can't be added to the unityFile
			if p.fileconfig.hasFileSettings(fcfg) then
				return
			end

			-- if the file is the precompiled header source, it can't be added either.
			if cfg.pchsource == fcfg.abspath and not cfg.flags.NoPCH then
				return
			end
		end

		-- add to the list.
		table.insert(fileList, file.abspath)

		-- mark as ExcludeFromBuild
		for cfg in p.project.eachconfig(prj) do
			local fcfg = p.fileconfig.getconfig(file, cfg)
			fcfg.flags.ExcludeFromBuild = true
		end

		-- now output the list if we have enough.
		if (#fileList >= count) then
			local unityName = _write_unity_file(prj, id, fileList)
			for cfg in p.project.eachconfig(prj) do
				addFile(cfg, unityName)
			end

			fileList = {}
			id = id + 1
		end
	end)

	if (#fileList >= 0) then
		local unityName = _write_unity_file(prj, id, fileList)
		for cfg in p.project.eachconfig(prj) do
			addFile(cfg, unityName)
		end
	end


	-- Alpha sort the indices, so I will get consistent results in
	-- the exported project files.

	table.sort(files, function(a,b)
		return a.vpath < b.vpath
	end)

	return files
end


p.override(p.oven, "bakeFiles", function(base, prj)
	local files = base(prj)

	if prj.unity and type(prj.unity) == 'number' then
		files = _generate_unity_files(prj, files, prj.unity)
	end

	return files
end)
