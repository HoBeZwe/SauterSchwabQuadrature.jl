using LinearAlgebra
using Test

using CompScienceMeshes
using SauterSchwabQuadrature
using StaticArrays
using BEAST

include("verificationintegral.jl")

pI = point(1,5,3)
pII = point(2,5,3)
pIII = point(7,1,0)
pIV = point(5,1,-3)

Sourcechart = simplex(pI,pIII,pII)
Testchart = simplex(pI,pIV,pII)

Accuracy = 12
ce = CommonEdge(Accuracy)

function integrand(x,y)
			return(((x-pI)'*(y-pII))*exp(-im*1*norm(x-y))/(4pi*norm(x-y)))
end

function INTEGRAND(û,v̂)
	n1 = neighborhood(Testchart, û)
	n2 = neighborhood(Sourcechart, v̂)
	x = cartesian(n1)
	y = cartesian(n2)
	output = integrand(x,y)*jacobian(n1)*jacobian(n2)

return(output)
end

result = sauterschwab_parameterized(INTEGRAND, ce)-
		   verifintegral2(Sourcechart, Testchart, integrand, Accuracy)

@test norm(result) < 1.e-3


kernel(x,y) = 1/norm(cartesian(x)-cartesian(y))

t1 = simplex(
	@SVector[0.180878, -0.941848, -0.283207],
	@SVector[0.0, -0.92388, -0.382683],
 	@SVector[0.0, -0.980785, -0.19509])
t2 = simplex(
	@SVector[0.180878, -0.941848, -0.283207],
	@SVector[0.0, -0.92388, -0.382683],
	@SVector[0.158174, -0.881178, -0.44554])

@test indexin(t1.vertices, t2.vertices) == [1, 2, nothing]

rt = BEAST.RTRefSpace{Float64}()
igd = generate_integrand_uv(kernel, rt, rt, t1, t2)

i5 = sauterschwab_parameterized(igd, CommonEdge(5))
i10 = sauterschwab_parameterized(igd, CommonEdge(10))
i15 = sauterschwab_parameterized(igd, CommonEdge(15))

# brute numerical approach
q1 = quadpoints(t1, 10)
q2 = quadpoints(t2, 10)

M = N = numfunctions(rt)
iref = zero(i5)
for (x,w1) in q1
    f = rt(x)
    for (y,w2) in q2
        g = rt(y)
        G = kernel(x,y)
        ds = w1*w2
        global iref += SMatrix{M,N}([dot(f[i][1], G*g[j][1])*ds for i=1:M, j=1:N])
    end
end

include(joinpath(dirname(@__FILE__,),"numquad.jl"))
ibf = numquad(kernel, rt, rt, t1, t2, zero(i5))

@test i5  ≈ iref atol=1e-3
@test i10 ≈ iref atol=1e-3
@test i10 ≈ ibf  atol=1e-3
@test i10 ≈ i15  atol=1e-5


# Test the more (or less) singular case of the second kind kernel
function kernel2nd(x,y)

	r = cartesian(x) - cartesian(y)
	R = norm(r)

	gradgreen = - r / R^3

	@SMatrix [
		0             -gradgreen[3]  gradgreen[2]
		 gradgreen[3]             0 -gradgreen[1]
		-gradgreen[2]  gradgreen[1]             0 ]
end

igd = generate_integrand_uv(kernel2nd, rt, rt, t1, t2)
i10 = sauterschwab_parameterized(igd, CommonEdge(10))
i15 = sauterschwab_parameterized(igd, CommonEdge(15))
i20 = sauterschwab_parameterized(igd, CommonEdge(20))
# i25 = sauterschwab_parameterized(igd, CommonEdge(25))
# i30 = sauterschwab_parameterized(igd, CommonEdge(30))
# i35 = sauterschwab_parameterized(igd, CommonEdge(35))
#
# i50 = sauterschwab_parameterized(igd, CommonEdge(50))
# i55 = sauterschwab_parameterized(igd, CommonEdge(55))

iref = numquad(kernel2nd, rt, rt, t1, t2, zero(i15))

# Compare to BEAST:
tqd = BEAST.quadpoints(rt, [t1], (12,))
bqd = BEAST.quadpoints(rt, [t2], (13,))

SE_strategy = BEAST.WiltonSEStrategy(
  tqd[1,1],
  BEAST.DoubleQuadStrategy(
	tqd[1,1],
	bqd[1,1]))

op = BEAST.MWDoubleLayer3D(0.0)
z2 = zeros(3,3)
BEAST.momintegrals!(op, rt, rt, t1, t2, z2, SE_strategy)