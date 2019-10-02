# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/FEMMaterials.jl/blob/master/LICENSE

using JuliaFEM, FEMMaterials, Materials, FEMBase, LinearAlgebra
import FEMMaterials: Continuum3D, MecaMatSo

mesh = abaqus_read_mesh(joinpath("plastic_beam.inp"))
beam_elements = create_elements(mesh, "Body1")
bc_elements_1 = create_nodal_elements(mesh, "BC1")
bc_elements_2 = create_nodal_elements(mesh, "BC2")
trac_elements = create_surface_elements(mesh, "PRESSURE")

update!(beam_elements, "youngs_modulus", 200.0e3)
update!(beam_elements, "poissons_ratio", 0.3)
update!(beam_elements, "yield_stress", 100.0)

for j in 1:3
    update!(bc_elements_1, "displacement $j", 0.0)
end
update!(bc_elements_2, "displacement 1", 0.0)
update!(bc_elements_2, "displacement 2", 0.0)
update!(trac_elements, "surface pressure", 0.0 => 0.00)
update!(trac_elements, "surface pressure", 1.0 => 2.70)


beam = Problem(Continuum3D, "plastic beam", 3)
beam.properties.material_model = :IdealPlastic
trac = Problem(Continuum3D, "traction", 3)
bc = Problem(Dirichlet, "fix displacement", 3, "displacement")
add_elements!(beam, beam_elements)
add_elements!(trac, trac_elements)
add_elements!(bc, bc_elements_1)
add_elements!(bc, bc_elements_2)

analysis = Analysis(MecaMatSo, "solve problem")
analysis.properties.max_iterations = 50
analysis.properties.t0 = 0.0
analysis.properties.t1 = 1.0
analysis.properties.dt = 0.05
xdmf = Xdmf("results4"; overwrite=true)
add_results_writer!(analysis, xdmf)
add_problems!(analysis, beam, trac, bc)

run!(analysis)


close(xdmf)

#tim = range(0.0, stop=1.0, length=20)
tim = 0.0:0.05:1.0
vmis_ = []
for t in tim
    vmis = []
    for element in beam_elements
        for ip in get_integration_points(element)
            s11, s22, s33, s12, s23, s31 = ip("stress", t)
            #@info("s33 = $s33")
            push!(vmis, sqrt(1/2*((s11-s22)^2 + (s22-s33)^2 + (s33-s11)^2 + 6*(s12^2+s23^2+s31^2))))
            #stress_v = ip("stress_v", t)
            #push!(vmis, stress_v)
        end
    end
    push!(vmis_, maximum(vmis))
end

u2_96 = []
for t in tim
    push!(u2_96, beam("displacement", t)[96][2])
end

#using Plots
if false
    ip1 = first(get_integration_points(body_element))
    t = range(0, stop=1.0, length=50)
    s11(t) = ip1("stress", t)[1]
    s22(t) = ip1("stress", t)[2]
    s33(t) = ip1("stress", t)[3]
    s12(t) = ip1("stress", t)[4]
    s23(t) = ip1("stress", t)[5]
    s31(t) = ip1("stress", t)[6]
    e33(t) = ip1("strain", t)[3]
    s(t) = ip1("stress", t)
    function vmis(t)
        s11, s22, s33, s12, s23, s31 = ip1("stress", t)
        return sqrt(1/2*((s11-s22)^2 + (s22-s33)^2 + (s33-s11)^2 + 6*(s12^2+s23^2+s31^2)))
    end
    y = vmis.(t)
    x = e33.(t)
    plot(x, y)
    # labels = ["s11" "s22" "s33" "s12" "s23" "s31"]
    # plot(t, s11, title="stress at integration point 1", label="s11")
    # plot!(t, s22, label="s22")
    # plot!(t, s33, label="s33")
    # plot!(t, s12, label="s12")
    # plot!(t, s23, label="s23")
    # plot!(t, s31, label="s31")
end