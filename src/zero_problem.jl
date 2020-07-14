export zero_problem

struct ZeroFunc{U,P,F}
    f!::F
end

_lift(T, val) = val
_lift(::Type{<:Number}, val) = val[1]

(af::ZeroFunc{U,P})(res, (u, p)) where {U,P} = af.f!(res, _lift(U, u), _lift(P, p))

"""
Construct a zero problem of the form

```math
    0 = f(u, p),
```

where `u` is the state and `p` is the parameter(s). The function can operate on scalars or
vectors, and be in-place or not. It assumes that the function output is of the same
dimension as `u`.

# Parameters

* `name::String` : the name of the zero problem.
* `f` : the function to use for the zero problem. It takes either two arguments
  (`u` and `p`) or three arguments for an in-place version (`res`, `u`, and `p`).
* `u0` : the initial state value (either scalar- or vector-like).
* `p0` : the initial parameter value (either scalar- or vector-like).
* `pnames` : (keyword, optional) the names of the parameters. If not specified,
  auto-generated names will be used.

# Example

```
prob = zero_problem("cubic", (u, p) -> u^3 - p, 1.5, 1)  # u0 = 1.5, p0 = 1
```
"""
function zero_problem(name::String, f, u0, p0; pnames = nothing)
    # Determine whether f is in-place or not
    if any(method.nargs == 4 for method in methods(f))
        f! = f
    else
        f! = (res, u, p) -> res .= f(u, p)
    end
    # Generate parameter names
    _pnames = par_names(p0, pnames)
    # Give the user-provided function the input expected
    U = u0 isa Number ? Number : Vector
    P = p0 isa Number ? Number : Vector
    alg = ZeroFunc{U,P,typeof(f!)}(f!)
    # Create the necessary continuation variables and add the function
    u = Var("u", (U === Number ? [u0] : u0))
    p = Var("p", (P === Number ? [p0] : p0))
    func = Func("f", alg, length(u0))
    push!(func, u)
    push!(func, p)
    # TODO: Should also add the parameters as monitor functions
    return push!(Problem(name), func)
end
