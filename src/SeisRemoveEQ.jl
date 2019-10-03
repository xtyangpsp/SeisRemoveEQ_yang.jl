__precompile__()
module SeisRemoveEQ

include("utils.jl")
include("map_removeEQ.jl")
using .Utils
using .Map_removeEQ

using Distributed
@everywhere using SeisIO, Dates, Printf, JLD2, FileIO

export seisremoveEQ

function seisremoveEQ(InputDict::Dict)

	Utils.initlogo()

	jldopen(InputDict["finame"], "r") do file
		InputDict["DLtimestamplist"] = file["info/DLtimestamplist"];
		InputDict["stationlist"] = file["info/stationlist"];
	end

	fodir = InputDict["fodir"]
	foname = InputDict["foname"]

	if foname == InputDict["finame"]
		error("Input name and output name is identical; which may cause overwrite. Please change the output name. Abort.")
	end

	mkpath(fodir)
    fopath=joinpath(fodir, foname*".jld2")
	InputDict["fopath"] = fopath

	tmppath = joinpath(fodir, "./seisremoveeq_tmp")
	InputDict["tmppath"] = tmppath
	mkpath(tmppath)

	Utils.defaultinputdict!(InputDict)

	#print parameters
	printparams(InputDict)

	printstyled("---Start removing EQ---\n"; color=:cyan, bold=true)

	# choose converting time window
	mapidlist = []
	for i = 1:length(InputDict["DLtimestamplist"])
		y, jd = parse.(Int64, split(InputDict["DLtimestamplist"][i], ".")[1:2])
		try
			m, d = j2md(y,jd)
			curdate=DateTime(y, m, d)
			if !InputDict["IsStartendtime"]
				# convert all time stamp
				push!(mapidlist, i)
			else
				if curdate >= InputDict["starttime"] && curdate <= InputDict["endtime"]
					push!(mapidlist, i)
				else
					continue
				end
			end
		catch jmderror
			println(jmderror)

			if i==length(InputDict["DLtimestamplist"])
				pop!(InputDict["DLtimestamplist"])
				println("!!! Removed the final timestamp. This is a temporary fix for non-leap year with 366 days.!!!")
			end
		end
 	end

	if isempty(mapidlist)
		error("no data is within start and endtime. abort.")
	end

	InputDict["NumofTimestamp"] = length(mapidlist)

	t_removeeq = @elapsed pmap(x -> map_removeEQ(x, InputDict), mapidlist)

	# convert intermediate file to prescibed file format (JLD2, ASDF, ...)
	InputDict["DLtimestamplist_selected"] = InputDict["DLtimestamplist"][mapidlist]

	t_convert = @elapsed convert_tmpfile(InputDict)

	printstyled("---Summary---\n"; color=:cyan, bold=true)
	println("time to remove EQ    =$(t_removeeq)[s]")
	println("time to convert      =$(t_convert)[s]")
	print("\nprocess done at:")
	println(now())
	str = "EQ is successfully removed from raw data:\nOutput = $fopath\n"
	printstyled(str; color=:green, bold=true)

end

end # module
