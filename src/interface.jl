import Base.position
import PeriodicTable

export AbstractSystem
export BoundaryCondition, DirichletZero, Periodic, infinite_box, isinfinite
export bounding_box, boundary_conditions, periodicity, n_dimensions, species_type
export position, velocity, element, atomic_mass, atomic_number, atomic_symbol
export atomkeys, hasatomkey

#
# Identifier for boundary conditions per dimension
#
abstract type BoundaryCondition end
struct DirichletZero <: BoundaryCondition end  # Dirichlet zero boundary (i.e. molecular context)
struct Periodic <: BoundaryCondition end  # Periodic BCs

infinite_box(::Val{1}) = [[Inf]]u"bohr"
infinite_box(::Val{2}) = [[Inf, 0], [0, Inf]]u"bohr"
infinite_box(::Val{3}) = [[Inf, 0, 0], [0, Inf, 0], [0, 0, Inf]]u"bohr"
infinite_box(dim::Int) = infinite_box(Val(dim))


#
# Abstract system
#
"""
    AbstractSystem{D}

A `D`-dimensional system.
"""
abstract type AbstractSystem{D} end

"""
    bounding_box(sys::AbstractSystem{D})

Return a vector of length `D` of vectors of length `D` that describe the "box" in which the system `sys` is defined.
"""
function bounding_box end

"""
    boundary_conditions(sys::AbstractSystem{D})

Return a vector of length `D` of `BoundaryCondition` objects, one for each direction described by `bounding_box(sys)`.
"""
function boundary_conditions end

"""
    species_type(::AbstractSystem)

Return the type used to represent a species or atom.
"""
function species_type end

"""Return vector indicating whether the system is periodic along a dimension."""
periodicity(sys::AbstractSystem) = [isa(bc, Periodic) for bc in boundary_conditions(sys)]

"""Returns true if the given system is infinite"""
isinfinite(sys::AbstractSystem{D}) where {D} = bounding_box(sys) == infinite_box(D)


"""
    n_dimensions(::AbstractSystem)
    n_dimensions(atom)

Return number of dimensions.
"""
n_dimensions(::AbstractSystem{D}) where {D} = D
# Note: Can't use ndims, because that is ndims(sys) == 1 (because of indexing interface)

# indexing and iteration interface...need to implement getindex and length, here are default dispatches for others
Base.size(s::AbstractSystem) = (length(s),)
Base.firstindex(::AbstractSystem) = 1
Base.lastindex(s::AbstractSystem) = length(s)
# default to 1D indexing
Base.iterate(sys::AbstractSystem, state = firstindex(sys)) =
    (firstindex(sys) <= state <= length(sys)) ? (@inbounds sys[state], state + 1) : nothing
Base.eltype(sys::AbstractSystem) = species_type(sys)

# TODO Support similar, push, ...

#
# Species property accessors from systems and species
#

"""The element corresponding to a species/atom (or missing)."""
element(id::Union{Symbol,AbstractString,Integer})  = PeriodicTable.elements[id]


"""
    position(sys::AbstractSystem{D})
    position(sys::AbstractSystem, index)
    position(species)

Return a vector of positions of every particle in the system `sys`. Return type
should be a vector of vectors each containing `D` elements that are
`<:Unitful.Length`. If an index is passed or the action is on a `species`,
return only the position of the referenced `species` / species on that index.
"""
position(sys::AbstractSystem)        = position.(sys)    # in Cartesian coordinates!
position(sys::AbstractSystem, index) = position(sys[index])


"""
    velocity(sys::AbstractSystem{D})
    velocity(sys::AbstractSystem, index)
    velocity(species)

Return a vector of velocities of every particle in the system `sys`. Return
type should be a vector of vectors each containing `D` elements that are
`<:Unitful.Velocity`. If an index is passed or the action is on a `species`,
return only the velocity of the referenced `species`. Returned value of the function
may be `missing`.
"""
velocity(sys::AbstractSystem)        = velocity.(sys)    # in Cartesian coordinates!
velocity(sys::AbstractSystem, index) = velocity(sys[index])


"""
    atomic_mass(sys::AbstractSystem)
    atomic_mass(sys::AbstractSystem, i)
    atomic_mass(species)

Vector of atomic masses in the system `sys` or the atomic mass of a particular `species` /
the `i`th species in `sys`. The elements are `<: Unitful.Mass`.
"""
atomic_mass(sys::AbstractSystem)        = atomic_mass.(sys)
atomic_mass(sys::AbstractSystem, index) = atomic_mass(sys[index])


"""
    atomic_symbol(sys::AbstractSystem)
    atomic_symbol(sys::AbstractSystem, i)
    atomic_symbol(species)

Vector of atomic symbols in the system `sys` or the atomic symbol of a particular `species` /
the `i`th species in `sys`.

The intention is that [`atomic_number`](@ref) carries the meaning
of identifying the type of a `species` (e.g. the element for the case of an atom), whereas
[`atomic_symbol`](@ref) may return a more unique identifier. For example for a deuterium atom
this may be `:D` while `atomic_number` is still `1`.
"""
atomic_symbol(sys::AbstractSystem)        = atomic_symbol.(sys)
atomic_symbol(sys::AbstractSystem, index) = atomic_symbol(sys[index])


"""
    atomic_number(sys::AbstractSystem)
    atomic_number(sys::AbstractSystem, i)
    atomic_number(species)

Vector of atomic numbers in the system `sys` or the atomic number of a particular `species` /
the `i`th species in `sys`.

The intention is that [`atomic_number`](@ref) carries the meaning
of identifying the type of a `species` (e.g. the element for the case of an atom), whereas
[`atomic_symbol`](@ref) may return a more unique identifier. For example for a deuterium atom
this may be `:D` while `atomic_number` is still `1`.
"""
atomic_number(sys::AbstractSystem)        = atomic_number.(sys)
atomic_number(sys::AbstractSystem, index) = atomic_number(sys[index])

"""
    atomkeys(sys::AbstractSystem)

Return the atomic properties, which are available in all atoms of the system.
"""
function atomkeys(system::AbstractSystem)
    atkeys = length(system) == 0 ? () : keys(system[1])
    filter(k -> hasatomkey(system, k), atkeys)
end

"""
    hasatomkey(system::AbstractSystem, x::Symbol)

Returns true whether the passed property available in all atoms of the passed system.
"""
hasatomkey(system::AbstractSystem, x::Symbol) = all(at -> haskey(at, x), system)

# Defaults for system
Base.pairs(system::AbstractSystem) = (k => system[k] for k in keys(system))
function Base.get(system::AbstractSystem, x::Symbol, default)
    haskey(system, x) ? getindex(system, x) : default
end
