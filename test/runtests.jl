using NumericalContinuation
using NumericalContinuation.FourierCollocation
using Test

function duffing!(res, u, p, t)
    res[1] = u[2]
    res[2] = p[2]*sin(p[1]*t) - 2*p[3]*u[2] - u[1] - u[1]^3
    return
end

@testset "FourierCollocation" begin
    @testset "Duffing" begin
        p0 = [1.0, 0.1, 0.05]
        # sol = solve(ODEProblem(duffing!, [1.0, 0.0], (0.0, 50*2π/p0[1]), p0), Tsit5())
        # sol = solve(ODEProblem(duffing!, sol[:, end], (0.0, 2π/p0[1]), p0), Tsit5())
        # u0 = sol(range(0, 2π/p0[1], length=21)[1:end-1])[:, :]
        u0 = [-0.233 -0.092 0.057 0.202 0.329 0.426 0.481 0.487 0.443 0.354 0.233 0.092 -0.057 -0.202 -0.329 -0.426 -0.481 -0.487 -0.443 -0.354 -0.233; 0.425 0.469 0.473 0.439 0.364 0.248 0.099 -0.063 -0.217 -0.34 -0.425 -0.468 -0.473 -0.439 -0.364 -0.248 -0.1 0.063 0.216 0.34 0.424]
        fourier = fourier_collocation("duffing", duffing!, [0, 2π/p0[1]], u0, p0, pnames=["ω", "Γ", "ξ"], phase=false, fix_t0=true, fix_t1=false)

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


using Pkg
Pkg.activate("nonlinear", shared=true)
using NumericalContinuation
using NumericalContinuation.FourierCollocation

function duffing!(res, u, p, t)
    res[1] = u[2]
    res[2] = p[2]*sin(p[1]*t) - 2*p[3]*u[2] - u[1] - u[1]^3
    return
end

p0 = [1.0, 0.1, 0.05]
u0 = [-0.233 -0.092 0.057 0.202 0.329 0.426 0.481 0.487 0.443 0.354 0.233 0.092 -0.057 -0.202 -0.329 -0.426 -0.481 -0.487 -0.443 -0.354 -0.233; 0.425 0.469 0.473 0.439 0.364 0.248 0.099 -0.063 -0.217 -0.34 -0.425 -0.468 -0.473 -0.439 -0.364 -0.248 -0.1 0.063 0.216 0.34 0.424]
fourier = fourier_collocation("duffing", duffing!, [0, 2π/p0[1]], u0, p0, pnames=["ω", "Γ", "ξ"], phase=false, fix_t0=true, fix_t1=false)
opt = Options()
closed = NumericalContinuation.ClosedProblem(fourier, opt)
NumericalContinuation.init!(closed)
