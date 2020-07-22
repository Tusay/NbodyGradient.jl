abstract type AbstractInitialConditions end
"""

Holds orbital elements of a single body.
"""
struct Elements{T<:AbstractFloat} <: AbstractInitialConditions
    m::T
    P::T
    t0::T
    ecosϖ::T
    esinϖ::T
    i::T
    Ω::T

    Elements(m::T,P::T,t0::T,ecosϖ::T,esinϖ::T,i::T,Ω::T) where T<:Real = new{T}(m,P,t0,ecosϖ,esinϖ,i,Ω)
end

function Base.show(io::IO, ::MIME"text/plain" ,elems::Elements{T}) where T <: Real
    names = ["m","P","t0","ecosϖ","esinϖ","i","Ω"]
    vals = [elems.m,elems.P,elems.t0,elems.ecosϖ,elems.esinϖ,elems.i,elems.Ω]
    println(io, "Elements{$T}")
    println.(Ref(io), names,": ",vals)
end

# Fix this later...
#="""Allow alternate specification"""
function Elements(;m::T=0.0,P::T=0.0,t0::T=0.0,e::T=0.0,ϖ::T=0.0,i::T=0.0,Ω::T=0.0) where T<:Real
    esinϖ,ecosϖ = e .* sincos(ϖ)
    return new{T}(m,P,t0,ecosϖ,esinϖ,i,Ω)
end=#

"""Allow keywargs"""
Elements(;m::T=0.0,P::T=0.0,t0::T=0.0,ecosϖ::T=0.0,esinϖ::T=0.0,i::T=0.0,Ω::T=0.0) where T<:Real = Elements(m,P,t0,ecosϖ,esinϖ,i,Ω)

#= This overwrites the main constructor... Maybe not needed. I don't see folks using integers here.
"""Promotion to (atleast) floats"""
Elements(m::Real=0.0,P::Real=0.0,t0::Real=0.0,e::Real=0.0,ϖ::Real=0.0,i::Real=0.0,Ω::Real=0.0) = Elements(promote(m,P,t0,e,ϖ,i,Ω)...)
=#

abstract type InitialConditions{T} end
"""

Holds relevant initial conditions arrays. Uses orbital elements.
"""
struct ElementsIC{T<:AbstractFloat,V<:Vector{T},M<:Matrix{T}} <: InitialConditions{T}
    elements::M
    H::Vector{Int64}
    ϵ::M
    amat::M
    nbody::Int64
    m::V
    t0::T
    der::Bool

    function ElementsIC(elems::Union{String,Array{T,2}},H::Union{Array{Int64,1},Int64},t0::T;der::Bool=true) where T <: AbstractFloat
        # Check if only number of bodies was passed. Assumes fully nested.
        if typeof(H) == Int64; H::Vector{Int64} = [H,ones(H-1)...]; end
        ϵ = convert(Array{T},hierarchy(H))
        if typeof(elems) == String
            elements = convert(Array{T},readdlm(elems,',',comments=true))
        else
            elements = elems
        end
        nbody = H[1]
        m = elements[1:nbody,1]
        amat = amatrix(ϵ,m)
        return new{T,Vector{T},Matrix{T}}(elements,H,ϵ,amat,nbody,m,t0,der);
    end
end

"""

Collects `Elements` and produces an `ElementsIC` struct.
"""
function ElementsIC(t0::T,elems::Elements{T}...;H::Vector{Int64}) where T <: AbstractFloat
    
    elements = zeros(length(elems),7)
    function parse_system(elems::Elements{T}...) where T <: AbstractFloat
        bodies = Dict{Symbol,Elements}()
        for i in 1:length(elems)
            key = Meta.parse("b$i")
            bodies[key] = elems[i]
        end
        key = sort(collect(keys(bodies)))
        field = fieldnames(Elements)
        elements = zeros(length(bodies),7)
        for i in 1:length(bodies), elm in enumerate(fieldnames(Elements))
            elements[i,elm[1]] = getfield(bodies[key[i]],elm[2])
        end
        return elements
    end     
            
    elements .= parse_system(elems...)
    return ElementsIC(elements,H,t0)
end

"""Shows the elements array."""
Base.show(io::IO,::MIME"text/plain",ic::ElementsIC{T}) where {T} = begin
println(io,"ElementsIC{$T}\nOribital Elements: "); show(io,"text/plain",ic.elements); end;

"""

Holds relevant initial conditions arrays. Uses Cartesian coordinates. 
"""
struct CartesianIC{T<:AbstractFloat} <: InitialConditions{T}
    x::Array{T,2}
    v::Array{T,2}
    jac_init::Array{T,2}
    m::Array{T,1}
    t0::T
    nbody::Int64
    
    function CartesianIC(filename::String,x,v,jac_init,t0) where T <: AbstractFloat
        m = convert(Array{T},readdlm(filename,',',comments=true))
        nbody = length(m)
        return new{T}(x,v,jac_init,m,t0,nbody)
    end
end

# Include ics source files
const ics = ["kepler","kepler_init","setup_hierarchy","init_nbody"]
for i in ics; include("$(i).jl"); end
