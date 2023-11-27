"""
Objective for minimizing the maximum difference between time-adjacent power
generation variables. Note that this function introduces a number of
auxiliary variables and constraints to appropriately model the objective.
Mathematically, the objective and auxiliary terms are modeled as follows:
```math
    \\begin{aligned}
    & \\text{minimize} & & z \\\\
    & \\text{subject to} & & z \\geq pg_{i, c, t} - pg_{i, c, t-1}, \\, \\forall i \\in \\mathcal{G}, \\, \\forall c \\in \\mathcal{C}, \\, \\forall t \\in \\{2, 3, \\dots, T\\} \\\\
    & & & z \\geq pg_{i, c, t-1} - pg_{i, c, t}, \\, \\forall i \\in \\mathcal{G}, \\, \\forall c \\in \\mathcal{C}, \\, \\forall t \\in \\{2, 3, \\dots, T\\} \\\\
    & & & z \\geq 0 \\\\
    & & & x \\in \\mathcal{X},
    \\end{aligned}
```
where ``\\mathcal{G}`` is the set of generators, ``\\mathcal{C}`` is the set of
conductors, and ``\\{2, 3, \\dots, T\\}`` are the non-starting time indices.
Further, ``x \\in \\mathcal{X}`` represents the remainder of the problem
formulation, i.e., variables and constraints not relevant to this description.
"""
function objective_min_max_generation_fluctuation(pwm::AbstractPowerWaterModel)
    pmd = _get_powermodel_from_powerwatermodel(pwm)
    z = JuMP.@variable(pmd.model, lower_bound = 0.0)
    nw_ids = sort(collect(_PMD.nw_ids(pmd)))

    for n in 2:length(nw_ids)
        nw_1, nw_2 = nw_ids[n-1], nw_ids[n]

        for (i, gen) in _PMD.ref(pmd, nw_2, :gen)
            pg_1 = _PMD.var(pmd, nw_1, :pg, i)
            pg_2 = _PMD.var(pmd, nw_2, :pg, i)

            JuMP.@constraint(pwm.model, z >= pg_1[1] - pg_2[1])
            JuMP.@constraint(pwm.model, z >= pg_2[1] - pg_1[1])
            JuMP.@constraint(pwm.model, z >= pg_1[2] - pg_2[2])
            JuMP.@constraint(pwm.model, z >= pg_2[2] - pg_1[2])
            JuMP.@constraint(pwm.model, z >= pg_1[3] - pg_2[3])
            JuMP.@constraint(pwm.model, z >= pg_2[3] - pg_1[3])
        end
    end

    return JuMP.@objective(pwm.model, _IM.JuMP.MIN_SENSE, z);
end


"""
    objective_ne(pm::AbstractPowerWaterModel)
"""
function objective_ne(pwm::AbstractPowerWaterModel)
    pmd = _get_powermodel_from_powerwatermodel(pwm)
    power_ne_cost = _PMD.objective_ne(pmd)

    wm = _get_watermodel_from_powerwatermodel(pwm)
    water_ne_cost = _WM.objective_ne(wm)

    total_ne_cost = power_ne_cost + water_ne_cost
    return JuMP.@objective(pwm.model, JuMP.MIN_SENSE, total_ne_cost)
end

"""
    objective_weighted_ne(pm::AbstractPowerWaterModel)
"""
function objective_weighted_ne(pwm::AbstractPowerWaterModel)
    pmd = _get_powermodel_from_powerwatermodel(pwm)
    power_ne_cost = _PMD.objective_ne(pmd)

    # println("Power ne cost = $power_ne_cost")
    wm = _get_watermodel_from_powerwatermodel(pwm)
    water_ne_cost = _WM.objective_ne(wm)
    # println("Water ne cost = $water_ne_cost")

    first_nw_id = sort(collect(_PMD.nw_ids(pmd)))[1]
    lambda = _IM.ref(pwm, :dep, first_nw_id, :construct_ratio_power_to_water)
    total_ne_cost = lambda*power_ne_cost + (1 - lambda)*water_ne_cost
    # println("lambda = $lambda")
    # println("Printing objective $total_ne_cost")
    return JuMP.@objective(pwm.model, JuMP.MIN_SENSE, total_ne_cost)
end


