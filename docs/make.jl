using Orcas
using Documenter
using Literate

example_base = joinpath(dirname(@__FILE__), "src")
adliterate = [
        ("BasicSchedule.jl", "BasicSchedule"),
        ("StateTaskNetwork.jl", "StateTaskNetwork")
    ]
literate_subdir = joinpath(example_base, "literate")
isdir(literate_subdir) || mkdir(literate_subdir)

for (source, target) in adliterate
    fsource, ftarget = joinpath.(example_base, [source, target])
    Literate.markdown(
        fsource,
        example_base,
        name=target,
        credit=true
    )
end

makedocs(;
    modules=[Orcas],
    authors="Sean L. Wu <slwood89@gmail.com>",
    sitename="Orcas.jl",
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
        "Basic Scheduling" => [
            "BasicSchedule.md",
        ],
        "State Task Networks" => [
            "StateTaskNetwork.md"
        ],
        "Reference" => "reference.md"
    ],
)

# deploydocs(;
#     target = "build",
#     repo = "github.com/adolgert/Fleck.jl.git",
#     branch = "gh-pages"
# )
