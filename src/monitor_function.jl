struct MonitorFunction{F}
    f::F
end

function (mfunc::MonitorFunction)(res, u, data)
    res[1] = mfunc.f(res, Base.tail(u), Base.tail(data)) - (isempty(u[1]) ? data[1] : u[1][1])
    return nothing
end

function (mfunc::MonitorFunction)(res, u, data, prob)
    res[1] = mfunc.f(res, Base.tail(u), Base.tail(data), prob) - (isempty(u[1]) ? data[1] : u[1][1])
    return nothing
end

struct MonitorFunctions end
