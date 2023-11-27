# Definitions for solving a budget-constrained joint optimal power-water flow problem.


"Entry point for running the budget-constrained optimal power-water flow problem."
function solve_opwf_ne(p_file, w_file, pw_file, pwm_type, optimizer; kwargs...)
    return solve_model(p_file, w_file, pw_file, pwm_type, optimizer, build_opwf_ne; kwargs...)
end


"Entry point for running the budget-constrained optimal power-water flow problem."
function solve_opwf_ne(data, pwm_type, optimizer; kwargs...)
    return solve_model(data, pwm_type, optimizer, build_opwf_ne; kwargs...)
end


"Construct the budget-constrained optimal power-water flow problem."
function build_opwf_ne(pwm::AbstractPowerWaterModel)

    first_nw_id = sort(collect(_IM.nw_ids(pwm, :dep)))[1]
    power_constraints = _IM.ref(pwm, :dep, first_nw_id, :power_con)
    # Power-only related variables and constraints.
    pmd = _get_powermodel_from_powerwatermodel(pwm)
    if(power_constraints == "p_on")
        # _PMD.build_mn_mc_mld_simple_flexible_loads(pmd)
        _PMD.build_mn_mc_mld_multi_scenario_flexible_loads(pmd)
    end

    water_constraints = _IM.ref(pwm, :dep, first_nw_id, :water_con)
    if(water_constraints == "w_on")
        # Water-only related variables and constraints.
        wm = _get_watermodel_from_powerwatermodel(pwm)
        _WM.build_mn_owf(wm)
    end


    # Power-water linking constraints.
    linking_choice = _IM.ref(pwm, :dep, first_nw_id, :linking)
    if(linking_choice == "on")
        build_linking(pwm)

        # Constraints on the total expansion budget.
    else
        println("***** No Linking Constraints*******")
    end
    constraint_budget_ne(pwm)

    objective_choice = _IM.ref(pwm, :dep, first_nw_id, :objective_choice)

    if(objective_choice == "demand")
        objective_max_combined_weighted_demand(pwm)
    elseif objective_choice == "power"
        objective_max_weighted_power(pwm)
    elseif objective_choice == "min_fuel_cost"
        # Add the objective that minimizes power generation costs.
        _PMD.objective_mc_min_fuel_cost(pmd)
    elseif objective_choice == "construction_cost"
        objective_weighted_ne(pwm)
    end

    # println(pwm.model)
    # objective_ne(pwm)
end
