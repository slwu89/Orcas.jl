using Catlab, AlgebraicPetri
using JuMP, HiGHS

pn = @acset LabelledPetriNet begin
    S=4
    sname=Symbol.("p" .* string.(1:4))
    T=4
    tname=Symbol.("t" .* string.(1:4))
    I=5
    is=[1,1,2,3,4]
    it=[1,2,3,3,4]
    O=6
    ot=[1,2,2,2,3,4]
    os=[2,2,3,3,4,1]
end

to_graphviz(pn)

# paper follow convention that matrices are places (rows) X transitions (cols)
tm = TransitionMatrices(pn)
pre, post = transpose(tm.input), transpose(tm.output)
C = post .- pre

# M places, N transitions
m0 = zeros(ns(pn))
m0[1] = 2

mf = zeros(ns(pn))
mf[4] = 2

# ----------------------------------------------------------------------
# formulation 1 (given in proposition 2):
# system F_1(K)
# - assume firing sequence σ of length K that leads from m0 to mf
# - X_it is binary and is 1 if trans t is fired at step i, 0 o/w

# decision variables
# X_i: binary vector of length N for each i ∈ 1,...,K
# M_i: integer vector of length M for each i ∈ 1,...,K (but fully specified by constraints, as seen below)

K = 4

jumpmod = JuMP.Model(HiGHS.Optimizer)

X = @variable(
    jumpmod,
    X[j ∈ 1:nt(pn), i ∈ 1:K],
    Bin
)

# eqn 5d
@constraint(
    jumpmod,
    [i ∈ 1:K],
    sum(X[:,i]) == 1
)

M = @variable(
    jumpmod,
    M[j ∈ 1:ns(pn), i ∈ 1:K],
    Int
)

# eqn 5a
@constraint(
    jumpmod,
    m0 ≥ pre * X[:,1]
)

@constraint(
    jumpmod,
    [i ∈ 2:K],
    M[:, i-1] ≥ pre * X[:,i]
)

# eqn 5b
@constraint(
    jumpmod,
    M[:, 1] == m0 + C * X[:, 1]
)

@constraint(
    jumpmod,
    [i ∈ 2:K],
    M[:, i] == M[:, i-1] + C * X[:, i]
)

# eqn 5c
@constraint(
    jumpmod,
    M[:, K] == mf
)

optimize!(jumpmod)

value.(X)
value.(M)

# ----------------------------------------------------------------------
# formulation 2 (given in proposition 3):
# system F_2(K)
# - allow multiple transitions to fire at the same time

# define 2 sub-problems associated with the original reachability problem
# which can be solved using F_2(K).