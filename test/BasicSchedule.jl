using Catlab, DataFrames
using JuMP, HiGHS
using Orcas, Orcas.BasicSchedule
using Test

# --------------------------------------------------------------------------------
# basic CPM examples

# look at the schema for projects
to_graphviz(SchProjGraph)

# ex: table 7.1 from Eiselt, H. A., & Sandblom, C. L. (2022). Operations research: A model-based approach.
proj_df = DataFrame(
    Activity = [:start,:A,:B,:C,:D,:E,:F,:G,:H,:I,:J,:end],
    Predecessor = [
        [], [:start], [:A], [:A,:B], [:B], [:B,:C], [:C,:D,:E],
        [:D], [:F,:G], [:F,:G], [:I], [:H,:J]
    ],
    Duration = [0,5,3,7,4,6,4,2,9,6,2,0]
)

projnet = make_ProjGraph(proj_df)
to_graphviz(projnet, node_labels=:label)

projnet_cpm = ProjGraphCPM{Symbol,Int}()
copy_parts!(projnet_cpm, projnet)

toposort = forward_pass!(projnet_cpm)
backward_pass!(projnet_cpm, toposort)
cV, cE = find_critical_path(projnet_cpm)

cg = Subobject(projnet_cpm, V=cV, E=cE)
to_graphviz(cg, node_labels=:label)

# ex: fig 7.4 from Eiselt, H. A., & Sandblom, C. L. (2022). Operations research: A model-based approach.
proj_df = DataFrame(
    Activity = [:start,:A,:B,:C,:D,:end],
    Predecessor = [
        [], [:start], [:start], [:A,:B], [:A,:B], [:C,:D]
    ],
    Duration = [0,5,4,7,8,0]
)

projnet = make_ProjGraph(proj_df)
to_graphviz(projnet, node_labels=:label)

projnet_cpm = ProjGraphCPM{Symbol,Int}()
copy_parts!(projnet_cpm, projnet)

toposort = forward_pass!(projnet_cpm)
backward_pass!(projnet_cpm, toposort)
cV, cE = find_critical_path(projnet_cpm)

cg = Subobject(projnet_cpm, V=cV, E=cE)
to_graphviz(cg, node_labels=:label)

# "reduce" time for D to 7
proj_df[proj_df.Activity .== :D, :Duration] .= 7
projnet = make_ProjGraph(proj_df)

projnet_cpm = ProjGraphCPM{Symbol,Int}()
copy_parts!(projnet_cpm, projnet)

toposort = forward_pass!(projnet_cpm)
backward_pass!(projnet_cpm, toposort)
cV, cE = find_critical_path(projnet_cpm)

cg = Subobject(projnet_cpm, V=cV, E=cE)
to_graphviz(cg, node_labels=:label)

# --------------------------------------------------------------------------------
# CPM with acceleration as a LP problem

# view the schema
to_graphviz(SchAccelProjGraph)

# ex: Fig III.12 from Eiselt, H. A., & Sandblom, C. L. (2013). Decision analysis, location models, and scheduling problems.
proj_df = DataFrame(
    Activity = [:start,:A,:B,:C,:D,:E,:end],
    Predecessor = [
        [], [:start], [:start], [:A], [:A], [:B,:C], [:D,:E]
    ],
    Max = [0,3,5,4,4,5,0],
    Min = [0,3,2,1,1,2,0],
    Cost = [0,0,200,200,100,600,0]
)

projnet = make_AccelProjGraph(proj_df)
to_graphviz(projnet, node_labels=:label)

proj_jump = optimize_AccelProjGraph!(projnet, 10)

# migrate the AccelProjGraph to ProjGraph to do CPM
projnet_cpm = ProjGraphCPM{Symbol,Int}()
copy_parts!(projnet_cpm, projnet)

projnet_cpm[:,:duration] = projnet[:,:x]

