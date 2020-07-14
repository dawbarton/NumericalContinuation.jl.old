# A key principle in building up the problem structure is that there should be no mutable
# state that gets modified during the continuation run. This means that things like the size
# of (variable-size) variables is not included in the problem structure; fixed-size
# variables can be determined using initial_u.

# The key benefit of this principle is that it becomes possible to reuse a problem structure
# multiple times and, possibly more importantly, it becomes impossible to corrupt the
# problem structure during construction.

export Var, Data, Func, Problem
export glue, get_problem, get_flatproblem

"""
An abstract representation of a continuation variable, that is, state that is continually
updated during continuation.
"""
struct Var
    name::String
    initial_dim::Int64
    initial_u::Any
    initial_t::Any
    top_level::Bool
end
Var(
    name;
    initial_u = nothing,
    initial_t = nothing,
    initial_dim = length(initial_u),
    top_level = false,
) = Var(name, initial_dim, initial_u, initial_t, top_level)

function Base.show(io::IO, mime::MIME"text/plain", var::Var)
    println(io, "$Var($(var.name))")
    println(io, "    initial_dim → $(var.initial_dim)")
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
    println(io, "$Data($(data.name))")
    print(io, "    initial_data → $(data.initial_data)")
end

"""
An abstract representation of a function of the form `f!(output, var, data)`.
"""
struct Func
    name::String
    func::Any
    initial_dim::Int64
    initial_f::Any
    group::Vector{Symbol}
    pass_problem::Bool
    var::Vector{Var}
    var_names::Dict{String,Int64}
    data::Vector{Data}
    data_names::Dict{String,Int64}
end

function Func(
    name,
    func,
    var = (),
    data = ();
    initial_f = nothing,
    initial_dim = length(initial_f),
    group = [:embedded],
    pass_problem = false,
)
    f = Func(
        name,
        func,
        initial_dim,
        initial_f,
        group,
        pass_problem,
        Var[],
        Dict{String,Int64}(),
        Data[],
        Dict{String,Int64}(),
    )
    for v in var
        push!(f, v)
    end
    for d in data
        push!(f, d)
    end
    return f
end

function Base.show(io::IO, mime::MIME"text/plain", func::Func)
    println(io, "$Func($(func.name))")
    println(io, "    initial_dim → $(func.initial_dim)")
    println(io, "    initial_f → $(func.initial_f)")
    println(io, "    group → $(func.group)")
    println(io, "    pass_problem → $(func.pass_problem)")
    println(io, "    var → $([nameof(v) for v in func.var])")
    print(io, "    data → $([nameof(d) for d in func.data])")
end

function glue(var1::Var, var2::Var)
    if var1.initial_dim != var2.initial_dim
        throw(ArgumentError("Size mismatch between var1 and var2"))
    end
    return Func(var1.name*"="*var2.name, (res, u) -> res .= u[1] .- u[2], (var1, var2); initial_dim = var1.initial_dim)
end

"""
Return the underlying problem tree structure.
"""
function get_problem end

"""
An abstract type for `Problem` owners to inherit from. (Inheriting is not required but
reduces boilerplate.)
"""
abstract type ProblemOwner end

(owner::ProblemOwner)(::Signal, problem, indices = nothing) = nothing  # fallback for signal handling

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
    owner_pass_indices::Vector{Union{Var,Data,Func,Problem}}
end

const ProblemTypes = Union{Var,Data,Func,Problem}  # Cannot put this earlier because of type recursion issue

function Problem(name, owner = nothing, func = (), problem = ())
    prob = Problem(
        name,
        Vector{Func}[],
        Dict{String,Int64}(),
        Problem[],
        Dict{String,Int64}(),
        owner,
        ProblemTypes[],
    )
    for f in func
        push!(prob, f)
    end
    for p in problem
        push!(prob, p)
    end
    return prob
end

function Base.show(io::IO, mime::MIME"text/plain", problem::Problem)
    println(io, "$Problem($(problem.name))")
    println(io, "    func → $([nameof(f) for f in problem.func])")
    print(io, "    problem → $([nameof(p) for p in problem.problem])")
end

get_problem(problem::Problem) = problem

