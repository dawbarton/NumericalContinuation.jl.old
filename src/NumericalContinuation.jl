module NumericalContinuation


using TimerOutputs  # TODO: remove when finished
const to = TimerOutput()

include("docstrings.jl")
include("signal.jl")
include("view_vector.jl")
include("problem_structure.jl")
include("monitor_function.jl")
include("options.jl")
include("closed_problem.jl")

include("utils.jl")

include("zero_problem.jl")

end # module
