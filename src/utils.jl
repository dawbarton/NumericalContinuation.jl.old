"""
Return a list of parameter names based on user supplied values.
"""
function par_names end

par_names(p, pnames::Nothing) = ["p$i" for i in eachindex(p)]

function par_names(p, pnames)
    if length(p) == length(pnames)
        return [string(pname) for pname in pnames]
    else
        throw(ArgumentError("Number of parameters does not match number of parameter names)"))
    end
end
