module NumericalContinuation

using DocStringExtensions

@template TYPES = """
    $(TYPEDEF)
    $(DOCSTRING)
    # Fields
    $(TYPEDFIELDS)
    """

"""
An abstract representation of a continuation variable, that is, state that is continually
updated during continuation.
"""
struct Var
    name::String
    initial_u::Any
    initial_t::Any
    owner::Any
end

"""
An abstract representation of continuation data, that is, information that may change
between two continuation steps but not during a single continuation step.
"""
struct Data
    name::String
    initial_data::Any
    owner::Any
end

"""
An abstract representation of a continuation function of the form `f(output, vars, data)`.
No properties such as smoothness are assumed. Functions may be embedded within the
continuation zero problem or used in other contexts.
"""
struct Func
    name::String
    vars::Vector{Var}
    var_names::Dict{String, Int64}
    data::Vector{Data}
    data_names::Dict{String, Int64}
    owner::Any
end

"""
An abstract representation of a continuation problem.
"""
struct Problem
    name::String
    funcs::Vector{Func}
    func_names::Dict{String, Int64}
    groups::Vector{Symbol}
    group_names::Dict{Symbol, Int64}
    group_membership::Vector{Vector{Int64}}
    problems::Vector{Problem}
    problem_names::Dict{String, Int64}
    owner::Any
end

"""
A flattened representation of a problem.
"""
struct FlatProblem
    name::String
    vars::Vector{Var}
    var_names::Dict{String, Int64}
    data::Vector{Data}
    data_names::Dict{String, Int64}
    funcs::Vector{Func}
    func_names::Dict{String, Int64}
    groups::Vector{Vector{Int64}}
    group_names::Dict{Symbol, Int64}
    problems::Vector{Problem}
    problem_names::Dict{String, Int64}
    owner::Any
end

FlatProblem(name::String, owner) = FlatProblem(
    name,
    Vector{Var}(),
    Dict{String, Int64}(),
    Vector{Data}(),
    Dict{String, Int64}(),
    Vector{Func}(),
    Dict{String, Int64}(),
    Vector{Vector{Int64}}(),
    Dict{Symbol, Int64}(),
    Vector{Problem}(),
    Dict{String, Int64}(),
    owner,
)

function flatten(prob::Problem)
    flat = FlatProblem(prob.name, prob.owner)
    flatten!(flat, prob, "")
end

function flatten!(flat::FlatProblem, prob::Problem, basename::String)
    for func in prob.funcs
        if !(func in flat.funcs)
            # Func has not been previously added, so add it
            push!(flat.funcs, func)
            fidx = lastindex(flat.funcs)
            if !isempty(func.name)
                fname = func.name[1] == "%" ? basename*"."*func.name[2:end] : func.name
                if haskey(flat.func_names, fname)
                    @warning "Duplicate Func name" fname func
                else
                    flat.func_names[func.name] = fidx
                end
            end
            # Iterate over the Var
        end
    end
    # Groups are separate!
end

end # module
