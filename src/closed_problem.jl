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

function init!(closed::ClosedProblem, problem)
    signal!(closed, Signal(:pre_init), problem)
    init!(closed.mfuncs, problem)
    init!(closed.covering, problem)
    signal!(closed, Signal(:post_init), problem)
end

function run!(closed::ClosedProblem, problem)
    signal!(closed, Signal(:pre_run), problem)
    run!(closed.covering, problem)
    signal!(closed, Signal(:post_run), problem)
end

signal!(closed::ClosedProblem, signal::Signal, problem) =
    signal!(closed.flat, signal, problem)

get_options(problem::ClosedProblem) = problem.options
get_problem(problem::ClosedProblem) = problem.top_level
get_flatproblem(problem::ClosedProblem) = problem.flat
get_mfuncs(problem::ClosedProblem) = problem.mfuncs
get_covering(problem::ClosedProblem) = problem.covering
