#
# A simple and flexible atom implementation
#
export Atom, atomic_system, periodic_system, isolated_system

# Valid types for atom identifiers
const AtomId = Union{Symbol,AbstractString,Integer}

struct Atom{D, L<:Unitful.Length, V<:Unitful.Velocity, M<:Unitful.Mass}
    position::SVector{D, L}
    velocity::SVector{D, V}
    atomic_symbol::Symbol
    atomic_number::Int
    atomic_mass::M
    data::Dict{Symbol, Any}  # Store arbitrary data about the atom.
end
velocity(atom::Atom)      = atom.velocity
position(atom::Atom)      = atom.position
atomic_mass(atom::Atom)   = atom.atomic_mass
atomic_symbol(atom::Atom) = atom.atomic_symbol
atomic_number(atom::Atom) = atom.atomic_number
n_dimensions(::Atom{D}) where {D} = D

Base.getindex(at::Atom, x::Symbol) = hasfield(Atom, x) ? getfield(at, x) : getindex(at.data, x)
Base.haskey(at::Atom,   x::Symbol) = hasfield(Atom, x) || haskey(at.data, x)
function Base.get(at::Atom, x::Symbol, default)
    hasfield(Atom, x) ? getfield(at, x) : get(at.data, x, default)
end
function Base.keys(at::Atom)
    (:position, :velocity, :atomic_symbol, :atomic_number, :atomic_mass, keys(at.data)...)
end
Base.pairs(at::Atom) = (k => at[k] for k in keys(at))

"""
    Atom(identifier::AtomId, position::AbstractVector; kwargs...)
    Atom(identifier::AtomId, position::AbstractVector, velocity::AbstractVector; kwargs...)
    Atom(; atomic_symbol::Symbol, position, velocity=zeros(length(position))u"bohr/s", kwargs...)
    Atom(; atomic_number::Integer, position, velocity=zeros(length(position))u"bohr/s", kwargs...)

Construct an atomic species located at the cartesian coordinates `position` with (optionally)
the given cartesian `velocity`. Note that `AtomId = Union{Symbol,AbstractString,Integer}`.

Supported `kwargs` include `atomic_symbol`, `atomic_number`, `atomic_mass`, `charge`,
`multiplicity` as well as user-specific custom properties.

## Default values

If the `identifier` corresponds to a known atom, `atomic_symbol`, `atomic_number` and
`atomic_mass` are set according the `element(identifier)`.

Otherwise, the default values are:
- `atomic_symbol`: `identifier` if `identifier isa Symbol`, else `:?`
- `atomic_number`: `identifier` if `identifier isa Integer`, else `0`
- `atomic_mass`: `NaN*u"u"`

The default `velocity` is zero. The other properties have no default values.
"""
function Atom(identifier::AtomId,
              position::AbstractVector{L},
              velocity::AbstractVector{V}=zeros(length(position))u"bohr/s";
              atomic_symbol=nothing,
              atomic_number=nothing,
              atomic_mass=nothing,
              kwargs...) where {L <: Unitful.Length, V <: Unitful.Velocity}
    isnothing(atomic_symbol) && identifier isa Symbol && (atomic_symbol = identifier)
    isnothing(atomic_number) && identifier isa Integer && (atomic_number = identifier)
    if isnothing(atomic_symbol) | isnothing(atomic_number) | isnothing(atomic_mass)
        el = element(identifier)
        if !ismissing(el) # set appropriate defaults if available
            isnothing(atomic_symbol) && (atomic_symbol = Symbol(el.symbol))
            isnothing(atomic_number) && (atomic_number = el.number)
            isnothing(atomic_mass) && (atomic_mass = el.atomic_mass)
        else # set fallback defaults
            isnothing(atomic_symbol) && (atomic_symbol = :?)
            isnothing(atomic_number) && (atomic_number = 0)
            isnothing(atomic_mass) && (atomic_mass = NaN*u"u")
        end
    end
    Atom{length(position), L, V, typeof(atomic_mass)}(position, velocity, atomic_symbol,
                                    atomic_number, atomic_mass, Dict(kwargs...))
end
function Atom(id::AtomId, position::AbstractVector, velocity::Missing; kwargs...)
    Atom(id, position, zeros(length(position))u"bohr/s"; kwargs...)
end
function Atom(; position, velocity=zeros(length(position))u"bohr/s", kwargs...)
    atomic_number = get(kwargs, :atomic_number, missing)
    if !ismissing(atomic_number)
        return Atom(atomic_number::Integer, position, velocity; kwargs...)
    end
    atomic_symbol = get(kwargs, :atomic_symbol, missing)
    if !ismissing(atomic_symbol)
        return Atom(atomic_symbol::Symbol, position, velocity; kwargs...)
    end
    error("Atom(; ...) call requires either atomic_number of atomic_symbol among its keyword arguments")
end

