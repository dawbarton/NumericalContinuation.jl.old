"""
Return the underlying flattened problem structure (includes generated code).
"""
function get_flatproblem end

"""
A flattened representation of a continuation problem.
"""
struct FlatProblem{G,O}
    var::Vector{Var}
    var_names::Dict{String,Int64}
    data::Vector{Data}
    data_names::Dict{String,Int64}
    func::Vector{Func}
    func_names::Dict{String,Int64}
    group::Vector{Vector{Func}}
    group_names::Dict{Symbol,Int64}
    problem::Vector{Problem}
    problem_names::Dict{String,Int64}
    mfuncs::MonitorFunctions
    call_group::G
    call_owner::O
end

FlatProblem(mfuncs::MonitorFunctions) = FlatProblem(
    Var[],
    Dict{String,Int64}(),
    Data[],
    Dict{String,Int64}(),
    Func[],
    Dict{String,Int64}(),
    Vector{Func}[],
    Dict{Symbol,Int64}(),
    Problem[],
    Dict{String,Int64}(),
    mfuncs,
    nothing,
    nothing,
)

function Base.show(io::IO, mime::MIME"text/plain", flat::FlatProblem)
    println(io, "$FlatProblem()")
    println(io, "    var → $(collect(keys(flat.var_names)))")
    println(io, "    data → $(collect(keys(flat.data_names)))")
    println(io, "    func → $(collect(keys(flat.func_names)))")
    println(io, "    problem → $(collect(keys(flat.problem_names)))")
    print(io, "    group → $(collect(keys(flat.group_names)))")
end

get_flatproblem(flat::FlatProblem) = flat

"""
Take a hierarchical `Problem` structure and return a flattened version that contains
generated code for each function group.
"""
function flatten(problem::Problem)
    flat = FlatProblem()
    _flatten!(flat, problem, "")
    call_group = Tuple(eval(_gen_call_group(flat, i)) for i in eachindex(flat.group))
    call_owner = eval(_gen_call_owner(flat))
    return FlatProblem(
        flat.var,
        flat.var_names,
        flat.data,
        flat.data_names,
        flat.func,
        flat.func_names,
        flat.group,
        flat.group_names,
        flat.problem,
        flat.problem_names,
        flat.mfuncs,
        call_group,
        call_owner,
    )
end

const NAME_SEP = "."

function _flatten!(flat::FlatProblem, problem::Problem, basename)
    basename_sep = (isempty(basename) || basename[end] == NAME_SEP) ? basename : basename * NAME_SEP
    push!(flat.problem, problem)
    flat.problem_names[basename] = lastindex(flat.problem)
    # Iterate over the sub-problems (depth first)
    for subproblem in problem.problem
        if isempty(subproblem.name)
            _flatten!(flat, subproblem, basename)
        else
            _flatten!(flat, subproblem, basename_sep * subproblem.name)
        end
    end
    # Iterate over functions in the problem
    for func in problem.func
        if !(func in flat.func)
            # Func has not been previously added, so add it
            push!(flat.func, func)
            fidx = lastindex(flat.func)
            if !isempty(func.name)
                fname = basename_sep * func.name
                if haskey(flat.func_names, fname)
                    @warn "Duplicate Func name" fname func
                else
                    flat.func_names[fname] = fidx
                end
            end
            # Iterate over the groups the Func belongs to
            for group in func.group
                if !haskey(flat.group_names, group)
                    push!(flat.group, Func[])
                    gidx = lastindex(flat.group)
                    flat.group_names[group] = gidx
                else
                    gidx = flat.group_names[group]
                end
                push!(flat.group[gidx], func)
            end
            # Iterate over the Vars belonging to the Func
            for var in func.var
                if !(var in flat.var)
                    # Var has not been previously added, so add it
                    push!(flat.var, var)
                    vidx = lastindex(flat.var)
                    if !isempty(var.name)
                        vname = var.top_level ? var.name : basename_sep * var.name
                        if haskey(flat.var_names, vname)
                            @warn "Duplicate Var name" vname var
                        else
                            flat.var_names[vname] = vidx
                        end
                    end
                end
            end
            # Iterate over the Data belonging to the Func
            for data in func.data
                if !(data in flat.data)
                    # Data has not been previously added, so add it
                    push!(flat.data, data)
                    didx = lastindex(flat.data)
                    if !isempty(data.name)
                        dname = basename_sep * data.name
                        if haskey(flat.data_names, dname)
                            @warn "Duplicate Data name" dname data
                        else
                            flat.data_names[dname] = didx
                        end
                    end
                end
            end
        else
            throw(ErrorException("Duplicate Func within the problem structure"))
        end
    end
    return flat
end

function _gen_call_group(flat::FlatProblem, group::Integer)
    func = :(function (res, u, data, problem) end)
    for (i, f) in enumerate(flat.group[group])
        func_f = :($(f.func)(res[$i]))
        u = :(())
        for var in f.var
            idx = findfirst(==(var), flat.var)
            push!(u.args, :(u[$idx]))
        end
        if length(u.args) == 0
            push!(func_f.args, :(u[:]))
        elseif length(u.args) == 1
            push!(func_f.args, u.args[1])
        else
            push!(func_f.args, u)
        end
        d = :(())
        for data in f.data
            idx = findfirst(==(data), flat.data)
            push!(d.args, :(data[$idx]))
        end
        if length(d.args) == 1
            push!(func_f.args, d.args[1])
        elseif length(d.args) > 1
            push!(func_f.args, d)
        end
        if f.pass_problem
            push!(func_f.args, :problem)
        end
        push!(func.args[2].args, func_f)
    end
    push!(func.args[2].args, :nothing)
    return func
end
_gen_call_group(flat::FlatProblem, group::Symbol) =
    _gen_call_group(flat, flat.group_names[group])

function _gen_call_owner(flat::FlatProblem)
    func = :(function (signal::Signal, problem) end)
    for problem in flat.problem
        if problem.owner !== nothing
            indices = Int64[]
            for item in problem.owner_pass_indices
                if item isa Var
                    idx = findfirst(==(item), flat.var)
                elseif item isa Data
                    idx = findfirst(==(item), flat.data)
                elseif item isa Func
                    idx = findfirst(==(item), flat.func)
                elseif item isa Problem
                    idx = findfirst(==(item), flat.problem)
                else
                    idx = nothing
                end
                if idx === nothing
                    throw(ErrorException("Requested item does not exist in the problem structure: $item"))
                else
                    push!(indices, idx)
                end
            end
            # Using the call signature owner(signal, problem) means that we don't have to
            # worry about whether we are adding methods to the correct function. For
            # example, we could have two covering algorithms that provide an adapt signal -
            # which function do you overload?
            if isempty(indices)
                push!(func.args[2].args, :($(problem.owner)(signal, problem)))
            else
                push!(func.args[2].args, :($(problem.owner)(signal, problem, $((indices...,)))))
            end
        end
    end
    push!(func.args[2].args, :nothing)
    return func
end
