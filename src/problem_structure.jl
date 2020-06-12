# A key principle in building up the problem structure is that there should be no mutable
# state that gets modified during the continuation run. This means that things like the size
# of (variable-size) variables is not included in the problem structure; fixed-size
# variables can be determined using initial_u.

# The key benefit of this principle is that it becomes possible to reuse a problem structure
# multiple times and, possibly more importantly, it becomes impossible to corrupt the
# problem structure during construction.

export Var, Data, Func, Problem

"""
An abstract representation of a continuation variable, that is, state that is continually
updated during continuation.
"""
struct Var
    name::String
    initial_u::Any
    initial_t::Any
    toplevel::Bool
end
Var(name, initial_u, initial_t = nothing) =
    Var(name, initial_u, initial_t, false)

function Base.show(io::IO, mime::MIME"text/plain", var::Var)
    println(io, "Var($(var.name))")
    println(io, "    initial_u → $(var.initial_u)")
    print(io, "    initial_t → $(var.initial_t)")
end

"""
An abstract representation of continuation data, that is, information that may change
between two continuation steps but not during a single continuation step.
"""
struct Data
    name::String
    initial_data::Any
end

function Base.show(io::IO, mime::MIME"text/plain", data::Data)
    println(io, "Data($(data.name))")
    print(io, "    initial_data → $(data.initial_data)")
end

"""
An abstract representation of a function of the form `f!(output, var, data)`.
"""
struct Func
    name::String
    func::Any
    initial_f::Any
    group::Vector{Symbol}
    pass_problem::Bool
    var::Vector{Var}
    var_names::Dict{String,Int64}
    data::Vector{Data}
    data_names::Dict{String,Int64}
end

function Func(name, func, initial_f, group = [:embedded], pass_problem = false)
    Func(name, func, initial_f, group, pass_problem, Var[], Dict{String,Int64}(), Data[],
        Dict{String,Int64}())
end

function Base.show(io::IO, mime::MIME"text/plain", func::Func)
    println(io, "Func($(func.name))")
    println(io, "    initial_f → $(func.initial_f)")
    println(io, "    group → $(func.group)")
    println(io, "    pass_problem → $(func.pass_problem)")
    println(io, "    var → $([nameof(v) for v in func.var])")
    print(io, "    data → $([nameof(d) for d in func.data])")
end

"""
An abstract representation of a continuation problem.
"""
struct Problem
    name::String
    func::Vector{Func}
    func_names::Dict{String,Int64}
    problem::Vector{Problem}
    problem_names::Dict{String,Int64}
    owner::Any
end

Problem(name, owner = nothing) = Problem(
    name,
    Vector{Func}[],
    Dict{String,Int64}(),
    Problem[],
    Dict{String,Int64}(),
    owner,
)

function Base.show(io::IO, mime::MIME"text/plain", problem::Problem)
    println(io, "Problem($(problem.name))")
    println(io, "    func → $([nameof(f) for f in problem.func])")
    print(io, "    problem → $([nameof(p) for p in problem.problem])")
end

# Generic functions for all collections
for (Collection, Item, name) in (
    (Func, Var, :var),
    (Func, Data, :data),
    (Problem, Func, :func),
    (Problem, Problem, :problem),
)
    @eval function Base.push!(collection::$Collection, item::$Item)
        if item in collection.$name
            throw(ArgumentError(string($Item) * " already added: " * item.name))
        else
            push!(collection.$name, item)
            if !isempty(item.name)
                idx = lastindex(collection.$name)
                if haskey(collection.$(Symbol(name, "_names")), item.name)
                    @warn "Duplicate name" item.name item
                else
                    collection.$(Symbol(name, "_names"))[item.name] = idx
                end
            end
        end
        return collection
    end

    @eval function Base.getindex(collection::$Collection, ::Type{$Item}, item::AbstractString)
        return collection.$name[collection.$(Symbol(name, "_names"))[item]]
    end
end

for (Collection, names) in ((Func, (:var, :data)), (Problem, (:func, :problem)))
    @eval function Base.getindex(collection::$Collection, item::AbstractString)
        itempath = split(item, ".", limit=2)
        for subcollection in $names
            names_dict = getfield(collection, Symbol(subcollection, "_names"))
            if haskey(names_dict, itempath[1])
                idx = names_dict[itempath[1]]
                if length(itempath) == 1
                    return getfield(collection, subcollection)[idx]
                else
                    return getfield(collection, subcollection)[idx][itempath[2]]
                end
            end
        end
        throw(KeyError(item))
    end
end

for Item in (Var, Data, Func, Problem)
    @eval Base.nameof(item::$Item) = item.name
    @eval ownerof(item::$Item) = item.owner
end

"""
A flattened representation of a continuation problem.
"""
struct FlatProblem
    name::String
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
    owner::Any
end

FlatProblem(name, owner = nothing) = FlatProblem(
    name,
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
    owner,
)

function flatten(problem::Problem)
    flat = FlatProblem(problem.name, problem.owner)
    _flatten!(flat, problem, "")
end

function _flatten!(flat::FlatProblem, problem::Problem, basename)
    # Iterate over the sub-problems (depth first)
    for subproblem in problem.problem
        if isempty(subproblem.name)
            flatten!(flat, subproblem, basename)
        else
            flatten!(flat, subproblem, basename * subproblem.name * ".")
        end
    end
    # Iterate over functions in the problem
    for func in problem.func
        if !(func in flat.func)
            # Func has not been previously added, so add it
            push!(flat.func, func)
            fidx = lastindex(flat.func)
            if !isempty(func.name)
                fname = basename * func.name
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
                        vname = var.toplevel ? var.name : basename * var.name
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
                        dname = basename * data.name
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

function _generate_func(flat::FlatProblem, group::Integer)
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
_generate_func(flat::FlatProblem, group::Symbol) = _generate_func(flat, flat.group_names[group])