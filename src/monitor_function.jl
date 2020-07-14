export monitor_functions, monitor_function, get_active, set_active!

"""
A problem structure to contain monitor functions.
"""
struct MonitorFunctions
    func::Vector{Func}
    active::Vector{Bool}
    idx_var::Vector{Int64}
    idx_data::Vector{Int64}
    idx_func::Vector{Int64}
    name::Dict{String, Int64}
end
MonitorFunctions() = MonitorFunctions(Func[], Bool[], Int64[], Int64[], Int64[], Dict{String, Int64}())

function (mfuncs::MonitorFunctions)(::Signal{:post_correct}, problem)
    # Store the var value in data (if var is non-empty)
    chart = get_current_chart(problem)
    u = get_uview(chart)
    data = get_data(chart)
    for (active, idx_var, idx_data) in zip(mfuncs.active, mfuncs.idx_var, mfuncs.idx_data)
        if active
            data[idx_data][] = u[idx_var]
        end
    end
end

function init!(mfuncs::MonitorFunctions, problem)
    flat = get_flatproblem(problem)
    # Find all monitor functions and store their locations
    for (i, func) in pairs(flat.func)
        if func.func isa MonitorFunction
            idx_var = findfirst(==(func.var[1]), flat.var)
            idx_data = findfirst(==(func.data[1]), flat.data)
            push!(mfuncs.func, func)
            push!(mfuncs.active, func.func.active[])
            push!(mfuncs.idx_var, idx_var)
            push!(mfuncs.idx_data, idx_data)
            push!(mfuncs.idx_func, i)
            mfuncs.name[first(k for (k, v) in flat.var_names if v == idx_var)] = lastindex(mfuncs.func)
        end
    end
end

function exchange_pars(flat::FlatProblem) end

"""
Create a problem structure to contain monitor functions
"""
function monitor_functions(name = "mfuncs")
    problem = Problem(name, MonitorFunctions())
    return problem
end

"""
An individual monitor function.
"""
struct MonitorFunction{F}
    f::F
    active::Base.RefValue{Bool}
end

# Slightly annoying special casing of the different combinations of inputs to account for
# the fact that Tuples are unwrapped if they are singletons

function (mfunc::MonitorFunction)(res, u::Tuple, data::Tuple, prob...)
    res[1] =
        mfunc.f(Base.tail(u), Base.tail(data), prob...) -
        (isempty(u[1]) ? data[1][] : u[1][1])
    return
end

function (mfunc::MonitorFunction)(res, u::Tuple{<:Any,<:Any}, data::Tuple, prob...)
    res[1] = mfunc.f(u[2], Base.tail(data), prob...) - (isempty(u[1]) ? data[1][] : u[1][1])
    return
end

function (mfunc::MonitorFunction)(res, u::Tuple, data::Tuple{<:Any,<:Any}, prob...)
    res[1] = mfunc.f(Base.tail(u), data[2], prob...) - (isempty(u[1]) ? data[1][] : u[1][1])
    return
end

function (mfunc::MonitorFunction)(
    res,
    u::Tuple{<:Any,<:Any},
    data::Tuple{<:Any,<:Any},
    prob...,
)
    res[1] = mfunc.f(u[2], data[2], prob...) - (isempty(u[1]) ? data[1][] : u[1][1])
    return
end

function (mfunc::MonitorFunction)(res, u::Tuple, data::Tuple{<:Any}, prob...)
    res[1] = mfunc.f(Base.tail(u), prob...) - (isempty(u[1]) ? data[] : u[1][1])
    return
end

function (mfunc::MonitorFunction)(res, u::Tuple{<:Any,<:Any}, data::Tuple{<:Any}, prob...)
    res[1] = mfunc.f(u[2], prob...) - (isempty(u[1]) ? data[] : u[1][1])
    return
end

function monitor_function(
    name,
    f,
    var = (),
    data = ();
    initial_value = nothing,
    active = false,
    group = :embedded,
    pass_problem = false,
    top_level = true,
)
    mvar = Var(
        name;
        initial_dim = 1,
        initial_u = initial_value,
        top_level = top_level,
    )
    mdata = Data("mfunc_data", Ref(initial_value))
    fullgroup = (group isa Symbol ? push! : append!)([:mfunc], group)
    return Func(name, MonitorFunction(f, Ref(active)), (mvar, var...), (mdata, data...); initial_dim = 1, group = fullgroup, pass_problem = pass_problem)
end

function parameter(name, var; active = false, top_level = true, index = 1)
    local mfunc
    let index = index
        mfunc =
            monitor_function(name, u -> u[index], (var,); active = active, top_level = top_level)
    end
end

function parameters(names, var; kwargs...)
    return [parameter(name, var; index = i, kwargs...) for (i, name) in enumerate(names)]
end

"""
Set a monitor function active or inactive. Only used during the creation of the problem
structure; once the continuation problem is closed, changing this has no effect.
"""
function set_active!(mfunc::Func, active::Bool)
    if mfunc.func isa MonitorFunction
        mfunc.func.active[] = active
    else
        throw(ArgumentError("Func provided is not a MonitorFunction"))
    end
end

"""
Return whether a monitor function is active (able to change value) or not.
"""
function get_active(mfunc::Func)
    if mfunc.func isa MonitorFunction
        return mfunc.func.active[]
    else
        throw(ArgumentError("Func provided is not a MonitorFunction"))
    end
end
