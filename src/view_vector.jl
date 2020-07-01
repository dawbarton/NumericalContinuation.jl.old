"""
Define a dimension of an array in terms of a sequence of sub-vectors of specified
dimensions. When used with a `ViewArray`, it allows views into an array to be generated on
demand.
"""
struct ViewAxis
    dims::Vector{Int64}
    indices::Vector{UnitRange{Int64}}
    dirty::Base.RefValue{Bool}
end
ViewAxis(n::Integer) = ViewAxis(zeros(Int64, n), Vector{UnitRange{Int64}}(undef, n), Ref(true))
Base.getindex(axis::ViewAxis, idx) = axis.dims[idx]

function Base.setindex!(axis::ViewAxis, dim, idx)
    axis.dirty[] = true
    axis.dims[idx] = dim
    return dim
end

"""
Update the internal indicies of the `ViewAxis` if the dimensions have been changed. This
function is automatically called when a `ViewArray` is created from the ViewAxis.
"""
function update_indices!(axis::ViewAxis)
    if axis.dirty[]
        idx0 = 0
        for i in eachindex(axis.dims)
            idx1 = idx0 + axis.dims[i]
            axis.indices[i] = (idx0 + 1):idx1
            idx0 = idx1
        end
    end
    return nothing
end

function Base.show(io::IO, mime::MIME"text/plain", axis::ViewAxis)
    print(io, "$ViewAxis($(axis.dims))")
end

"""
A `ViewArray` generates views into an underlying array on demand when indexed. The
size/shape of the views is determined by the `ViewAxis` used to create the `ViewArray`.
"""
struct ViewArray{N, A}
    axes::NTuple{N, ViewAxis}
    array::A

    function ViewArray(axes::NTuple{N, ViewAxis}, array::A) where {N, A}
        if length(axes) > 2
            throw(ErrorException("Not implemented"))
        end
        for (i, viewaxis) in enumerate(axes)
            update_indices!(viewaxis)
            if viewaxis.indices[end][end] != size(array, i)
                throw(ErrorException("Size mismatch in dimension $i"))
            end
        end
        return new{N, A}(axes, array)
    end
end
ViewArray(axes::ViewAxis, array) = ViewArray((axes,), array)

Base.getindex(va::ViewArray{1}, ::Colon) = va.array
Base.getindex(va::ViewArray{2}, ::Colon) = va.array
Base.getindex(va::ViewArray{1}, i1) = view(va.array, va.axes[1].indices[i1])
Base.getindex(va::ViewArray{2}, i1, i2) = view(va.array, va.axes[1].indices[i1], va.axes[2].indices[i2])

Base.setindex!(va::ViewArray{1}, value, i1) = va.array[va.axes[1].indices[i1]] = value
Base.setindex!(va::ViewArray{2}, value, i1, i2) = va.array[va.axes[1].indices[i1], va.axes[2].indices[i2]] = value
