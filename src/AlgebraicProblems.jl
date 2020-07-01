"""
This module implements basic functionality to construct algebraic problems of
the form

```math
    0 = f(u, p)
```

where `u` and `p` are the state variables and parameters respectively. Both `u`
and `p` can be scalars or vectors.
"""
module AlgebraicProblems

using ..NumericalContinuation: NumericalContinuation, Var, Func, Problem

include("docstrings.jl")

export AlgebraicProblem

struct AlgebraicFunc{U, P, F}
    f!::F
end

_convert_to(T, val) = val
_convert_to(::Type{<:Number}, val) = val[1]

(af::AlgebraicFunc{U, P})(res, (u, p)) where {U, P} = af.f!(res, _convert_to(U, u), _convert_to(P, p))

"""
Construct an algebraic zero problem of the form

```math
    0 = f(u, p),
```

where `u` is the state and `p` is the parameter(s). The function can operate on scalars or
vectors, and be in-place or not. It assumes that the function output is of the same
dimension as `u`.

# Parameters

* `name::String` : the name of the algebraic zero problem.
* `f` : the function to use for the zero problem. It takes either two arguments
  (`u` and `p`) or three arguments for an in-place version (`res`, `u`, and `p`).
* `u0` : the initial state value (either scalar- or vector-like).
* `p0` : the initial parameter value (either scalar- or vector-like).
* `pnames` : (keyword, optional) the names of the parameters. If not specified,
  auto-generated names will be used.

# Example

```
prob = AlgebraicProblem("cubic", (u, p) -> u^3 - p, 1.5, 1)  # u0 = 1.5, p0 = 1
```
"""
function AlgebraicProblem(name::String, f, u0, p0; pnames=nothing)
    # Determine whether f is in-place or not
    if any(method.nargs == 4 for method in methods(f))
        f! = f
    else
        f! = (res, u, p) -> res .= f(u, p)
    end
    # Check for parameter names
    _pnames = pnames !== nothing ? [string(pname) for pname in pnames] : ["p$i" for i in 1:length(p0)]
    if length(_pnames) != length(p0)
        throw(ArgumentError("Length of parameter vector does not match number of parameter names"))
    end
    # Give the user-provided function the input expected
    U = u0 isa Number ? Number : Vector
    P = p0 isa Number ? Number : Vector
    alg = AlgebraicFunc{U, P, typeof(f!)}(f!)
    # Create the necessary continuation variables and add the function
    u = Var("u", (U === Number ? [u0] : u0))
    p = Var("p", (P === Number ? [p0] : p0))
    func = Func("f", alg, length(u0))
    push!(func, u)
    push!(func, p)
    # TODO: Should also add the parameters as monitor functions
    return push!(Problem(name), func)
end

end # module
