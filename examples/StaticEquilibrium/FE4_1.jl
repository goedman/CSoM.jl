using Docile

@comment """
# FE4_1
"""

"""
###FE4_1

Backbone method for static equilibrium analysis of a rod.

### Constructors
```julia
FE4_1(data::Dict)
```
### Arguments
```julia
* `data` : Dictionary containing all input data

   nels:     Number of elements
   np_types: Number of element types
```
### Notes

Special handling is needed if a column contains `Symbol`s. In JSON a `Symbol`
like `:Fe` is encoded as ":Fe". Optionally, `json2df()` turns these
`ASCIIString`s back to `Symbol`s based on the convert_symbols argument.

### Examples
```julia
syms = [:A, :B, :C, :D]
df = DataFrame(Any[Int64[], Symbol[], Float64[], Symbol[]], syms)
push!(df, [3  :B 6.0 :Fe])
push!(df, [9  :H 9.0 :Si])
push!(df, [1  :O 1.0 :H])
df |> display
println()
jsonstr = df2json(df, pretty_print=true);
df1=json2df(jsonstr)
println(df1)
println()

jsonstr2 = df2json(df, pretty_print=false);
df2=json2df(jsonstr2)
println(df2)
println()

jsonstr3 = df2json(df, cols=[:A, :C], pretty_print=true);
df3=json2df(jsonstr3)
println(df3)
println()

df4=json2df(jsonstr3, convert_symbols=false);
println(df4)
println()

```
"""
function FE4_1(data::Dict{Symbol, Any})
  
  # Parse & check FEdict data
  
  if :element_type in keys(data)
    element_type::ElementType = data[:element_type]
  else
    println("No element type specified.")
    return
  end
  
  ndim::Int64 = element_type.ndim
  nst::Int64 = element_type.nst
  
  # Add radial stress
  if ndim == 3 && element_type.axisymmetric
    nst = 4
  end
  
  element::Element = element_type.element
  @assert typeof(element) <: Element
  
  if typeof(element) == Line
    (nels, nn) = mesh_size(element, element_type.nxe)
  elseif typeof(element) == Triangle || typeof(element) == Quadrilateral
    (nels, nn) = mesh_size(element, element_type.nxe, element_type.nye)
  elseif typeof(element) == Hexahedron
    (nels, nn) = mesh_size(element, element_type.nxe, element_type.nye, element_type.nze)
  else
    println("$(typeof(element)) is not a known finite element.")
    return
  end
   
  nodof = element.nodof         # Degrees of freedom per node
  ndof = element.nod * nodof    # Degrees of freedom per element
  
  # Update penalty if specified in FEdict
  
  penalty = 1e20
  if :penalty in keys(data)
    penalty = data[:penalty]
  end
  
  # Allocate all arrays
  
  # Start with arrays to be initialized from FEdict
  
  if :properties in keys(data)
    prop = zeros(size(data[:properties], 1), size(data[:properties], 2))
    for i in 1:size(data[:properties], 1)
      prop[i, :] = data[:properties][i, :]
    end
  else
    println("No :properties key found in FEdict")
  end
  
  nf = ones(Int64, nodof, nn)
  #
  if :support in keys(data)
    for i in 1:size(data[:support], 1)
      nf[:, data[:support][i][1]] = data[:support][i][2]
    end
  end
  #
  
  x_coords = zeros(nn)
  if :x_coords in keys(data)
    x_coords = data[:x_coords]
  end
  
  y_coords = zeros(nn)
  if :y_coords in keys(data)
    y_coords = data[:y_coords]
  end
  
  z_coords = zeros(nn)
  if :z_coords in keys(data)
    z_coords = data[:z_coords]
  end

  etype = ones(Int64, nels)
  if :etype in keys(data)
    etype = data[:etype]
  end
  
  # All other arrays
  
  points = zeros(element_type.nip, ndim)
  g = zeros(Int64, ndof)
  g_coord = zeros(ndim,nn)
  fun = zeros(element.nod)
  coord = zeros(element.nod, ndim)
  gamma = zeros(nels)
  jac = zeros(ndim, ndim)
  g_num = zeros(Int64, element.nod, nels)
  der = zeros(ndim, element.nod)
  deriv = zeros(ndim, element.nod)
  bee = zeros(nst,ndof)
  km = zeros(ndof, ndof)
  mm = zeros(ndof, ndof)
  gm = zeros(ndof, ndof)
  kg = zeros(ndof, ndof)
  eld = zeros(ndof)
  weights = zeros(element_type.nip)
  g_g = zeros(Int64, ndof, nels)
  num = zeros(Int64, element.nod)
  actions = zeros(nels, ndof)
  displacements = zeros(size(nf, 1), ndim)
  gc = ones(ndim, ndim)
  dee = zeros(nst,nst)
  sigma = zeros(nst)
  axial = zeros(nels)
  
  formnf!(nodof, nn, nf)
  neq = maximum(nf)
  kdiag = round(Int64, zeros(neq))
  #@show nf
  
  # Set global numbering, coordinates and array sizes
  
  ell = zeros(nels)
  if :x_coords in keys(data)
    for i in 1:length(data[:x_coords])-1
      ell[i] = data[:x_coords][i+1] - data[:x_coords][i]
    end
  end
  
  for i in 1:nels
    num = [i; i+1]
    num_to_g!(element.nod, nodof, nn, ndof, num, nf, g)
    g_g[:, i] = g
    fkdiag!(ndof, neq, g, kdiag)
  end
  
  for i in 2:neq
    kdiag[i] = kdiag[i] + kdiag[i-1]
  end

  kv = zeros(kdiag[neq])
  gv = zeros(kdiag[neq])
  
  println("There are $(neq) equations and the skyline storage is $(kdiag[neq]).\n")
    
  loads = zeros(neq+1)
  if :loaded_nodes in keys(data)
    for i in 1:size(data[:loaded_nodes], 1)
      loads[nf[:, data[:loaded_nodes][i][1]]+1] = data[:loaded_nodes][i][2]
    end
  end
  
  for i in 1:nels
    km = rod_km!(km, prop[etype[i], 1], ell[i])
    g = g_g[:, i]
    fsparv!(kv, km, g, kdiag)
  end

  fixed_freedoms = 0
  if :fixed_freedoms in keys(data)
    fixed_freedoms = size(data[:fixed_freedoms], 1)
  end
  no = zeros(Int64, fixed_freedoms)
  node = zeros(Int64, fixed_freedoms)
  sense = zeros(Int64, fixed_freedoms)
  value = zeros(Float64, fixed_freedoms)
  if :fixed_freedoms in keys(data) && fixed_freedoms > 0
    for i in 1:fixed_freedoms
      node[i] = data[:fixed_freedoms][i][1]
      sense[i] = data[:fixed_freedoms][i][2]
      no[i] = nf[sense[i], node[i]]
      value[i] = data[:fixed_freedoms][i][3]
    end
    kv[kdiag[no]] = kv[kdiag[no]] + penalty
    loads[no+1] = kv[kdiag[no]] .* value
  end

  sparin!(kv, kdiag)
  loads[2:end] = spabac!(kv, loads[2:end], kdiag)
  println()

  displacements = zeros(size(nf))
  for i in 1:size(displacements, 1)
    for j in 1:size(displacements, 2)
      if nf[i, j] > 0
        displacements[i,j] = loads[nf[i, j]+1]
      end
    end
  end
  displacements = displacements'

  loads[1] = 0.0
  for i in 1:nels
    km = rod_km!(km, prop[etype[i], 1], ell[i])
    g = g_g[:, i]
    eld = loads[g+1]
    actions[i, :] = km * eld
  end

  FEM(element_type, element, ndim, nels, nst, ndof, nn, nodof, neq, penalty,
    etype, g, g_g, g_num, kdiag, nf, no, node, num, sense, actions, 
    bee, coord, gamma, dee, der, deriv, displacements, eld, fun, gc,
    g_coord, jac, km, mm, gm, kv, gv, loads, points, prop, sigma, value,
    weights, x_coords, y_coords, z_coords, axial)
end
