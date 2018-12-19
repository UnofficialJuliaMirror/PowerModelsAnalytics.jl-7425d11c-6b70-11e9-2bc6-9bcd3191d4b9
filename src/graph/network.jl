export
    pm2graph


function add_loads!(graph::MetaGraph, case::Dict)
    for load in values(get(case, "load", Dict()))
        set_props!(graph, load["load_bus"], Dict(:load_pd=>load["pd"], :load_status=>load["status"]))
    end

end


function add_gens!(graph::MetaGraph, case::Dict)
    for gen in values(get(case, "gen", Dict()))
        set_props!(graph, gen["gen_bus"], Dict(:gen_pmax=>gen["pmax"], :gen_status=>gen["gen_status"], :pvsystem=>false))
    end

end


function add_shunts!(graph::MetaGraph, case::Dict)
    for shunt in values(get(case, "shunt", Dict()))
        set_props!(graph, shunt["shunt_bus"], Dict(:shunt_gs=>shunt["gs"], :shunt_status=>shunt["status"]))
    end
end


function add_storage!(graph::MetaGraph, case::Dict)
    for strg in values(get(case, "storage", Dict()))
        set_props!(graph, strg["storage_bus"], Dict(:storage_energy=>strg["energy"], :storage_energy_rating=>strg["energy_rating"], :storage_status=>strg["status"]))
    end

end


function add_pvsystem(graph::MetaGraph, case::Dict)
    for pv in values(get(case, "pvsystem", Dict()))
        set_prop!(graph, pv["pv_bus"], :pvsystem, true)
    end
end


function identify_islands!(graph::MetaGraph, case::Dict)
    network = deepcopy(case)
    for switch in values(case["branch"])
        if switch["switch"]
            switch["br_status"] = 0
        end
    end

    islands = sort([island for island in PowerModels.connected_components(network)]; by=x->minimum(x))
    for node in vertices(graph)
        set_prop!(graph, node, :island, 1)
    end

    for (n, island) in enumerate(islands)
        for bus in island
            set_prop!(graph, bus, :island, n)
        end
    end
end


function identify_energized!(graph::MetaGraph, case::Dict)
    for node in vertices(graph)
        set_prop!(graph, node, :is_energized, false)
    end

    energized_islands = [island for island in PowerModels.connected_components(case) if
                            any(gen_bus in island for gen_bus in [gen["gen_bus"] for gen in values(case["gen"]) if gen["gen_status"] == 1]) ]

    for energized_island in energized_islands
        for bus in energized_island
            set_prop!(graph, bus, :is_energized, true)
        end
    end
end


function identify_bus_status!(graph::MetaGraph, case::Dict)
    for bus in values(case["bus"])
        set_prop!(graph, bus["bus_i"], :bus_status, bus["bus_type"] == 0 ? 0 : 1)
    end
end


function add_node_names!(graph::MetaGraph, case::Dict)
    for bus in values(case["bus"])
        set_props!(graph, bus["bus_i"], Dict(:bus_i=>bus["bus_i"], :name=>bus["name"]))
    end
end


function pm2graph(case::Dict{String,Any})::MetaGraph
    nnodes = length(case["bus"])
    graph = MetaGraphs.MetaGraph(nnodes)

    for branch in values(get(case, "branch", Dict()))
        add_edge!(graph, branch["f_bus"], branch["t_bus"])
        set_props!(graph, Edge(branch["f_bus"], branch["t_bus"]), Dict(:branch_i=>branch["index"], :name=>branch["name"], :switch=>get(branch, "switch", false), :br_status=>Bool(get(branch, "status", 1)), :transformer=>get(branch, "transformer", false)))
    end

    for dcline in values(get(case, "dcline", Dict()))
        add_edge!(graph, dcline["f_bus"], dcline["t_bus"])
        set_props!(graph, Edge(dcline["f_bus"], dcline["t_bus"]), Dict(:branch_i=>dcline["index"], :name=>dcline["name"], :switch=>get(dcline, "switch", false), :br_status=>Bool(get(dcline, "status", 1)), :transformer=>false))
    end

    add_loads!(graph, case)
    add_shunts!(graph, case)
    add_gens!(graph, case)
    add_storage!(graph, case)

    add_node_names!(graph, case)

    identify_bus_status!(graph, case)
    identify_islands!(graph, case)
    identify_energized!(graph, case)

    return graph
end
