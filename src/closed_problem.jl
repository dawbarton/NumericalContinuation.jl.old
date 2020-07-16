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
