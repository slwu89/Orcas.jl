# for scratch work
using Catlab
using JuMP, HiGHS

# const VectorJuMPVar = Union{Float64, Vector{Float64}, Containers.DenseAxisArray{JuMP.VariableRef}, Vector{JuMP.VariableRef}}
const JuMPVar = Union{Float64, JuMP.VariableRef}

"""
Index an acset along multiple homs (columns)
"""
function multi_incident(acs, parts1, names1, parts2, names2)
  intersect(incident(acs, parts1, names1), incident(acs, parts2, names2))
end

#   * U is the set of units
#   * K is the relation between U (units) and T (tasks)
#   * K_i in the text is the set of units capable of performing task i, in 
#     here it is stn[incident(stn, i, :kt), :ku]
#   * I_j in the text is the set of tasks which can be performed by unit j,
#     here it is stn[incident(stn, j, :ku), :kt]
@present StateTaskNetSch(FreeSchema) begin
    (State,Task,Input,Output,Unit,UnTsk)::Ob
    is::Hom(Input,State)
    it::Hom(Input,Task)
    os::Hom(Output,State)
    ot::Hom(Output,Task)
    ut_u::Hom(UnTsk,Unit)
    ut_t::Hom(UnTsk,Task)

    Label::AttrType
    state::Attr(State,Label)
    task::Attr(Task,Label)
    unit::Attr(Unit,Label)

    Real::AttrType
    storage::Attr(State,Real)
    inprop::Attr(Input,Real)
    outprop::Attr(Output,Real)
    outtime::Attr(Output,Real)
    time::Attr(Task,Real)
    vmax::Attr(UnTsk,Real)
    vmin::Attr(UnTsk,Real)
end

to_graphviz(StateTaskNetSch, graph_attrs=Dict(:size=>"7",:ratio=>"fill"))

@abstract_acset_type AbstractStateTaskNet

@acset_type StateTaskNet(StateTaskNetSch, index=nameof.(generators(StateTaskNetSch,:Hom))) <: AbstractStateTaskNet

"""
The `StateTaskNetSch` schema augmented with attributes for optimization. The mathematical optimization
problem follows the formulation in:

  * Kondili, Emilia, Constantinos C. Pantelides, and Roger WH Sargent. "A general algorithm for short-term scheduling of batch operations—I. MILP formulation." Computers & Chemical Engineering 17.2 (1993): 211-227.

The additional elements are:

  * `JumpType`: an attribute type that can store either JuMP.VariableRef (pre-optimization) or Float64 (post-optimization)
  * `TimeType`: type that stores the actual times (`H` is the unique points)
  * `IJT`: this object is used to index task ``i``, unit ``j``, and time step ``t``
  * `ST`: this object is used to index state ``s`` and time step ``t``
  * `H`: time object (we use `H` to avoid name clashes, and to stand for "horizon", as in the paper)
  * `ij`: morphism from `IJT` to `K` (i.e; indexes task ``i`` and unit ``j``)
  * `t1`: morphism from `IJT` to `H`
  * `w_dv`: stores decision variable  ``W_{ijt} = 1`` if unit ``j`` starts processing task ``i`` at the beginning of time period ``t``; 0 otherwise
  * `b_dv`: stores decision variable ``B_{ijt}``, amount of material which starts undergoing task ``i`` in unit ``j`` at the beginning of time period ``t``
  * `s`: morphism from `ST` to `S`
  * `t2`: morphism from `ST` to `H`
  * `s_dv`: stores decision variable ``S_{st}``, amount of material stored in state ``s``, at the beginning of time period ``t``
"""
@present StateTaskNetOptSch <: StateTaskNetSch begin
  JumpType::AttrType
  TimeType::AttrType
  
  (Time,UnTskTime,StTime)::Ob

  t::Attr(Time,TimeType)

  utt_ut::Hom(UnTskTime,UnTsk)
  utt_t::Hom(UnTskTime,Time)
  # testing
  utt_unit::Hom(UnTskTime,Unit)
  utt_unit == compose(utt_ut, ut_u)
  utt_task::Hom(UnTskTime,Task)
  utt_task == compose(utt_ut, ut_t)
  # testing
  w_dv::Attr(UnTskTime,JumpType)
  b_dv::Attr(UnTskTime,JumpType)

  st_s::Hom(StTime,State)
  st_t::Hom(StTime,Time)
  s_dv::Attr(StTime,JumpType)
end

