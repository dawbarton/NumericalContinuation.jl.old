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

Return a list of documented signals. This may not be an exhaustive list of all possible
signals.
"""
function signals()
    signal = Symbol[]
    for m in methods(signals)
        if (m.nargs == 2) && (m.sig.parameters[2] <: Signal)
            par = m.sig.parameters[2]
            if par isa Union
                while par.b isa Union
                    push!(signal, par.a.parameters[1])
                    par = par.b
                end
                push!(signal, par.a.parameters[1])
                push!(signal, par.b.parameters[1])
            else
                push!(signal, par.parameters[1])
            end
        end
    end
    return signal
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

# Signature

```
owner(signal, [indices], problem, u, data)
```

# Arguments

- `signal::Signal{:initial_state}`
- `indices::NTuple{N,Int64} where N`: (optional) indices of any [`Var`](@ref),
    [`Data`](@ref), [`Func`](@ref), or [`Problem`](@ref) requested using
    [`pass_indices`](@ref)
- `problem::ClosedProblem`: the underlying problem structure
- `u::Vector{Vector{T}} where {T<:Number}`: vector of initial values
- `t::Vector{Vector{T}} where {T<:Number}`: vector of initial tangents
- `data::Vector{Any}`: vector of initial data

# Notes

- While `u`, `t`, and `data` can be mutated at will, the values contained within them should
    not be since they are user supplied. Instead, they should be copied before mutating.

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

These signals occur when [`init!`](@ref) is called with a [`ClosedProblem`](@ref).

# Signature

```
owner(signal, [indices], problem)
```

# Arguments

- `signal::Signal{:initial_state}`
- `indices::NTuple{N,Int64} where N`: (optional) indices of any [`Var`](@ref),
    [`Data`](@ref), [`Func`](@ref), or [`Problem`](@ref) requested using
    [`pass_indices`](@ref)
- `problem::ClosedProblem`: the underlying problem structure
"""
signals(signal::Union{Signal{:pre_init},Signal{:post_init}}) = (@doc signals(::typeof(signal)))  # brackets are required due to special casing of @doc

