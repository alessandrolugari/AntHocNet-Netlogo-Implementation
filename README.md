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
When the networ

# Routing

# Proactive Path Maintenance