to_graphviz(StateTaskNetOptSch, graph_attrs=Dict(:size=>"7",:ratio=>"fill",:dpi=>"120"))

@abstract_acset_type AbstractStateTaskNetOpt <: AbstractStateTaskNet

@acset_type StateTaskNetOpt(StateTaskNetOptSch, index=nameof.(generators(StateTaskNetOptSch,:Hom))) <: AbstractStateTaskNetOpt

# """
# ``S_i``: set of states which feed task ``i``
# """
# function feeds(stn::AbstractStateTaskNet, i::Int)
#     stn[incident(stn, i, :it), :is]
# end
# feeds(stn::AbstractStateTaskNet, i) = feeds(stn, only(incident(stn, i, :task)))

# """
# ``\\overline{S_{i}}``: set of states which task ``i`` produces as its outputs
# """
# function generates(stn::AbstractStateTaskNet, i::Int)
#     stn[incident(stn, i, :ot), :os]
# end
# generates(stn::AbstractStateTaskNet, i) = generates(stn, only(incident(stn, i, :task)))

# """
# ``T_s``: set of tasks receiving material from state ``s``
# """
# function receives(stn::AbstractStateTaskNet, s::Int) 
#     stn[incident(stn, s, :os), :ot]
# end
# receives(stn::AbstractStateTaskNet, s) = receives(stn, only(incident(stn, s, :state)))

# """
# ``\\overline{T_{s}}``: set of tasks producing material in state ``s``
# """
# function produces(stn::AbstractStateTaskNet, s::Int)
#     stn[incident(stn, s, :is), :it]
# end
# produces(stn::AbstractStateTaskNet, s) = produces(stn, only(incident(stn, s, :state)))

# """
# ``K_i``: set of units capable of performing task ``i``
# """
# function units(stn::AbstractStateTaskNet, i::Int)
#     stn[incident(stn, i, :kt), :ku]
# end
# units(stn::AbstractStateTaskNet, i) = units(stn, only(incident(stn, i, :task)))

# make the example STN from paper (fig 3)
stn = @acset StateTaskNet{Symbol,Float64} begin
    State=9
    state=[:FeedA,:HotA,:Product1,:FeedB,:IntBC,:FeedC,:IntAB,:ImpureE,:Product2]
    storage=[Inf,100,Inf,Inf,150,Inf,200,100,Inf]
    Task=5
    task=[:Heating,:Reaction2,:Reaction1,:Reaction3,:Separation]
    Unit=4
    unit=[:Heater,:Reactor1,:Reactor2,:Still]
    Input=8
    is=[1,2,4,5,6,6,7,8]
    it=[1,2,3,2,3,4,4,5]
    inprop=[1,0.4,0.5,0.6,0.5,0.2,0.8,1]
    Output=7
    ot=[1,2,2,3,4,5,5]
    os=[2,3,7,5,8,7,9]
    outprop=[1,0.4,0.6,1,1,0.1,0.9]
    outtime=[1,2,2,2,1,2,1]
    UnTsk=8
    ut_u=[1,2,2,2,3,3,3,4]
    ut_t=[1,2,3,4,2,3,4,5]
    vmin=zeros(8)
    vmax=[100,80,80,80,50,50,50,200]
end

# check proportions correct and set time
for t in parts(stn, :Task)
    @assert sum(stn[incident(stn, t, :ot), :outprop]) == 1
    @assert sum(stn[incident(stn, t, :it), :inprop]) == 1
    stn[t,:time] = maximum(stn[incident(stn, t, :ot), :outtime])
end

# plotting
GRAPH_ATTRS = Dict(:rankdir=>"LR")
NODE_ATTRS = Dict(:shape => "plain", :style=>"filled")
EDGE_ATTRS = Dict(:splines=>"splines")

