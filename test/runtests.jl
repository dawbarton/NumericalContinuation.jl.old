using NumericalContinuation
using Test

@testset "NumericalContinuation.jl" begin
    # Write your own tests here.
    p1 = zero_problem("cubic", (u, p) -> u^3 - p, 1.5, 1.5^3)
    p2 = zero_problem("quad", (u, p) -> u^2 - p, 1.2, 1.2^2)
    p3 = push!(push!(Problem("group"), p1), p2)
    p4 = push!(Problem("main"), p3)
    mfunc = monitor_function("test", u -> u[1], )
    mfuncs = monitor_functions()
    flat = NumericalContinuation.flatten(p4)
end
