"""
Schemas and tools for basic project scheduling problems (critical path, LP formulations, etc).
Most of the content in this module is from the following references:

  1. Ulusoy, Gündüz, et al. Introduction to Project Modeling and Planning. Springer International Publishing, 2021.
  2. Eiselt, Horst A., and Carl-Louis Sandblom. Decision analysis, location models, and scheduling problems. Springer Science & Business Media, 2013.
  3. Eiselt, Horst A., and Carl-Louis Sandblom. Operations research: A model-based approach. Springer Nature, 2022.
"""
module BasicSchedule
export SchProjGraph, AbstractProjGraph, ProjGraph, make_ProjGraph, 
    SchProjGraphLP, AbstractProjGraphLP, SchProjGraphLP, optimize_ProjGraphLP, 
    SchProjGraphCPM, AbstractProjGraphCPM, ProjGraphCPM, forward_pass!, backward_pass!, find_critical_path, 
    SchProjGraphNPV, AbstractProjGraphNPV, ProjGraphNPV, optimize_ProjGraphNPV, 
    SchAccelProjGraph, AbstractAccelProjGraph, AccelProjGraph, make_AccelProjGraph, optimize_AccelProjGraph!

using Catlab, DataFrames
using JuMP, HiGHS

const VarType = Union{JuMP.VariableRef,Float64}
const VectorVarType = Union{Vector{JuMP.VariableRef},Vector{Float64}}

# notes:
# 1. a somewhat more principled way to handle the start/end nodes in AoN
#    network would be to have 2 dummy objects (S,E) with 1 element in their sets
#    which point to the nodes that are supposed to be starting and ending.

# --------------------------------------------------------------------------------
# basic AoN schema

"""
The basic schema for AoN (activity on node) style
project networks. Vertices are tasks and edges indicate
precedence relations between tasks. It is assumed that instances on
this schema are DAGs, to prevent nonsensical task relationships.
Labels on vertices are to assist in reading the network,
and durations give the amount of time required to complete
each task.
"""
@present SchProjGraph <: SchLabeledGraph begin
    Duration::AttrType
    duration::Attr(V,Duration)
end

"""
An abstract acset type that inherits from `AbstractGraph`
"""
@abstract_acset_type AbstractProjGraph <: AbstractGraph

"""
A concrete acset type that inherits from `AbstractProjGraph`
"""
@acset_type ProjGraph(SchProjGraph, index=[:src,:tgt]) <: AbstractProjGraph

"""
Make a `ProjGraph` acset from a `DataFrame` with columns for
`Activity`, `Predecessor`, and `Duration`.
"""
function make_ProjGraph(input::DataFrame)
    g = @acset ProjGraph{Symbol,Int} begin
        V = size(input,1)
        label = input.Activity
        duration = input.Duration
    end

    for r in eachrow(input)
        if length(r.Predecessor) > 0
            prednodes = vcat(incident(g, r.Predecessor, :label)...)
            node = only(incident(g, r.Activity, :label))
            add_edges!(g, prednodes, fill(node, length(r.Predecessor)))
        else
            continue
        end
    end

    return g
end

# --------------------------------------------------------------------------------
# AoN + LP

"""
This schema inherits from `SchProjGraph` and is used to model
the basic project scheduling problem as an LP problem.
"""
@present SchProjGraphLP <: SchProjGraph begin
    DecisionVar::AttrType
    t::Attr(V,DecisionVar)
end

"""
An abstract acset type that inherits from `AbstractProjGraph`
"""
@abstract_acset_type AbstractProjGraphLP <: AbstractProjGraph

"""
A concrete acset type that inherits from `AbstractProjGraphLP`
"""
@acset_type ProjGraphLP(SchProjGraphLP, index=[:src,:tgt]) <: AbstractProjGraphLP


