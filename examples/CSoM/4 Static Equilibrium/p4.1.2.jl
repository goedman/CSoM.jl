using CSoM

ProjDir = dirname(@__FILE__)

l = 1.0       # Total length [m]
N = 5         # Number of nodes
els = N - 1   # Number of finite elements
nod = 2       # Number of nodes per finite elements
nodof = 1     # Degrees of freedom for each node
np_types = 1  # Number of proerty types
EA = 1.0e5    # Strain stiffness
nip = 1       # Number of integration points

struct_el = :Rod
fin_el = :Line

data = Dict(
  # Rod(nels, np_types, nip, finite_element(nod, nodof))
  :struc_el => Rod(4, 1, 1, Line(2, 1)),
  :properties => [2.0e3; 1.0e3],
  :etype => [2, 2, 1, 1],
  :x_coords => linspace(0, 1, 5),
  :support => [
    (1, [0])
    ],
  :fixed_freedoms => [
    (5, 1, 0.05)
    ]
)

data |> display
println()

@time m = FE4_1(data)
println()

if VERSION.minor > 5
  println("Displacements:")
  m.displacements' |> display
  println()

  println("Actions:")
  m.actions' |> display
  println()
else
  using DataTables
  dis_dt = DataTable(
    x_translation = m.displacements[:, 1],
  )
  fm_dt = DataTable(
    normal_force_1 = m.actions[:, 1],
    normal_force_2 = m.actions[:, 2]
  )
    
  display(dis_dt)
  println()
  display(fm_dt)
  
  using Plots
  gr(size=(400,500))

  x = 0.0:l/els:l
  u = convert(Array, dis_dt[:x_translation])
  N = vcat(
    convert(Array, fm_dt[:normal_force_1])[1],
    convert(Array, fm_dt[:normal_force_2])
  )
    
  p = Vector{Plots.Plot{Plots.GRBackend}}(2)
  titles = ["CSoM p4.2.1 u(x)", "CSoM p4.2.1 N(x)"]
   
  p[1]=plot(ylim=(0.0, 1.0), xlim=(0.0, 70.0),
    yflip=true, xflip=true, xlab="Normal force [N]",
    ylab="x [m]", title=titles[2]
  )
  vals = convert(Array, fm_dt[:normal_force_2])
  for i in 1:els
      plot!(p[1], 
        [vals[i], vals[i]],
        [(i-1)*l/els, i*l/els], color=:blue,
        color=:blue, fill=true, fillalpha=0.1, leg=false
      )
      delta = abs(((i-1)*l/els) - (i*l/els)) / 20.0
      y1 = collect(((i-1)*l/els):delta:(i*l/els))
      for j in 1:length(y1)
        plot!(p[1],
          [vals[i], 0.0],
          [y1[j], y1[j]], color=:blue, alpha=0.5
        )
      end
  end
  
  p[2] = plot(u, x, xlim=(0.0, 0.05), yflip=true,
    xlab="Displacement [m]", ylab="x [m]",
    fill=true, fillalpha=0.1, leg=false, title=titles[1])

  plot(p..., layout=(1, 2))
  savefig(ProjDir*"/p4.1.2.png")
  
end
