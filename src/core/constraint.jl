"""
Constraint for modeling a fixed load (i.e., not connected to a pump). Since
the base power formulation uses a variable, ``0 \\leq z_{it} \\leq 1``, to
model the proportion of maximum load served at load ``i \\in \\mathcal{L}``,
time index ``t \\in \\mathcal{T}``, a value of one indicates the full load
being served, as expected for non-pump loads. That is, these constraints are
```math
z_{it} = 1, \\, \\forall i \\in \\mathcal{L}^{\\prime},
\\, \\forall t \\in \\mathcal{T},
```
where ``\\mathcal{L}^{\\prime}`` is the set of loads not connected to a pump.
"""
function constraint_fixed_load(pwm::AbstractPowerWaterModel, i::Int; nw::Int = _IM.nw_id_default)
    pmd = _get_powermodel_from_powerwatermodel(pwm)
    z = _PMD.var(pmd, nw, :z_demand, i)
    JuMP.@constraint(pmd.model, z == 1.0)
end


"""
Constraint for modeling a variable load (i.e., connected to a pump). Since
the base power formulation uses a variable, ``0 \\leq z_{it} \\leq 1``, to
model the proportion of maximum load served at load ``i \\in \\mathcal{L}``,
time index ``t \\in \\mathcal{T}``, a value of one indicates the maximum load
is being served (denoted as ``pd``). Any other value will represent some
proportion of this maximum. Linking pump power to load is thus modeled via
```math
P_{jt} = z_{it} \\sum_{c \\in \\mathcal{C}} pd_{ict}, \\,
\\forall (i, j) \\in \\mathcal{D}, \\, \\forall t \\in \\mathcal{T},
```
where ``\\mathcal{D}`` is the set of interdependencies, linking loads,
``i \\in \\mathcal{L}``, to pumps, ``j \\in \\mathcal{P}``. Here, ``P_{j}``
is a variable that represents pump power and ``\\mathcal{C}`` is the set of
conductors, i.e., power is bounded by ``\\sum_{c \\in \\mathcal{C}} pd_{ict}``.
"""
function constraint_pump_load(pwm::AbstractPowerWaterModel, i::Int, a::Int; nw::Int = _IM.nw_id_default)
    power_load = _get_power_load_expression(pwm, i, nw = nw)
    pump_load = _get_pump_load_expression(pwm, a, nw = nw)
    factor = _get_power_conversion_factor(pwm.data, string(nw))
    c = JuMP.@constraint(pwm.model, factor * pump_load == power_load)
end

function constraint_ne_pump_load(pwm::AbstractPowerWaterModel, i::Int, a::Int; nw::Int = _IM.nw_id_default)
    power_load = _get_power_load_expression(pwm, i, nw = nw)
    ne_pump_load = _get_ne_pump_load_expression(pwm, a, nw = nw)
    factor = _get_power_conversion_factor(pwm.data, string(nw))
    c = JuMP.@constraint(pwm.model, factor * ne_pump_load == power_load)
end


"""
    constraint_budget_ne(pm::AbstractPowerWaterModel)
"""
function constraint_budget_ne(pwm::AbstractPowerWaterModel)
    pmd = _get_powermodel_from_powerwatermodel(pwm)
    power_ne_cost = _PMD.objective_ne(pmd)

    wm = _get_watermodel_from_powerwatermodel(pwm)
    water_ne_cost = _WM.objective_ne(wm)

    total_ne_cost = power_ne_cost + water_ne_cost
    first_nw_id = sort(collect(_PMD.nw_ids(pmd)))[1]
    budget_ne = _IM.ref(pwm, :dep, first_nw_id, :budget_ne)

    JuMP.@constraint(pwm.model, total_ne_cost <= budget_ne)
end

function _get_power_load_expression(pwm::AbstractPowerWaterModel, i::Int; nw::Int = _IM.nw_id_default)
    pmd = _get_powermodel_from_powerwatermodel(pwm)
    pd = sum(_PMD.ref(pmd, nw, :load, i)["pd"])
    z = _PMD.var(pmd, nw, :z_demand, i)
    return JuMP.@expression(pmd.model, pd * z)
end


function _get_pump_load_expression(pwm::AbstractPowerWaterModel, i::Int; nw::Int = _IM.nw_id_default)
    wm = _get_watermodel_from_powerwatermodel(pwm)
    return _WM.var(wm, nw, :P_pump, i)
end


function _get_ne_pump_load_expression(pwm::AbstractPowerWaterModel, i::Int; nw::Int = _IM.nw_id_default)
    wm = _get_watermodel_from_powerwatermodel(pwm)
    return _WM.var(wm, nw, :P_ne_pump, i)
end
