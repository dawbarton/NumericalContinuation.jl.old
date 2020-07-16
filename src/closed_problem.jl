struct ClosedProblem{C}  # TODO: it's not clear if this specialisation will help or whether Any will do instead
    options::Options
    top_level::Problem
    flat::FlatProblem
    mfuncs::MonitorFunctions
    covering::C
end

function ClosedProblem(problem::Problem, options::Options, cover = DEFAULTCOVER)
    top_level = Problem("")
    push!(top_level, problem)
    mfuncs_problem = monitor_functions()
    mfuncs = mfuncs_problem.func
    push!(top_level, mfuncs_problem)
    covering_problem = cover(top_level)
    covering = covering_problem.func
    push!(top_level, covering_problem)
    flat = flatten(top_level)
    closed = ClosedProblem(options, top_level, flat, mfuncs, covering)
end

function init!(closed::ClosedProblem)
    signal!(Signal(:pre_init), closed)
    init!(closed.mfuncs, closed)
    init!(closed.covering, closed)
    signal!(Signal(:post_init), closed)
end

function run!(closed::ClosedProblem)
    signal!(Signal(:pre_run), closed)
    run!(closed.covering, closed)
    signal!(Signal(:post_run), closed)
end

signal!(signal::Signal, closed::ClosedProblem, args...) =
    signal!(closed.flat, signal, closed, args...)

signal!(closed::ClosedProblem, signal::Signal, args...) =
    signal!(closed.flat, signal, args...)

get_options(problem::ClosedProblem) = problem.options
get_problem(problem::ClosedProblem) = problem.top_level
get_flatproblem(problem::ClosedProblem) = problem.flat
get_mfuncs(problem::ClosedProblem) = problem.mfuncs
get_covering(problem::ClosedProblem) = problem.covering

function get_initial_state(T::Type{<:Number}, closed::ClosedProblem)
    u = Vector{Vector{T}}()
    t = Vector{Vector{T}}()
    for var in closed.flat.var
        if var.initial_dim == 0
            push!(u, T[])
        elseif var.initial_u === nothing
            push!(u, zeros(T, var.initial_dim))
        elseif length(var.initial_u) == var.initial_dim
            push!(u, convert(Vector{T}, var.initial_u))
        else
            throw(ErrorException("Initial data for variable $(var) does not have the correct number of dimensions"))
        end
        if var.initial_dim == 0
            push!(t, T[])
        elseif var.initial_t === nothing
            push!(t, zeros(T, var.initial_dim))
        elseif length(var.initial_t) == var.initial_dim
            push!(t, convert(Vector{T}, var.initial_t))
        else
            throw(ErrorException("Initial tangent for variable $(var) does not have the correct number of dimensions"))
        end
    end
    d = Vector{Any}()
    for data in closed.flat.data
        push!(d, data.initial_data)
    end
    # Allow problems to alter the initial values/data
    signal!(Signal(:initial_state), closed, u, t, d)
    # Condense
    uu = reduce(vcat, u)
    tt = reduce(vcat, t)
    va = ViewAxis(length.(u))
    return (va=va, u=uu, t=tt, data=d)
end
