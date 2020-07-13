using NumericalContinuation
using Test

@testset "NumericalContinuation.jl" begin
    p1 = zero_problem("circle", (u, p) -> u[1]^2 + u[2]^2 - 1, [1, 0], [])
    p2 = zero_problem("plane", (u, p) -> u[1] + u[2] + u[3], [1, 0, -1], [])

    p1 = zero_problem("cubic", (u, p) -> u^3 - p, 1.5, 1.5^3)
    p2 = zero_problem("quad", (u, p) -> u^2 - p, 1.2, 1.2^2)
    p3 = push!(push!(Problem("group"), p1), p2)
    p4 = push!(Problem("main"), p3)
    mfunc = monitor_function("test", u -> u[1], )
    mfuncs = monitor_functions()
    flat = NumericalContinuation.flatten(p4)
end