function to_graphviz_property_graph(stn::AbstractStateTaskNet;
    prog::AbstractString="dot", graph_attrs::AbstractDict=Dict(),
    node_attrs::AbstractDict=Dict(), edge_attrs::AbstractDict=Dict(), name::AbstractString="G", kw...)
  pg = PropertyGraph{Any}(; name = name, prog = prog,
    graph = merge!(GRAPH_ATTRS, graph_attrs),
    node = merge!(NODE_ATTRS, node_attrs),
    edge = merge!(EDGE_ATTRS, edge_attrs),
  )
  S_vtx = Dict(map(parts(stn, :State)) do s
    s => add_vertex!(pg; label="$(stn[s,:state])", shape="circle")
  end)
  T_vtx = Dict(map(parts(stn, :Task)) do t
    t => add_vertex!(pg; label="$(stn[t,:task])", shape="rectangle")
  end)
  U_vtx = Dict(map(parts(stn, :Unit)) do u
    u => add_vertex!(pg; label="$(stn[u,:unit])", shape="cylinder")
  end)

  edges = Dict{Tuple{Int,Int}, Int}()
  map(parts(stn, :Input)) do i
    edge = (S_vtx[stn[i, :is]], T_vtx[stn[i, :it]])
    edges[edge] = get(edges, edge, 0) + 1
  end
  map(parts(stn, :Output)) do o
    edge = (T_vtx[stn[o, :ot]], S_vtx[stn[o, :os]])
    edges[edge] = get(edges, edge, 0) + 1
  end
  map(parts(stn, :UnTsk)) do k
    edge = (U_vtx[stn[k,:ut_u]], T_vtx[stn[k,:ut_t]])
    edges[edge] = get(edges, edge, 0) + 1
  end
  for ((src, tgt),count) in edges
    # add_edge!(pg, src, tgt, label="$(count)")
    add_edge!(pg, src, tgt)
  end

  pg
end

to_graphviz_property_graph(stn) |> to_graphviz

# build optimization acset
stn_opt = StateTaskNetOpt{Symbol,Float64,JuMPVar,Int}()
copy_parts!(stn_opt, stn)
dt = minimum(stn_opt[:,:time])
H = 10

add_parts!(stn_opt, :Time, length(1:dt:H+1), t=Int.(collect(1:dt:H+1)))

StTime = product(
  FinSet(nparts(stn_opt, :State)),
  FinSet(nparts(stn_opt, :Time))  
)

add_parts!(
  stn_opt, :StTime, length(apex(StTime)),  
  st_s = legs(StTime)[1],
  st_t = legs(StTime)[2]
)

UnTaskTime = product(
  FinSet(nparts(stn_opt, :UnTsk)),
  FinSet(nparts(stn_opt, :Time))
)

add_parts!(
  stn_opt, :UnTskTime, length(apex(UnTaskTime)),  
  utt_ut = legs(UnTaskTime)[1],
  utt_t = legs(UnTaskTime)[2]
)
stn_opt[:,:utt_task] = stn_opt[:,(:utt_ut, :ut_t)]
stn_opt[:,:utt_unit] = stn_opt[:,(:utt_ut, :ut_u)]

# do the jump model
jumpmod = JuMP.Model(HiGHS.Optimizer)

# make decision vars
for i in parts(stn_opt, :UnTskTime)
  stn_opt[i, :w_dv] = @variable(jumpmod, binary=true)
  stn_opt[i, :b_dv] = @variable(jumpmod)
end

for i in parts(stn_opt, :StTime)
  stn_opt[i, :s_dv] = @variable(jumpmod)
end

# # constraints

# # 3.1.1: allocation constraints
# i: task, j: unit, t: time\

# helper fn
W_ijt(acs,i,j,t) = begin
  acs[
    only(intersect(
      incident(acs, i, :utt_task), incident(acs, j, :utt_unit), incident(acs, t, (:utt_t, :t))
    )),
    :w_dv
  ]
end

for j in parts(stn_opt, :Unit)
  Ij = stn_opt[incident(stn_opt, j, :ut_u), :ut_t]
  for i in Ij, t in stn_opt[:,:t]
    @constraint(
      jumpmod,

    )
  end
end

j=2
t=1
Ij = stn_opt[incident(stn_opt, j, :ut_u), :ut_t]
i=Ij[1]

# the t' indices in W_i'jt'
t=stn_opt[1,:t]
vcat(incident(stn_opt, t:t+stn_opt[i,:time]-1, (:utt_t, :t))...)

# the j index in W_ijt
incident(stn_opt, j, :utt_unit)

# the i index in W_ijt
incident(stn_opt, i, :utt_task)

# W_ijt
W_ijt(stn_opt, i, j, 11)

# the LHS sum term
sum(W_ijt(stn_opt,i′,j,t′) for i′ in Ij, t′ in t:t+stn_opt[i,:time]-1)

# it should not be for all t, it should only be until the last
# t for which it is possible to finish it.

# valid times for task i
stn_opt[:,:t] .+ stn_opt[i,:time] .- 1 .<= stn_opt[nparts(stn_opt,:Time),:t]

# valid times are leq than this
stn_opt[nparts(stn_opt,:Time),:t] - (stn_opt[i,:time] - 1)