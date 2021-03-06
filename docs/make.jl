using PtFEM, SparseArrays, Documenter

DOC_ROOT = ptfem_path("..", "docs")

page_list = Array{Pair{String, Any}, 1}();
append!(page_list, [Pair("Introduction", "INTRO.md")])
append!(page_list, [Pair("Getting started", "GETTINGSTARTED.md")]);
append!(page_list, [Pair("Changes w.r.t. PtFEM", "CHANGES.md")])
append!(page_list, [Pair("PtFEM.jl documentation", "index.md")])
append!(page_list, [Pair("Versions", "VERSIONS.md")]);
append!(page_list, [Pair("Todo", "TODO.md")])
append!(page_list, [Pair("References", "REFERENCES.md")])

makedocs(
    format = Documenter.HTML(prettyurls = haskey(ENV, "GITHUB_ACTIONS")),
    root = DOC_ROOT,
    modules = Module[],
    sitename = "PtFEM",
    authors = "Rob Goedman",
    pages = page_list,
)

deploydocs(
    root = DOC_ROOT,
    repo = "github.com/PtFEM.jl.git",
    devbranch = "master",
    push_preview = true,
 )
