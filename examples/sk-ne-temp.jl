using WaterModels, PowerWaterModels
using HiGHS
const WM = WaterModels
const PWM = PowerWaterModels

milp_solver = JuMP.optimizer_with_attributes(HiGHS.Optimizer, "log_to_console" => false)

# Specify paths to the input data files.
power_file = "examples/data/opendss/IEEE13_CDPSM.dss";
water_file = "examples/data/epanet/cohen-pump-ne.inp";
linking_file = "examples/data/json/expansion-pump-latest.json"


# Parse the input files into a dictionary.
data = parse_files(power_file, water_file, linking_file);
WM.propagate_topology_status!(data);

# for (nw, nw_data) in data["it"]["pmd"]["nw"]
#     for (i, load) in nw_data["load"]
#         load["pd"] = load["pd"] .* 1.0
#     end
# end


# Set the partitioning for flow variables in the water model.
WM.set_flow_partitions_num!(data, 5);

# Initialize a flow partitioning function to be used in water OBBT.
flow_partition_func = x -> WM.set_flow_partitions_num!(x, 5);

# Specify the following optimization models' types.
pwm_type = PowerWaterModel{NFAUPowerModel, LRDWaterModel};

# Solve the network expansion problem.
result = solve_opwf_ne(data, pwm_type, milp_solver);
