# for scratch work
using Catlab

#   * U is the set of units
#   * K is the relation between U (units) and T (tasks)
#   * K_i in the text is the set of units capable of performing task i, in 
#     here it is stn[incident(stn, i, :kt), :ku]
#   * I_j in the text is the set of tasks which can be performed by unit j,
#     here it is stn[incident(stn, j, :ku), :kt]
@present StateTaskNetSch(FreeSchema) begin
    (S,T,I,O,U,K)::Ob
    is::Hom(I,S)
    it::Hom(I,T)
    os::Hom(O,S)
    ot::Hom(O,T)
    ku::Hom(K,U)
    kt::Hom(K,T)

    Label::AttrType
    state::Attr(S,Label)
    task::Attr(T,Label)

    Real::AttrType
    inprop::Attr(I,Real)
    outprop::Attr(O,Real)
    time::Attr(T,Real)
    storage::Attr(S,Real)
    vmax::Attr(K,Real)
    vmin::Attr(K,Real)
end

@abstract_acset_type AbstractStateTaskNet
