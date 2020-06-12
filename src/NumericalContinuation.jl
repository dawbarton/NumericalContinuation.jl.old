module NumericalContinuation

using DocStringExtensions

@template TYPES = """
    $(TYPEDEF)
    $(DOCSTRING)
    # Fields
    $(TYPEDFIELDS)
    """

@template (FUNCTIONS, METHODS, MACROS) = """
    $(SIGNATURES)
    $(DOCSTRING)
    $(METHODLIST)
    """

include("problem_structure.jl")
include("AlgebraicProblems.jl")

end # module