"""
Formulate and solve the basic scheduling problem
according to the method in 4.3 from Ulusoy, G., & Hazır, Ö. (2021). Introduction to Project Modeling and Planning .

Returns a `JuMP.Model` object, and updates the input `g` with the optimized decision variables.
"""
function optimize_ProjGraphLP(g::T) where {T<:AbstractProjGraphLP}    
    jumpmod = JuMP.Model(HiGHS.Optimizer)

    # dv: when does each task start?
    @variable(
        jumpmod,
        0 ≤ t[v in vertices(g)]
    )
    
    g[:,:t] = jumpmod[:t]
    
    # wlog, start project begins at 0
    @constraint(
        jumpmod,
        g[1,:t] == 0
    )
    
    # projects can only begin after predecessors finish
    @constraint(
        jumpmod,
        [e ∈ edges(g)],
        g[e, (:tgt, :t)] - g[e, (:src, :t)] ≥ g[e, (:src, :duration)]
    )
    
    # minimize overall time
    @objective(
        jumpmod,
        Min,
        g[nv(g),:t]
    )
    
    optimize!(jumpmod)
        
    g[:,:t] = value.(g[:,:t])    

    return jumpmod
end


# --------------------------------------------------------------------------------
# AoN for CPM

"""
The schema for a basic project that will be subject to
critical path analysis. It inherits from `SchProjGraph`
"""
@present SchProjGraphCPM <: SchProjGraph begin
  es::Attr(V,Duration) # earliest possible starting times
  ef::Attr(V,Duration) # earliest possible finishing times
  ls::Attr(V,Duration) # latest possible starting times
  lf::Attr(V,Duration) # latest possible finishing times
  float::Attr(V,Duration) # "float" time of task
end

"""
An abstract acset type that inherits from `AbstractProjGraph`
"""
@abstract_acset_type AbstractProjGraphCPM <: AbstractProjGraph

"""
A concrete acset type that inherits from `AbstractProjGraphCPM`
"""
@acset_type ProjGraphCPM(SchProjGraphCPM, index=[:src,:tgt]) <: AbstractProjGraphCPM

"""
Perform a forward pass of the critical path sweep. This identifies
the earliest starting times `es` and finishing times `ef` for each node.
This assumes that the node with part id `1` is the start, and that the
node with highest part id is the end, and the graph is a DAG. Returns
the topological sort of the nodes.

See Eiselt, H. A., & Sandblom, C. L. (2013). Decision analysis, location models, and scheduling problems.
"""
function forward_pass!(g::T) where {T<:AbstractProjGraphCPM}
    g[1, :es] = 0
    g[1, :ef] = 0

    # also serves as a check `g` is actually a DAG
    toposort = topological_sort(g)

    for v in toposort[2:end]
        pred = collect(inneighbors(g, v))
        g[v, :es] = maximum(g[pred, :ef])
        g[v, :ef] = g[v, :es] + g[v, :duration]
    end

    return toposort
end

"""
Perform a backward pass of the critical path sweep. This identifies
the latest starting times `ls` and finishing times `lf` for each node.
It also computes the `float`, the maximum acceptable delay for each node.
This assumes that the graph is a DAG.

See Eiselt, H. A., & Sandblom, C. L. (2013). Decision analysis, location models, and scheduling problems.
"""
function backward_pass!(g::T, toposort) where {T<:AbstractProjGraphCPM}
    reverse!(toposort)

    g[toposort[1], :lf] = g[toposort[1], :es]
    g[toposort[1], :ls] = g[toposort[1], :es]
    
    for v in toposort[2:end]
        succ = collect(outneighbors(g, v))
        g[v, :lf] = minimum(g[succ, :ls])
        g[v, :ls] = g[v, :lf] - g[v, :duration]
    end

    # float: delay acceptable for each task w/out delaying completion of project
    g[:,:float] = g[:,:lf] - g[:,:ef]
end

