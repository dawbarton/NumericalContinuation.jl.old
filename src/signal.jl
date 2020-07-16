export Signal
export signals

"""
    $(TYPEDEF)

A signal type for indicating a particular signal should be processed.
"""
struct Signal{S} end
@inline Signal(S::Symbol) = Signal{S}()

"""
Issue a signal to all problem owners.

# Example

To signal that the correction step has finished (irrespective of success)
```
signal!(Signal(:post_correct), problem)
```
"""
function signal! end

"""
    $(SIGNATURES)

Return a list of documented signals.
"""
function signals()
    return [m.sig.parameters[2].parameters[1] for m in methods(signals) if ((m.nargs == 2) && (m.sig.parameters[2] <: Signal))]
end

"""
    $(SIGNATURES)

Return the docstring for a particular signal.
"""
signals(signal::Symbol) = signals(Signal(signal))

"""
    Signal(:initial_state)

Indicates that the function [`get_initial_state`](@ref) has been called. Problems should use
this as an opportunity to update initial conditions and initial data.

# Call signature

```
owner(signal, problem, [indices], u::Vector{Vector{T}}, data::Vector{Any}) where {T<:Number}
```

# Notes

* `u` is a vector of initial values (which themselves are vectors). While `u` can be mutated
  at will, the initial values should not be.

* `data` is a vector of initial data (which could be anything). Similar to `u`, while `data`
  can be mutated, the initial data should not be.

# Example

```
# Change the first element of the first initial value to be 1.0.

# BAD - mutating a user supplied value directly
u[1][1] = 1.0

# GOOD - copying a user supplied value before mutating
u[1] = copy(u[1])
u[1][1] = 1.0
```
"""
signals(signal::Signal{:initial_state}) = (@doc signals(::typeof(signal)))  # brackets are required due to special casing of @doc

"""
    Signal(:pre_init)
    Signal(:post_init)

These signals are called when [`init!`](@ref) is called with a [`ClosedProblem`](@ref).
"""
signals(signal::Union{Signal{:pre_init},Signal{:post_init}}) = (@doc signals(::typeof(signal)))  # brackets are required due to special casing of @doc