"""
    Atom(atom::Atom; kwargs...)

Update constructor. Construct a new `Atom`, by amending the data contained
in the passed `atom` object.
Supported `kwargs` include `atomic_symbol`, `atomic_number`, `atomic_mass`, `charge`,
`multiplicity` as well as user-specific custom properties.

# Examples
Construct a standard hydrogen atom located at the origin
```julia-repl
julia> hydrogen = Atom(:H, zeros(3)u"Å")
```
and now amend its charge and atomic mass
```julia-repl
julia> Atom(atom; atomic_mass=1.0u"u", charge=-1.0u"e_au")
```
"""
Atom(atom::Atom; kwargs...) = Atom(; pairs(atom)..., kwargs...)

function Base.convert(::Type{Atom}, id_pos::Pair{<:AtomId,<:AbstractVector{<:Unitful.Length}})
    Atom(id_pos...)
end

Base.show(io::IO, at::Atom) = show_atom(io, at)
Base.show(io::IO, mime::MIME"text/plain", at::Atom) = show_atom(io, mime, at)


#
# Special high-level functions to construct atomic systems
#

"""
    atomic_system(atoms::AbstractVector, bounding_box, boundary_conditions; kwargs...)

Construct a [`FlexibleSystem`](@ref) using the passed `atoms` and boundary box and conditions.
Extra `kwargs` are stored as custom system properties.

# Examples
Construct a hydrogen molecule in a box, which is periodic only in the first two dimensions
```julia-repl
julia> bounding_box = [[10.0, 0.0, 0.0], [0.0, 10.0, 0.0], [0.0, 0.0, 10.0]]u"Å"
julia> boundary_conditions = [Periodic(), Periodic(), DirichletZero()]
julia> hydrogen = atomic_system([:H => [0, 0, 1.]u"bohr",
                                 :H => [0, 0, 3.]u"bohr"],
                                  bounding_box, boundary_conditions)
```
"""
atomic_system(atoms::AbstractVector{<:Atom}, box, bcs; kwargs...) = FlexibleSystem(atoms, box, bcs; kwargs...)
atomic_system(atoms::AbstractVector, box, bcs; kwargs...) = FlexibleSystem(convert.(Atom, atoms), box, bcs; kwargs...)


"""
    isolated_system(atoms::AbstractVector; kwargs...)

Construct a [`FlexibleSystem`](@ref) by placing the passed `atoms` into an infinite vacuum
(standard setup for modelling molecular systems). Extra `kwargs` are stored as custom system properties.

# Examples
Construct a hydrogen molecule
```julia-repl
julia> hydrogen = isolated_system([:H => [0, 0, 1.]u"bohr", :H => [0, 0, 3.]u"bohr"])
```
"""
function isolated_system(atoms::AbstractVector{<:Atom}; kwargs...)
    # Use dummy box and boundary conditions
    D = n_dimensions(first(atoms))
    atomic_system(atoms, infinite_box(D), fill(DirichletZero(), D); kwargs...)
end
isolated_system(atoms::AbstractVector; kwargs...) = isolated_system(convert.(Atom, atoms); kwargs...)


"""
    periodic_system(atoms::AbstractVector, bounding_box; fractional=false, kwargs...)

Construct a [`FlexibleSystem`](@ref) with all boundaries of the `bounding_box` periodic
(standard setup for modelling solid-state systems). If `fractional` is true, atom coordinates
are given in fractional (and not in Cartesian) coordinates.
Extra `kwargs` are stored as custom system properties.

# Examples
Setup a hydrogen molecule inside periodic BCs:
```julia-repl
julia> bounding_box = [[10.0, 0.0, 0.0], [0.0, 10.0, 0.0], [0.0, 0.0, 10.0]]u"Å"
julia> hydrogen = periodic_system([:H => [0, 0, 1.]u"bohr",
                                   :H => [0, 0, 3.]u"bohr"],
                                  bounding_box)
```

Setup a silicon unit cell using fractional positions
```julia-repl
julia> bounding_box = 10.26 / 2 * [[0, 0, 1], [1, 0, 1], [1, 1, 0]]u"bohr"
julia> silicon = periodic_system([:Si =>  ones(3)/8,
                                  :Si => -ones(3)/8],
                                 bounding_box, fractional=true)
```
"""
function periodic_system(atoms::AbstractVector,
                         box::AbstractVector{<:AbstractVector};
                         fractional=false, kwargs...)
    boundary_conditions = fill(Periodic(), length(box))
    lattice = hcat(box...)
    !fractional && return atomic_system(atoms, box, boundary_conditions; kwargs...)

    parse_fractional(atom::Atom) = atom
    function parse_fractional(atom::Pair)::Atom
        id, pos_fractional = atom
        Atom(id, lattice * pos_fractional)
    end
    atomic_system(parse_fractional.(atoms), box, boundary_conditions; kwargs...)
end