"""
Find a critical path, assumes that the forward and backward passes have been
completed.

See Eiselt, H. A., & Sandblom, C. L. (2013). Decision analysis, location models, and scheduling problems.
"""
function find_critical_path(g::T) where {T<:AbstractProjGraphCPM}
    # set of critical activities 
    ca = incident(g, 0, :float)

    # stack of nodes for dfs search
    S = [1]
    seen = zeros(Bool, nv(g))
    # edges on the critical path
    ce = Int[]

    while !isempty(S)
        v = pop!(S)
        if !seen[v]
            seen[v] = true
            # only iterate over neighbors who are critical actvities
            for w in intersect(outneighbors(g, v), ca)
                if g[v, :lf] == g[w, :es]
                    push!(S, w)
                    push!(ce, only(edges(g, v, w)))
                end
            end
        end
    end

    return findall(seen), ce
end

# --------------------------------------------------------------------------------
# AoN + maximizing NPV with no resource constraints

"""
The schema for a project that will be subject to net present value optimization,
it inherits from `SchProjGraphCPM` because the optimization assumes that values
from the critical path method have been calculated.
"""
@present SchProjGraphNPV <: SchProjGraphCPM begin
    VarType::AttrType
    CostType::AttrType
    x::Attr(V,VarType) # decision var: finish time of task
    C::Attr(V,CostType) # cash flow of task
end

"""
An abstract acset type that inherits from `AbstractProjGraphCPM`
"""
@abstract_acset_type AbstractProjGraphNPV <: AbstractProjGraphCPM

"""
A concrete acset type that inherits from `AbstractProjGraphNPV`
"""
@acset_type ProjGraphNPV(SchProjGraphNPV, index=[:src,:tgt]) <: AbstractProjGraphNPV

"""
Formulate and solve the maximization of NPV under no resource constraints
according to the model in 4.4.1 from Ulusoy, G., & Hazır, Ö. (2021). Introduction to Project Modeling and Planning.

α is the discount rate (cost of capital).

Returns a `JuMP.Model` object, and updates the input `g` with the optimized decision variables.
"""
function optimize_ProjGraphNPV(g::T, α::Float64) where {T<:AbstractProjGraphNPV}

    jumpmod = JuMP.Model(HiGHS.Optimizer)

    # dv: when does each task finish + the constraint for them to all actually finish (4.25, 4.27)
    for v in vertices(g)
        g[v,:x] = @variable(
            jumpmod,
            [t ∈ g[v,:ef]:g[v,:lf]],
            Bin
        )
        @constraint(
            jumpmod,
            sum(g[v,:x]) == 1
        )
    end

    # con: precedence relations among activities (4.26)
    for e in edges(g)
        tgt_end = sum(t->t * g[e, (:tgt, :x)][t], g[e, (:tgt, :ef)]:g[e, (:tgt, :lf)])
        src_end = sum(t->t * g[e, (:src, :x)][t], g[e, (:src, :ef)]:g[e, (:src, :lf)])
        @constraint(
            jumpmod,
            tgt_end - src_end ≥ g[e, (:tgt, :duration)]
        )
    end

    # obj: maximize NPV
    @expression(jumpmod, npv[v in vertices(g)], sum(exp(-α*t)*g[v, :C]*g[v, :x][t] for t in g[v, :ef]:g[v, :lf]))
    @objective(jumpmod, Max, sum(sum.(jumpmod[:npv])))
        
    optimize!(jumpmod)
        
    for v in vertices(g)
        g[v,:x] = sum(t*value(g[v,:x][t]) for t in g[v,:ef]:g[v,:lf])
    end

    return jumpmod
end

# --------------------------------------------------------------------------------
# Proj scheduling + resource constraints
# from section beginning on p. 320 in Eiselt, Horst A., and Carl-Louis Sandblom. Decision analysis, location models, and scheduling problems. Springer Science & Business Media, 2013.

# we want 2 objs:
# 1. Min proj completion time
# 2. Min max resource useage

# dvs:
# 1. for each task, binary x_t if its finished then or not

