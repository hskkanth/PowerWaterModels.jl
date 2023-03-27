"""
    parse_link_file(path)

Parses a linking file from the file path `path`, depending on the file extension, and
returns a PowerWaterModels data structure that links power and water networks (a dictionary).
"""
function parse_link_file(path::String)
    if endswith(path, ".json")
        data = parse_json(path)
    else
        error("\"$(path)\" is not a valid file type.")
    end

    if !haskey(data, "multiinfrastructure")
        data["multiinfrastructure"] = true
    end

    return data
end


function parse_power_file(file_path::String)
    if split(file_path, ".")[end] == "m" # If reading a MATPOWER file.
        data = _PM.parse_file(file_path)
        _scale_loads!(data, 1.0 / 3.0)
        _PMD.make_multiconductor!(data, 3)
    else
        data = _PMD.parse_file(file_path)
    end

    return _IM.ismultiinfrastructure(data) ? data :
          Dict("multiinfrastructure" => true, "it" => Dict(_PMD.pmd_it_name => data))
end


function parse_water_file(file_path::String; ne_path::String, skip_correct::Bool = true)
    data = _WM.parse_file(file_path; ne_path = ne_path, skip_correct = skip_correct)
    return _IM.ismultiinfrastructure(data) ? data :
           Dict("multiinfrastructure" => true, "it" => Dict(_WM.wm_it_name => data))
end


"""
    parse_files(power_path, water_path, link_path)

Parses power, water, and linking data from `power_path`, `water_path`, and `link_path`,
respectively, into a single data dictionary. Returns a PowerWaterModels
multi-infrastructure data structure keyed by the infrastructure type `it`.
"""
function parse_files(power_path::String, water_path::String, link_path::String; water_ne_path::String="")
    joint_network_data = parse_link_file(link_path)
    _IM.update_data!(joint_network_data, parse_power_file(power_path))
    _IM.update_data!(joint_network_data, parse_water_file(water_path, ne_path = water_ne_path))
    correct_network_data!(joint_network_data)

    # Store whether or not each network uses per-unit data.
    p_per_unit = get(joint_network_data["it"][_PMD.pmd_it_name], "per_unit", false)
    w_per_unit = get(joint_network_data["it"][_WM.wm_it_name], "per_unit", false)

    # Make the power and water data sets multinetwork.
    joint_network_data_mn = make_multinetwork(joint_network_data)

    # Prepare and correct pump load linking data.
    assign_pump_loads!(joint_network_data_mn)

    # Modify variable load properties in the power network.
    _modify_loads!(joint_network_data_mn)

    # Return the network dictionary.
    return joint_network_data_mn
end
