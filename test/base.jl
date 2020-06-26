@testset "src/core/base.jl" begin
    p_file = "$(pmd_path)/test/data/opendss/case2_diag.dss"
    w_file = "$(wm_path)/test/data/epanet/snapshot/pump-hw-lps.inp"
    pw_file = "../test/data/json/case2-pump.json"
    p_type, w_type = LinDist3FlowPowerModel, MILPWaterModel

    @testset "instantiate_model (with file inputs)" begin
        pm, wm = instantiate_model(p_file, w_file, pw_file, p_type, w_type, build_pwf)
        @test pm.model == wm.model
    end

    @testset "instantiate_model (with network inputs)" begin
        p_data, w_data, pw_data = parse_files(p_file, w_file, pw_file)
        pm, wm = instantiate_model(p_data, w_data, pw_data, p_type, w_type, build_pwf)
        @test pm.model == wm.model
    end

    @testset "run_model (with file inputs)" begin
        result = run_model(p_file, w_file, pw_file, p_type, w_type, juniper, build_pwf)
        @test result["termination_status"] == LOCALLY_SOLVED
    end

    @testset "run_model (with network inputs)" begin
        p_data, w_data, pw_data = parse_files(p_file, w_file, pw_file)
        result = run_model(p_data, w_data, pw_data, p_type, w_type, juniper, build_pwf)
        @test result["termination_status"] == LOCALLY_SOLVED
    end
end
