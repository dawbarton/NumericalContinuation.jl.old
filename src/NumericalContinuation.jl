module NumericalContinuation


using TimerOutputs  # TODO: remove when finished
const to = TimerOutput()

include("docstrings.jl")
include("problem_structure.jl")
include("zero_problem.jl")
include("view_vector.jl")

end # module
