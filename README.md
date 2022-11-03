# AntHocNet-Netlogo-Implementation
Implementation of the algorithm AnthHocNet in Netlogo. This is part of the exam Distributed Artificial Ingelligence held at UNIMORE.

# The Algorithm
AntHocNet is an algorithm used for routing in MANETs. These are special networks in which the mobility of nodes is high, so a traditional approach of routing is not useful.
This algorithm shows an hybrid approach, having both reactive and proactive components.

# Interface
<!--insert image of interface-->
![program interface](/docs/anthocnet-interface.png)

## setup variables
`radius` if nodes inside radius they make link

`number-of-nodes`   number of nodes instanciated

`number-of-ants`    number of _reactive_ ants used for `reactive-path-setup`

`max-hops`  upper bound of hops used when moving through nodes in the net

## reactive variables
`number-of-packets-in-queue`, `avg-time-to-send-pkt`    values used for MAC layer travel time estimation

`Thop`  how long takes a packet to travel one hop when no traffic is in the net

## proactive variables
`sending-rate`  number of packet to send before sending a _proactive_ ant

`number-of-proactive-ants`  number of ants created during the maintenance path phase

# other variables
`node-speed`    value between 0 and 1 used for represent node mobility

`n-links`   number of links to be killed when `kill-n-random-link` is called

# Reactive Path Setup
When nodes are instanciated they have no routing information, so they start this phase where _reactive-forward-ant_ discovers, if exists, the paths connecting the nodes.

When the agent reach the destination, goes backward through all the visited nodes until the source node and compute for each hop the pheromone value. See the presentation for how it's computed this value.

# Routing
Each node act as a router and so must route the packets that receive to the destination, if is not reachable then the packet is sent to a random neighibor until reaches `max-hops` and then gets dropped.

The routing is stochastic, based on pheromone values, the formula is designed to pick the best paths. See the formula in the presentation for the exact defintiion.

# Proactive Path Maintenance
While a data session is running, once every `sending-rate` packets, `number-of-proactive-ants` ants are sent in the net.
Their task is both updating pheromone values (the move can move so the value can change), but also with a small probability, they can explore the network in order to look for new path connecting the nodes.
