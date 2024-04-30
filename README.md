# Orcas.jl

Operations Research with Composable, Algebraic Structure. At least the first two words will be implemented in this package, as to whether the rest will be, time will tell.

I use the [ACSet](https://github.com/AlgebraicJulia/ACSets.jl) data structure (although actually just importing all of [Catlab.jl](https://github.com/AlgebraicJulia/Catlab.jl) to do so) to structure problem definitions. ACSets (short for "attributed C-Set") are a data structure developed from applied category theory which generalize graphs, databases, etc. I find they allow an elegant expression of many classical problems. Also, I occasionally contribute to the AlgebraicJulia organization which supports them, and hope they become more popular, so this is an experiment to see just how useful they can be.

Right now, there is a single module `BasicSchedule` which contains basic functionality for planning/scheduling problems (derivatives of critical path method, etc). Material in it largely derives from the following references:

  1. Ulusoy, Gündüz, et al. Introduction to Project Modeling and Planning. Springer International Publishing, 2021.
  2. Eiselt, Horst A., and Carl-Louis Sandblom. Decision analysis, location models, and scheduling problems. Springer Science & Business Media, 2013.
  3. Eiselt, Horst A., and Carl-Louis Sandblom. Operations research: A model-based approach. Springer Nature, 2022.
