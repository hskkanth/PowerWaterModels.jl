using WaterModels, PowerWaterModels
using HiGHS
const WM = WaterModels
const PWM = PowerWaterModels

milp_solver = JuMP.optimizer_with_attributes(HiGHS.Optimizer, "log_to_console" => false)

# Specify paths to the input data files.
power_file = "PowerWaterModels.jl/examples/data/opendss/IEEE13_CDPSM.dss";
water_file = "PowerWaterModels.jl/examples/data/epanet/cohen-ne.inp";
linking_file = "PowerWaterModels.jl/examples/data/json/expansion.json"

# power_file = "PowerWaterModels.jl/examples/data/opendss/IEEE13_CDPSM.dss";
# water_file = "PowerWaterModels.jl/examples/data/epanet/cohen-ne.inp";
# linking_file = "PowerWaterModels.jl/examples/data/json/expansion_reg_and_ne_pumps.json"

# power_file = "PowerWaterModels.jl/examples/data/opendss/IEEE13_CDPSM.dss";
# water_file = "PowerWaterModels.jl/examples/data/epanet/cohen-ne_reg_pump_removed.inp";
# linking_file = "PowerWaterModels.jl/examples/data/json/expansion_ne_pump_replaces_reg_pump.json"




# Parse the input files into a dictionary.
data = parse_files(power_file, water_file, linking_file);
println("data reading completed")
WM.propagate_topology_status!(data);
# # Set the partitioning for flow variables in the water model.
WM.set_flow_partitions_num!(data, 5);
# # Initialize a flow partitioning function to be used in water OBBT.
flow_partition_func = x -> WM.set_flow_partitions_num!(x, 5);
# # Specify the following optimization models' types.
pwm_type = PowerWaterModel{NFAUPowerModel, LRDWaterModel};
# # Solve the network expansion problem.
result = solve_opwf_ne(data, pwm_type, milp_solver);
