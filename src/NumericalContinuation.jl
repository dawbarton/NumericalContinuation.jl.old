module NumericalContinuation


using TimerOutputs  # TODO: remove when finished
const to = TimerOutput()

include("docstrings.jl")
include("problem_structure.jl")
include("view_vector.jl")
include("AlgebraicProblems.jl")

end # module
