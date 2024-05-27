#  # State Task Networks

using Catlab
using Orcas, Orcas.StateTaskNetwork

# State task networks (STN) were initially introduced in two papers, [Kondili, Emilia, Constantinos C. Pantelides, and Roger WH Sargent. "A general algorithm for short-term scheduling of batch operations—I. MILP formulation." Computers & Chemical Engineering 17.2 (1993): 211-227](https://doi.org/10.1016/0098-1354(93)80015-F)
# and [Shah, N., C. C. Pantelides, and R. W. H. Sargent. "A general algorithm for short-term scheduling of batch operations—II. Computational issues." Computers & chemical engineering 17.2 (1993): 229-244](https://doi.org/10.1016/0098-1354(93)80016-G).

# Here we reproduce Figure 3 from the first paper. Note that in the original paper the diagram
# was only used as a conceptual, informal guide to the model. Because acsets take graphical depictions seriously,
# the set of Units (equipment) is also visualized just like the other sets and functions in the schema.

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

for t in parts(stn, :Task)
    @assert sum(stn[incident(stn, t, :ot), :outprop]) == 1
    @assert sum(stn[incident(stn, t, :it), :inprop]) == 1
    stn[t,:time] = maximum(stn[incident(stn, t, :ot), :outtime])
end

to_graphviz_property_graph(stn) |> to_graphviz