# need cons:
# 1. precedence cons
# 2. sum x_t = 1 for each task (ensure it actually finishes)


# --------------------------------------------------------------------------------
# AoN + acceleration (crashing)
# NOTE: this doesn't fit into the hierarchy right now, unfortunately, but it should?
# NOTE: generalize the obj of the LP to 2-objs: min cost and min time (right now time is hard constraint)

"""
Schema for a project graph that will be optimized for project
acceleration.

Uses description in section 1.3 Project Acceleration in Eiselt, H. A., & Sandblom, C. L. (2013). Decision analysis, location models, and scheduling problems.
"""
@present SchAccelProjGraph <: SchLabeledGraph begin
    VarType::AttrType
    TimeType::AttrType
    CostType::AttrType
    x::Attr(V,VarType) # decision var: duration
    y::Attr(V,VarType) # decision var: start time
    tmax::Attr(V,TimeType) # normal duration
    tmin::Attr(V,TimeType) # minimum duration
    Δc::Attr(V,CostType) # cost to reduce duration by one unit
end

"""
Abstract type for project graph under acceleration, inherits from `AbstractGraph`
"""
@abstract_acset_type AbstractAccelProjGraph <: AbstractGraph

"""
Concrete acset type for project graph under acceleration, inherits from `AbstractAccelProjGraph`
"""
@acset_type AccelProjGraph(SchAccelProjGraph, index=[:src,:tgt]) <: AbstractAccelProjGraph

"""
Make a `AccelProjGraph` acset from a `DataFrame` with columns for
`Activity`, `Predecessor`, `Max`, `Min`, and `Cost`.
"""
function make_AccelProjGraph(input::DataFrame)
    g = @acset AccelProjGraph{Symbol,VarType,Int,Float64} begin
        V = size(input,1)
        label = input.Activity
        tmax = input.Max
        tmin = input.Min
        Δc = input.Cost
    end

    for r in eachrow(input)
        if length(r.Predecessor) > 0
            prednodes = vcat(incident(g, r.Predecessor, :label)...)
            node = only(incident(g, r.Activity, :label))
            add_edges!(g, prednodes, fill(node, length(r.Predecessor)))
        else
            continue
        end
    end

    return g
end

"""
Formulate and solve the project acceleration problem with a prespecified time `Tbar`
according to the method in Eiselt, H. A., & Sandblom, C. L. (2013). Decision analysis, location models, and scheduling problems. 

Returns a `JuMP.Model` object, and updates the input `g` with the optimized decision variables.
"""
function optimize_AccelProjGraph!(g::T, Tbar) where {T<:AbstractAccelProjGraph}    
    jumpmod = JuMP.Model(HiGHS.Optimizer)
    
    # the decision vars
    @variable(
        jumpmod, 
        g[v,:tmin] ≤ x_j[v ∈ vertices(g)] ≤ g[v,:tmax] 
    )
    
    g[:,:x] = jumpmod[:x_j]
    
    @variable(
        jumpmod, 
        0 ≤ y_j[v ∈ vertices(g)]
    )
    
    g[:,:y] = jumpmod[:y_j]
    
    # final time constraint
    nt = only(incident(g, :end, :label))
    @constraint(
        jumpmod,
        final_time,
        g[nt,:y] ≤ Tbar
    )
    
    # precedence constraints
    for j in vertices(g)
        pred = collect(inneighbors(g,j))
        if length(j) > 0
            @constraint(
                jumpmod,
                [i ∈ pred],
                g[j,:y] ≥ g[i,:y] + g[i,:x]
            )
        end
    end
    
    # minimize costs
    @objective(
        jumpmod,
        Max,
        sum(g[v,:Δc] * g[v,:x] for v in vertices(g))
    )
    
    optimize!(jumpmod)
    
    g[:,:x] = value.(g[:,:x])
    g[:,:y] = value.(g[:,:y])

    return jumpmod
end

end