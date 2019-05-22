module NonLinearFEOperatorsTests

using Gridap.FESpaces
using Gridap.Assemblers
using Gridap.FEOperators

using Test
using Gridap
using Gridap.Geometry
using Gridap.Geometry.Cartesian
using Gridap.FieldValues
using Gridap.CellIntegration
using Gridap.Vtkio

import Gridap: gradient

# Define manufactured functions
ufun(x) = x[1] + x[2]
ufun_grad(x) = VectorValue(1.0,1.0)
gradient(::typeof(ufun)) = ufun_grad
bfun(x) = 0.0

# Construct the discrete model
model = CartesianDiscreteModel(domain=(0.0,1.0,0.0,1.0), partition=(4,4))

# Construct the FEspace
order = 1
tag = tag_from_name(model,"boundary")
tags = [tag,]
fespace = ConformingFESpace(Float64,model,order,tags)

# Define test and trial
V = TestFESpace(fespace)
U = TrialFESpace(fespace,ufun)

# Define integration mesh and quadrature
trian = triangulation(model)
quad = quadrature(trian,order=2)

# Define cell field describing the source term
bfield = cellfield(trian,bfun)

# Define residual and jacobian
a(v,u) = varinner(∇(v), ∇(u))
b(v) = varinner(v,bfield)
res(u,v) = a(v,u) - b(v)
jac(u,v,du) = a(v,du)

# Define Assembler
assem = SparseMatrixAssembler(V,U)

# Define the FEOperator
op = NonLinearFEOperator(res,jac,V,U,assem,trian,quad)

# Define the FESolver
tol = 1.e-8
maxiters = 10
solver = NonLinearFESolver(tol,maxiters)

# Solve!
uh = solve(solver,op)

# Define exact solution and error
u = cellfield(trian,ufun)
e = u - uh

# Define norms to measure the error
l2(u) = varinner(u,u)
h1(u) = a(u,u) + l2(u)

# Compute errors
el2 = sqrt(sum( integrate(l2(e),trian,quad) ))
eh1 = sqrt(sum( integrate(h1(e),trian,quad) ))

@test el2 < 1.e-8
@test eh1 < 1.e-8

#writevtk(trian,"trian",nref=4,cellfields=["uh"=>uh,"u"=>u,"e"=>e])

end # module NonLinearFEOperatorsTests