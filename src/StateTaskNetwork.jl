"""
State task networks were originally developed for sequencing (high-level) and scheduling (low-level) problems for batch operations.
Batch operations means batches of material may be merged, or split, along workflows to produce various products.

I follow these references:

  1. Kondili, Emilia, Constantinos C. Pantelides, and Roger WH Sargent. "A general algorithm for short-term scheduling of batch operations—I. MILP formulation." Computers & Chemical Engineering 17.2 (1993): 211-227.
"""
module StateTaskNetwork

using Catlab

export StateTaskNetSch, AbstractStateTaskNet

"""
The STN has 2 types of nodes, *state* nodes represent initial, intermediate, and final products.
*Task* nodes represent the processing operations which transform input products to output products.
It looks like a Petri net, but it appears the original authors were not aware of them.
Coincidentally, S and T even mirror the "state" and "transition" language of PNs.
"""
@present StateTaskNetSch(FreeSchema) begin
    (S,T,I,O)::Ob
    is::Hom(I,S)
    it::Hom(I,T)
    os::Hom(O,S)
    ot::Hom(O,T)
    Label::AttrType
    state::Attr(S,Label)
    task::Attr(T,Label)
end

@abstract_acset_type AbstractStateTaskNet

end