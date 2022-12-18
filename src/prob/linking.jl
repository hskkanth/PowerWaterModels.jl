function build_linking(pwm::AbstractPowerWaterModel)
    # Get important data that will be used in the modeling loop.
    pmd = _get_powermodel_from_powerwatermodel(pwm)

    for nw in _IM.nw_ids(pwm, :dep)
        # Obtain all pump loads at multinetwork index.
        pump_loads = _IM.ref(pwm, :dep, nw, :pump_load)

        for pump_load in values(pump_loads)
            # Constrain load variables if they are connected to a pump.
            pump_index = pump_load["pump"]["index"]
            load_index = pump_load["load"]["index"]
            constraint_pump_load(pwm, load_index, pump_index; nw = nw)
        end

        # Discern the indices for variable loads (i.e., loads connected to pumps).

        load_ids = _PMD.ids(pmd, nw, :load)
        var_load_ids = [x["load"]["index"] for x in values(pump_loads)]

        # Obtain all pump loads at multinetwork index.
        # ne_pump_loads = Dict()
        # ne_pump_loads = []
        if(haskey(_IM.ref(pwm, :dep, nw),:ne_pump_load))
            ne_pump_loads = _IM.ref(pwm, :dep, nw, :ne_pump_load)

            for ne_pump_load in values(ne_pump_loads)
                # Constrain load variables if they are connected to a network expansion pump.
                ne_pump_index = ne_pump_load["ne_pump"]["index"]
                ne_load_index = ne_pump_load["load"]["index"]
                constraint_ne_pump_load(pwm, ne_load_index, ne_pump_index; nw = nw)
            end

            var_load_ids_ne = [x["load"]["index"] for x in values(ne_pump_loads)]
            var_load_ids = union(var_load_ids,var_load_ids_ne)
        end


        for load_index in setdiff(load_ids, var_load_ids)
            # Constrain load variables if they are not connected to a pump.
            constraint_fixed_load(pwm, load_index; nw = nw)
        end
    end
end
