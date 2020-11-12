module Covering1D

using ..NumericalContinuation: NumericalContinuation, Data, Problem
using ..NumericalContinuation: monitor_function
using ..NumericalContinuation: ALLVARS

function pseudoarclength(u, data)
    result = zero(eltype(u))
    for i in eachindex(u)
        result += (u[i] - data.u[i])*data.t[i]
    end
    return result
end

struct Cover <: ProblemOwner end

function (::Cover)(::Signal{:pre_correct}, indices, problem)
    chart = get_current_chart(problem)
    u = copy(get_u(chart))
    t = copy(get_t(chart))
    tv = get_uview(chart, t)
    tv[indices[2]] = 0
    data = get_data(chart)
    data[indices[1]] = (u=u, t=t)
    return
end

function covering1d(problem::Problem)
    data = Data("pseudoarclength", nothing)
    mfunc = monitor_function("pseudoarclength", pseudoarclength, (ALLVARS,), (data,))
    cover = Problem("covering", Cover(), (mfunc,))
    pass_indices(cover, data)
    pass_indices(cover, mfunc.var[1])
end

end  # module
