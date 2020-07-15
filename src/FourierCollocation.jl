module FourierCollocation

using ..NumericalContinuation: Var, Data, Func, Problem
using ..NumericalContinuation: parameter, parameters, parameter_names

export fourier_collocation

struct FourierColl{F}
    f!::F
    n_dim::Int64
end

# TODO: allow for out-of-place functions (parameterise FourierColl further?)

function (fourier::FourierColl)(res, (u, p, t), data)
    mul!(data.Du, reshape(u, (fourier.n_dim, data.n_mesh)), data.D)
    ii = 1:fourier.n_dim
    T = t[2] - t[1]
    for i = 1:data.n_mesh
        @views fourier.f!(res[ii], u[ii], p, t[1] + T * (i - 1) / data.n_mesh)
        @views res[ii] .= data.Du[ii] .- T .* res[ii]
        ii = ii .+ fourier.n_dim
    end
    return
end

function fourier_collocation(
    name::String,
    f!,
    trange,
    u0,
    p0;
    pnames = nothing,
    top_level = true,
    phase = true,
    fix_t0 = true,
    fix_t1 = false,
)
    if length(trange) == 1
        t0 = [0, trange[1]]
    elseif length(trange) == 2
        t0 = trange
    else
        throw(ArgumentError("Expected trange to contain start and end times only"))
    end
    # Generate parameter names
    _pnames = parameter_names(p0, pnames)
    # Create the continuation problem
    problem = Problem(name)
    # Create differentiation matrix and temporary storage to avoid allocations
    D = -fourier_diff(eltype(u0), size(u0, 2)) * 2π
    Du = similar(u0)
    # Create the necessary continuation variables and add the function
    u = Var("u", initial_u = vec(u0))
    p = Var("p", initial_u = p0)
    t = Var("t", initial_u = t0)
    coll = Data("coll", (n_mesh = size(u0, 2), D = D, Du = Du))
    func = Func(
        "f",
        FourierColl(f!, size(u0, 1)),
        (u, p, t),
        (coll,),
        initial_dim = length(u0),
    )
    push!(problem, func)
    # Continuation parameters
    append!(problem, parameters(_pnames, p, top_level = top_level))
    push!(problem, parameter("t0", t, index = 1, active = !fix_t0, top_level = false))
    push!(problem, parameter("t1", t, index = 2, active = !fix_t1, top_level = false))
    return problem
end

"""
Create a Fourier differentiation matrix with numerical type T on the domain
`x = range(0, 2π, length=N+1)[1:end-1]`.
"""
function fourier_diff(T::Type{<:Number}, N::Integer; order = 1)
    D = zeros(T, N, N)
    n1 = (N - 1) ÷ 2
    n2 = N ÷ 2
    x = LinRange{T}(0, π, N + 1)
    if order == 1
        for i = 2:N
            sgn = (one(T) / 2 - iseven(i))
            D[i, 1] = iseven(N) ? sgn * cot(x[i]) : sgn * csc(x[i])
        end
    elseif order == 2
        D[1, 1] =
            iseven(N) ? -N^2 * one(T) / 12 - one(T) / 6 : -N^2 * one(T) / 12 + one(T) / 12
        for i = 2:N
            sgn = -(one(T) / 2 - iseven(i))
            D[i, 1] = iseven(N) ? sgn * csc(x[i]) .^ 2 : sgn * cot(x[i]) * csc(x[i])
        end
    else
        error("Not implemented")
    end
    for j = 2:N
        D[1, j] = D[N, j-1]
        D[2:N, j] .= D[1:N-1, j-1]
    end
    return D
end
fourier_diff(N::Integer; kwargs...) = fourier_diff(Float64, N; kwargs...)

end  # module