function objective_max_scaled_non_pump_demand(pwm::AbstractPowerWaterModel)
    # Get important data that will be used in the modeling loop.
    pmd = _get_powermodel_from_powerwatermodel(pwm)

    npl_expr = 0.0
    ntp = length(_IM.nw_ids(pwm, :dep)) #number of time points
    scale = 1.0
    for nw in  _IM.nw_ids(pwm, :dep)
        # Obtain all pump loads at multinetwork index.
        pump_loads = _IM.ref(pwm, :dep, nw, :pump_load)

        load_ids = _PMD.ids(pmd, nw, :load)
        var_load_ids = [x["load"]["index"] for x in values(pump_loads)]

        if(haskey(_IM.ref(pwm, :dep, nw),:ne_pump_load))
            ne_pump_loads = _IM.ref(pwm, :dep, nw, :ne_pump_load)

            var_load_ids_ne = [x["load"]["index"] for x in values(ne_pump_loads)]
            var_load_ids = union(var_load_ids,var_load_ids_ne)
        end

        non_pump_load_ids = setdiff(load_ids, var_load_ids)
        npl = length(non_pump_load_ids)
        for i in non_pump_load_ids
            scale = max(scale, sum(_PMD.ref(pmd, nw, :load, i)["pd"]))
        end
        npl_expr += sum(_PMD.var(pmd, nw, :z_demand, i)*sum((_PMD.ref(pmd, nw, :load, i)["pd"])) for i in non_pump_load_ids)
        # npl_expr += sum((var(pm, nw, :z_demand, i)) for i in non_pump_load_ids))
    end
    println("power objective scale = $scale")
    JuMP.@objective(pwm.model, Max,npl_expr/scale)
end

"""
    objective_max_combined_weighted_demand(pm::AbstractPowerWaterModel)
"""
function objective_max_combined_weighted_demand(pwm::AbstractPowerWaterModel)
    # pmd = _get_powermodel_from_powerwatermodel(pwm)
    power_demand = objective_max_scaled_non_pump_demand(pwm)

    wm = _get_watermodel_from_powerwatermodel(pwm)
    water_demand = _WM.objective_max_scaled_demand(wm)

    first_nw_id = sort(collect(_IM.nw_ids(pwm, :dep)))[1]
    lambda = _IM.ref(pwm, :dep, first_nw_id, :demand_ratio_power_to_water)
    total_weighted_demand = lambda*power_demand + (1.0-lambda)*water_demand

    return JuMP.@objective(pwm.model, JuMP.MAX_SENSE, total_weighted_demand)
end


function objective_max_weighted_power(pwm::AbstractPowerWaterModel)
    # Get important data that will be used in the modeling loop.
    pmd = _get_powermodel_from_powerwatermodel(pwm)

    npl_expr = 0.0
    pl_expr = 0.0
    ntp = length(_IM.nw_ids(pwm, :dep)) #number of time points
    for nw in  _IM.nw_ids(pwm, :dep)
        # Obtain all pump loads at multinetwork index.
        pump_loads = _IM.ref(pwm, :dep, nw, :pump_load)

        load_ids = _PMD.ids(pmd, nw, :load)
        var_load_ids = [x["load"]["index"] for x in values(pump_loads)]

        if(haskey(_IM.ref(pwm, :dep, nw),:ne_pump_load))
            ne_pump_loads = _IM.ref(pwm, :dep, nw, :ne_pump_load)

            var_load_ids_ne = [x["load"]["index"] for x in values(ne_pump_loads)]
            var_load_ids = union(var_load_ids,var_load_ids_ne)
        end

        non_pump_load_ids = setdiff(load_ids, var_load_ids)



        npl_expr += sum(_PMD.var(pmd, nw, :z_demand, i)*sum((_PMD.ref(pmd, nw, :load, i)["pd"])) for i in non_pump_load_ids)
        pl_expr += sum(_PMD.var(pmd, nw, :z_demand, i)*sum(_PMD.ref(pmd, nw, :load, i)["pd"]) for i in var_load_ids)
        # npl_expr += sum((var(pm, nw, :z_demand, i)) for i in non_pump_load_ids))
    end
    first_nw_id = sort(collect(_PMD.nw_ids(pmd)))[1]
    lambda = _IM.ref(pwm, :dep, first_nw_id, :demand_ratio_power_to_water)
    JuMP.@objective(pwm.model, Max,lambda*npl_expr + (1-lambda)*pl_expr)
end