"""
Request that the indices of a particular item (Var, Data, Func, or Problem) are passed to
the problem owner when signalled.
"""
function pass_indices!(problem::Problem, item::ProblemTypes)
    push!(problem.owner_pass_indices, item)
    return problem
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

    @eval function Base.append!(
        collection::$Collection,
        items::Union{NTuple{<:Any,$Item},AbstractVector{$Item}},
    )
        for item in items
            push!(collection, item)
        end
        return collection
    end

    @eval function Base.getindex(
        collection::$Collection,
        ::Type{$Item},
        item::AbstractString,
    )
        return collection.$name[collection.$(Symbol(name, "_names"))[item]]
    end
end

for (Collection, names) in ((Func, (:var, :data)), (Problem, (:func, :problem)))
    @eval function Base.getindex(collection::$Collection, item::AbstractString)
        itempath = split(item, ".", limit = 2)
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
    call_group::G
    call_owner::O
end

FlatProblem() = FlatProblem(
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

function evaluate!(res, flat::FlatProblem, group::Symbol, u, data, problem)
    flat.call_group[group](res, u, data, problem)
end

function signal!(flat::FlatProblem, signal::Signal, problem)
    flat.call_owner(signal, problem)
end

get_problem(flat::FlatProblem) = flat.problem[1]
get_flatproblem(flat::FlatProblem) = flat

"""
Take a hierarchical `Problem` structure and return a flattened version that contains
generated code for each function group.
"""
function flatten(problem::Problem)
    flat = FlatProblem()
    _flatten!(flat, problem, "")
    call_group = NamedTuple{(keys(flat.group_names)...,)}((
        eval(_gen_call_group(flat, i)) for i in eachindex(flat.group)
    ))
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
        call_group,
        call_owner,
    )
end

const NAME_SEP = "."

function _flatten!(flat::FlatProblem, problem::Problem, basename)
    if !(problem in flat.problem)
        push!(flat.problem, problem)
        pidx = lastindex(flat.problem)
        basename *= problem.name
        haskey(flat.problem_names, basename) && @warn "Duplicate Problem name" basename problem
        flat.problem_names[basename] = pidx
        # Iterate over the sub-problems (depth first)
        for subproblem in problem.problem
            _flatten!(flat, subproblem, basename * NAME_SEP)
        end
        # Iterate over functions in the problem
        for func in problem.func
            _flatten!(flat, func, basename * NAME_SEP)
        end
    else
        throw(ErrorException("Duplicate Problem within the problem structure"))
    end
    return flat
end

function _flatten!(flat::FlatProblem, func::Func, basename)
    if !(func in flat.func)
        # Func has not been previously added, so add it
        push!(flat.func, func)
        fidx = lastindex(flat.func)
        basename *= func.name
        haskey(flat.func_names, basename) && @warn "Duplicate Func name" basename func
        flat.func_names[basename] = fidx
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
            _flatten!(flat, var, basename * NAME_SEP)
        end
        # Iterate over the Data belonging to the Func
        for data in func.data
            _flatten!(flat, data, basename * NAME_SEP)
        end
    else
        throw(ErrorException("Duplicate Func within the problem structure"))
    end
    return flat
end

function _flatten!(flat::FlatProblem, var::Var, basename)
    if !(var in flat.var)
        # Not been previously added, so add it
        push!(flat.var, var)
        idx = lastindex(flat.var)
        basename = var.top_level ? var.name : basename * var.name
        haskey(flat.var_names, basename) && @warn "Duplicate Var name" basename var
        flat.var_names[basename] = idx
    end
    return flat
end

function _flatten!(flat::FlatProblem, data::Data, basename)
    if !(data in flat.data)
        # Not been previously added, so add it
        push!(flat.data, data)
        idx = lastindex(flat.data)
        basename *= data.name
        haskey(flat.data_names, basename) && @warn "Duplicate Data name" basename data
        flat.data_names[basename] = idx
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
            push!(func_f.args, :(u[:]))  # TODO: this won't work for monitor functions that require the entire state
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
                push!(
                    func.args[2].args,
                    :($(problem.owner)(signal, problem, $((indices...,)))),
                )
            end
        end
    end
    push!(func.args[2].args, :nothing)
    return func
end