toposort = forward_pass!(projnet_cpm)
backward_pass!(projnet_cpm, toposort)
cV, cE = find_critical_path(projnet_cpm)

cg = Subobject(projnet_cpm, V=cV, E=cE)
to_graphviz(cg, node_labels=:label)

# --------------------------------------------------------------------------------
# basic CPM/scheduling as LP

# ex: sec 4.3 from Ulusoy, G., Hazır, Ö., Ulusoy, G., & Hazır, Ö. (2021). Introduction to Project Modeling and Planning 
proj_df = DataFrame(
    Activity = [:start,:A,:B,:C,:D,:E,:F,:G,:end],
    Predecessor = [
        [], [:start], [:start], [:start], [:A], [:C], [:C], [:D,:B,:E], [:F,:G]
    ],
    Duration = [0,5,6,4,5,3,6,7,0]
)

projnet = make_ProjGraph(proj_df)
to_graphviz(projnet, node_labels=:label)

projnet_lp = ProjGraphLP{Symbol,Int,VarType}()
copy_parts!(projnet_lp, projnet)

proj_jump = optimize_ProjGraphLP(projnet_lp)

# solutions from book
@assert projnet_lp[1,:t] == 0
@assert projnet_lp[nv(projnet_lp),:t] == 17

# redo as LP: fig 7.4 from Eiselt, H. A., & Sandblom, C. L. (2022). Operations research: A model-based approach.
proj_df = DataFrame(
    Activity = [:start,:A,:B,:C,:D,:end],
    Predecessor = [
        [], [:start], [:start], [:A,:B], [:A,:B], [:C,:D]
    ],
    Duration = [0,5,4,7,8,0]
)

projnet = make_ProjGraph(proj_df)
to_graphviz(projnet, node_labels=:label)

projnet_lp = ProjGraphLP{Symbol,Int,VarType}()
copy_parts!(projnet_lp, projnet)

proj_jump = optimize_ProjGraphLP(projnet_lp)
projnet_lp[:,:t]

# --------------------------------------------------------------------------------
# CPM/optimization of NPV

proj_df = DataFrame(
    Activity = [:start,:A,:B,:C,:D,:E,:F,:G,:H,:I,:J,:K,:L,:end],
    Predecessor = [
        [], [:start], [:start], [:start], [:B], [:B], [:B], [:C,:F], [:A], [:D], [:F], [:I,:E,:J], [:K,:G], [:H,:L]
    ],
    Duration = [0,6,5,3,1,6,2,1,4,3,2,3,5,0]
)

projnet = make_ProjGraph(proj_df)
to_graphviz(projnet, node_labels=:label)

projnet_npv = ProjGraphNPV{Symbol,Int,Union{Containers.DenseAxisArray,Float64},Float64}()
copy_parts!(projnet_npv, projnet)

projnet_npv[:,:C] = [0,-140,318,312,-329,153,193,361,24,33,387,-386,171,0]

# before running NPV minimization, need to run forward/backward passes
toposort = forward_pass!(projnet_npv)
backward_pass!(projnet_npv, toposort)

cV, cE = find_critical_path(projnet_npv)

cg = Subobject(projnet_npv, V=cV, E=cE)
to_graphviz(cg, node_labels=:label)

# optimize it
optimize_ProjGraphNPV(projnet_npv, 0.01)

# negative cash flow tasks are scheduled as late as possible
neg_cash = [:A,:H,:D,:I]
neg_cash_ix = vcat(incident(projnet_npv, neg_cash, :label)...)
@test projnet_npv[neg_cash_ix, :lf] == Float64.(projnet_npv[neg_cash_ix, :x])

# non-critical positive cash flow tasks are scheduled as early as possible
pos_cash = [:C,:F,:G,:J]
pos_cash_ix = vcat(incident(projnet_npv, pos_cash, :label)...)

@test projnet_npv[pos_cash_ix, :ef] == Float64.(projnet_npv[pos_cash_ix, :x])
