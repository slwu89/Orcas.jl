#  # Basic Scheduling Problems

using Catlab, DataFrames
using JuMP, HiGHS
using Orcas, Orcas.BasicSchedule

# Here we describe how to set up and solve basic scheduling problems. The models and
# solution methods in the `BasicSchedule` module are mostly from the following references:
#   1. Ulusoy, Gündüz, et al. Introduction to Project Modeling and Planning. Springer International Publishing, 2021.
#   2. Eiselt, Horst A., and Carl-Louis Sandblom. Decision analysis, location models, and scheduling problems. Springer Science & Business Media, 2013.
#   3. Eiselt, Horst A., and Carl-Louis Sandblom. Operations research: A model-based approach. Springer Nature, 2022.

# ## Basic Critial Path Method

# The critical path method (CPM) is a classic technique in operations research. Given a set of tasks which represent
# a project, and a set of precedence relationships between them (i.e.; A must be completed before B can start), and
# how long each task takes to complete, CPM finds the path from start to finish of tasks that are *critical*, meaning
# any delay will slow down the entire project. Tasks not on the critical path are called non-critical tasks, and
# CPM will calculate their *float time*, which is the amount they can be delayed before affecting the whole project.
# Critical tasks, of course, have a float time of zero.

# The first example is from Section 7.1 of Eiselt, H. A., & Sandblom, C. L. (2022). Operations research: A model-based approach.
# The *schema* we use to represent basic project networks derived from `SchGraph` in Catlab. There are 2 attributes
# for vertices, which represent tasks, giving the name of the task, and the time it takes to complete.

to_graphviz(SchProjGraph)

# We first input the graph from Table 7.1 as a `DataFrame`, and then generate a `ProjGraph` from it.

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

# Next we'll make a `ProjGraphCPM` which contains the extra attributes needed for CPM, and copy the parts
# from our `ProjGraph` into it.

projnet_cpm = ProjGraphCPM{Symbol,Int}()
copy_parts!(projnet_cpm, projnet)

# CPM has 3 steps. First a forward pass computes the earliest possible starting and finishing times of each activity.
# Next, a backwards pass latest possible starting and finishing times. Finally we use a depth-first search to find
# the critical path. Note that the function `forward_pass!` returns the topological sort of the vertices, needed for
# `backward_pass!`. Both functions are modifying. `find_critical_path` returns the vertices and edges on the critcal
# path, and we use the `Subobject` interface from Catlab to visualize the critical path.

toposort = forward_pass!(projnet_cpm)
backward_pass!(projnet_cpm, toposort)
cV, cE = find_critical_path(projnet_cpm)

cg = Subobject(projnet_cpm, V=cV, E=cE)
to_graphviz(cg, node_labels=:label)