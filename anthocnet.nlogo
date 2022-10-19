extensions [
  table
  rnd
  nw
]

breed [nodes node]
breed [ants ant]
breed [messages message]

nodes-own [
  routing-table ; contains paths to reach other nodes
  pheromone-table ; contains value of pheromone to all destinations
]

ants-own [
  speed ; 0 <= speed <= 1 if below 1 the ant is slower, 1 equals to normal velocity
  repair ; true --> ant used during link failure procedure
]

messages-own [
  speed
]

links-own [
  quality ; variable that holds the quality between nodes
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; globals definition and handling
globals [
  ; params for routing
  maxhops
  maxtriptime
  packet-counter

  ; params for reactive path setup
  alpha
  gamma

  ; params for proactive path maintenance
  explore-random-path-threshold


  avg-hops-delivered
  avg-hops-total
  avg-send-time
  avg-pkt-loss
  pkt-loss-ratio
  pkt-loss-cnt
  pkt-delivered-cnt
]

to reset-metrics
  ;set avg-hops-delivered 0
  ;set avg-hops-total 0
  ;set avg-send-time 0
  ;set avg-pkt-loss 0
  ;set pkt-loss-ratio 0
  ;set pkt-loss-cnt 0
  ;set pkt-delivered-cnt 0
  setting-globals
  ;clear-all-plots
end

to reset-packet-counter
  set packet-counter 0
  set pkt-loss-cnt 0
  set pkt-delivered-cnt 0
end

to setting-globals
  set maxhops max-hops
  set maxtriptime 50 ; seconds
  set packet-counter 0

  set alpha 0.7
  set gamma 0.7

  set explore-random-path-threshold 0.1

  set avg-hops-delivered 0
  set avg-hops-total 0
  set avg-send-time 0
  set avg-pkt-loss 0
  set pkt-loss-ratio 0
  set pkt-loss-cnt 0
  set pkt-delivered-cnt 0
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; utility functions
to export-all-plots-separately
  let MODEL "radius-20--nodes-50--maxhops-50"
  let PATH (word "/home/alessandro/Desktop/netlogo_plots_csv/" MODEL "/")

  export-plot "avg # hops for delivered packets" (word PATH "avg_hops_delivered_pkt_" MODEL ".csv" )
  export-plot "avg # hops for all packets" (word PATH "avg_hops_all_pkt_" MODEL ".csv" )
  export-plot "pkt loss ratio" (word PATH "pkt_loss_ratio_" MODEL ".csv" )
end

to reset-tables
  ask nodes [
    ; initialize tables
    set routing-table table:make
    set pheromone-table table:make
  ]

  ;setting-globals
end

to clr-output
  clear-output
  reset-ticks
  reset-timer
  clear-all-plots

  ;setting-globals
end

to move-nodes
  create-ants 1 [
    set size 1
    set shape "bug"
    set repair true
  ]
  ask nodes [
    set heading random 360
    fd node-speed
  ]

  ; remove links
  ask links with [link-length > radius][
    let node1 [end1] of self
    let node2 [end2] of self

    ask node1 [
      table:remove [pheromone-table] of self [who] of node2
      table:remove [routing-table] of self [who] of node2
    ]

    ask node2 [
      table:remove [pheromone-table] of self [who] of node1
      table:remove [routing-table] of self [who] of node1
    ]

    die
  ]

  ; update tables
  ask nodes[
    create-links-with other nodes in-radius radius
  ]

  ask links with [link-length <= radius][
    let node1 [end1] of self
    let node2 [end2] of self

    let new-pheromone-value 0
    ask node1 [
      if member? [who] of node2 table:keys [pheromone-table] of node1 = false [
        table:put [pheromone-table] of self [who] of node2 0
        let tmp []
        set tmp lput node1 tmp
        set tmp lput node2 tmp
        table:put [routing-table] of self [who] of node2 tmp

        let start-time timer
        ask ants with [repair = true] [
          move-to-node self node2
        ]
        let hop-time timer - start-time

        set new-pheromone-value ((hop-time + Thop)/(2))^(-1)
        table:put [pheromone-table] of node1 [who] of node2 new-pheromone-value
      ]
    ]
    ask node2 [
      if member? [who] of node1 table:keys [pheromone-table] of node2 = false [
        table:put [pheromone-table] of self [who] of node1 0
        let tmp []
        set tmp lput node2 tmp
        set tmp lput node1 tmp
        table:put [routing-table] of self [who] of node1 tmp

        table:put [pheromone-table] of node2 [who] of node1 new-pheromone-value
      ]
    ]
  ]

  ask ants with [repair = true][
    die
  ]
end


to move-to-node [tmp-agent dst]
  ; tmp-agent can be either ant or message
  ask tmp-agent[
    face dst
    while [distance dst > 1] [
      ifelse distance dst < 1 [
        move-to dst
        stop
      ][
        fd 1 - speed
      ]
    ]
  ]
end

to kill-random-link
  let node1 0
  let node2 0
  ask one-of links [
    set node1 [end1] of self
    set node2 [end2] of self
    die
  ]

  ask node1 [
    table:remove [pheromone-table] of self [who] of node2
    table:remove [routing-table] of self [who] of node2
  ]

  ask node2 [
    table:remove [pheromone-table] of self [who] of node1
    table:remove [routing-table] of self [who] of node1
  ]
end

to update-metrics [agent current-node destination-node cnt-hops send-time]
  if [breed] of agent = messages[
    ifelse current-node != destination-node [
      set pkt-loss-cnt pkt-loss-cnt + 1
      ;set avg-pkt-loss avg-pkt-loss + ((1 - avg-pkt-loss) / packet-counter)
      set pkt-loss-ratio pkt-loss-cnt / packet-counter
    ][
      ; if pkt is sent correctly
      set pkt-delivered-cnt pkt-delivered-cnt + 1
      set avg-hops-delivered avg-hops-delivered + ((cnt-hops - avg-hops-delivered) / pkt-delivered-cnt)
      set avg-send-time avg-send-time + ((send-time - avg-send-time) / pkt-delivered-cnt)
    ]
  ]
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; setup, reactive/proactive and routing logic
to setup
  ca
  reset-ticks
  reset-timer

  ; setting globals
  setting-globals

  ask patches [
    set pcolor gray - 3
  ]
  create-nodes number-of-nodes [
    set size 2
    ;set color blue
    setxy random-xcor random-ycor
    set label who
    set shape "circle"
    create-links-with other nodes in-radius radius
  ]

  ask links [
    ;output-print link-length
    if link-length > radius [
      die
    ]
  ]

  ask ants [
    ;set speed (1 - random-float 0.7) ; max decrease in speed is 0.7 in order to have a minimum speed = 0.3
  ]

end

to reactive-path-setup
  if debug-reactive [
    output-print "[reactive] starting path setup procedure"
  ]
  ; move to start-node

  ask nodes [
    ; initialize tables if not existing
    if [routing-table] of self = 0 or [pheromone-table] of self = 0[
      set routing-table table:make
      set pheromone-table table:make
    ]
  ]

  create-ants number-of-ants [
    set size 1
    set shape "bug"
    set repair false
  ]

  ask nodes with [count link-neighbors > 0][
    let start-node self

    ask nodes with [who != [who] of start-node] [
      ask ants [
        move-to start-node
        let destination-node myself

        if debug-reactive [
          ;output-print (word "[reactive] start-node " start-node " destination-node " destination-node " ant " self)
        ]
        let current-node start-node
        let hops 0
        let visited-nodes []
        let total-hop-time 0

        while [current-node != destination-node and hops < maxhops][
          ; current-node is not destination-node but has destination-node in its neighbors
          ifelse member? destination-node [link-neighbors] of current-node [
            ; move ant to destination
            let start-time timer
            move-to-node self destination-node
            let hop-time timer - start-time

            set total-hop-time total-hop-time + hop-time
            set visited-nodes lput current-node visited-nodes
            set current-node destination-node

            set visited-nodes lput destination-node visited-nodes

            ; update routing table only if hops/time are below certain threshold
            ifelse table:has-key? [routing-table] of start-node [who] of destination-node [
              ; already existing entry in the table, append path only if below time threshold in order to discard bad paths
              ; check if the same path is in the table
              let tmp-visited-nodes table:get [routing-table] of start-node [who] of destination-node
              set tmp-visited-nodes lput visited-nodes tmp-visited-nodes
              table:put [routing-table] of start-node [who] of destination-node tmp-visited-nodes
            ][
              ; initialize entry for the destination
              let list-tmp [] ; create list of list
              set list-tmp lput visited-nodes list-tmp
              table:put [routing-table] of start-node [who] of destination-node list-tmp
            ]
          ][
            ; if destination node is not directly reachable from current-node (no destination in link-neighborhors) move to a random neighbor
            let next-hop one-of [link-neighbors] of current-node
            let start-time timer
            move-to-node self next-hop
            let hop-time timer - start-time

            set total-hop-time total-hop-time + hop-time
            set visited-nodes lput current-node visited-nodes
            set current-node next-hop
          ]

          set hops hops + 1
        ]

        ;output-print (word "time delta " time-delta)
      ]
    ]
  ]

  ; once i have the paths, the backtracking process starts
  ask nodes [
    let start-node self
    ask nodes with [who != [who] of start-node][
      let destination-node self
      ask ants[
        move-to destination-node
        if table:has-key? [routing-table] of start-node [who] of destination-node[
          let list-path table:get [routing-table] of start-node [who] of destination-node ; there could be multiple paths
          ;let path one-of list-path
          ;backtrack-ant-update-pheromone self path
          foreach list-path [
            path ->
            ;let path one-of list-path
            ;output-print (word "start " start-node " destination " destination-node " path " path)
            backtrack-ant-update-pheromone self path
          ]
        ]
      ]
    ]
  ]

  ; cleaning routing table: remove paths too long in terms of hops
  ask nodes [
    ; for each destination pick the shortest path (L_best) and keep the paths such that their length is not grater than 1.5 * L_best
    foreach table:keys [routing-table] of self [
      destination ->


    ]
  ]

  if debug-reactive [
    ask nodes [
      output-print (word "[reactive] routing-table of node " self)
      output-print routing-table
      output-print (word "[reactive] pheromone-table of node " self)
      output-print pheromone-table
      output-print ""
    ]
  ]

  ask ants [
    die
  ]
end

to backtrack-ant-update-pheromone [backward-ant visited-nodes]
  if debug-reactive-backtrack [
    output-print word "[backtrack] visited-nodes " visited-nodes
  ]
  reset-timer

  let last-node last visited-nodes
  set visited-nodes but-last visited-nodes

  let Tmac (number-of-packets-in-queue + 1) * avg-time-to-send-pkt
  let total-time 0
  let cnt-hop 1
  while [length visited-nodes > 0][
    let previous-node last visited-nodes

    let start-time timer
    move-to-node backward-ant previous-node
    let hop-time timer - start-time


    set total-time total-time + hop-time
    ;set total-time 0.03
    ; update Tmaxc
    set Tmac (alpha * Tmac) + ((1 - alpha) * hop-time)

    ; update pheromone value
    let pheromone-value ((total-time + (cnt-hop * Thop))/(2))^(-1)
    ;let pheromone-value ((hop-time + (cnt-hop * Thop))/(2))^(-1)

    ifelse table:has-key? [pheromone-table] of previous-node [who] of last-node [
      if debug-proactive or debug-reactive [
        ;output-print (word "---------------------------------------")
        ;output-print (word "[proactive-backward] updating-pheromone")
        ;output-print (word "[proactive-backward] total-time " total-time " cnt-hop " cnt-hop " Thop " Thop " pheromone-value "pheromone-value)
        ;output-print (word "---------------------------------------")
      ]
      let tmp-pheromone table:get [pheromone-table] of previous-node [who] of last-node
      set tmp-pheromone (gamma * tmp-pheromone) + ((1 - gamma) * pheromone-value)

      table:put [pheromone-table] of previous-node [who] of last-node tmp-pheromone

      if debug-reactive-backtrack [
        output-print (word "[backtrack] [pheromone-table] of " previous-node " destination node " [who] of last-node)
        output-print (word "[backtrack] pheromone value " tmp-pheromone)
        output-print (word "[backtrack] total-time " total-time " cnt-hop " cnt-hop " Thop " Thop)
      ]
    ][
      ; no pheromone value - add entry to the table
      table:put [pheromone-table] of previous-node [who] of last-node pheromone-value
    ]

    set cnt-hop cnt-hop + 1
    set last-node previous-node
    set visited-nodes but-last visited-nodes

  ]
end

to send-message
  ask messages [die]

  ; create only one agent-message than repeat routing procedure number-of-messages times
  create-messages 1 [
    set size 1
    set shape "letter sealed"
  ]

  let source-node one-of nodes
  let destination-node 0

  set destination-node one-of nodes with [who != [who] of source-node]
  ;set destination-node one-of nodes with [who != [who] of source-node and member? who [who] of [link-neighbors] of source-node = false and count [link-neighbors] of self > 0]
  ;set destination-node one-of nodes with [who != [who] of source-node and nw:distance-to source-node != false]

  repeat number-of-messages [
    let msg 0
    ask messages [
      set msg self
      move-to source-node
    ]
    if debug-routing [
      output-print (word "[sending message] " source-node " -> " destination-node)
    ]

    if destination-node != nobody [
      carefully [
        routing msg source-node destination-node
      ][
        ; link failure occurred - look for alternative paths
        random-search msg source-node destination-node
      ]

      if proactive-maintenance [
        ask ants [die]
        create-ants number-of-proactive-ants [
          set size 1
          set shape "bug"
          set repair false
        ]
        if packet-counter mod sending-rate = 0 and count [link-neighbors] of source-node > 0[
          carefully [
            proactive-path-maintenance ants source-node destination-node
          ][
          ]
        ]
        ask ants [die]
      ]
    ]

    if packet-counter mod 10000 = 0 [
      stop
    ]
  ]

  ask messages [die]

  if show-routing-params [
    output-print (word "avg-hops-delivered " avg-hops-delivered " avg-send-time " avg-send-time " avg-pkt-loss " pkt-loss-ratio)
  ]

  update-plots
end

to proactive-path-maintenance [agents src dst]
  ; send a  proactive forward ant every n packet sent
  reset-timer

  ask agents [
    ; during the sending process proactive ants are sent to monitor the path quality - with a small probability the ants can look for other paths
    let random-path random-float 1
    ifelse random-path < explore-random-path-threshold [
      ; look for random nodes in order to reach destination
      random-search self src dst
    ][
      ; no random search - monitor the quality of the path and update pheromone value
      ask src [
        if nw:distance-to dst != false [
          routing self self dst
        ]
      ]

    ]
  ]
end

to random-search [agent source-node destination-node]
  ; when msg/ant does not arrive to destination, either a link failure occurred or if the node was reachable it couldn't arrive
  ; this procedure handle these situation and move the agent randomly in the net
  let visited-nodes []
  let current-node source-node
  let cnt-hops 0

  ;output-print (word "agent " agent " souce-node " source-node " destination-node " destination-node)
  while [current-node != destination-node and cnt-hops < maxhops][
    ask one-of [link-neighbors] of current-node [
      set visited-nodes lput self visited-nodes
      ask agent [ ; probably viene l'errore poichè agent = node e node non ce l'ha l'attributo speed, devo controllare che agent sia ants oppure messages
        move-to-node self myself
      ]

      set current-node self

      if current-node = destination-node and [breed] of agent = ants [
        backtrack-ant-update-pheromone agent visited-nodes
      ]
    ]

    set cnt-hops cnt-hops + 1
  ]
end

to routing [agent source-node destination-node]
  ; agent represent a message or an ant
  reset-timer

  let start-send-time timer

  let visited-nodes []
  let cnt-hops 0

  let path []

  let current-node source-node
  set visited-nodes lput current-node visited-nodes

  while [(current-node != destination-node) and (cnt-hops < maxhops)][
    if debug-routing [
      output-print "##### routing status #####"
      output-print (word "current-node --> " current-node)
      output-print (word "destination-node --> " destination-node)
      output-print (word "link-neighbors of current-node " current-node " -> " ) ask [link-neighbors] of current-node  [output-print self]
      output-print (word "pheromone-table of current-node " current-node " -> " [pheromone-table] of current-node)
      output-print ""
    ]

    ifelse member? destination-node [link-neighbors] of current-node = true [
      ; if destination is in neighbors of the current node
      set current-node destination-node
      move-to-node agent destination-node

      set visited-nodes lput destination-node visited-nodes

      if [breed] of agent = ants [
        ask ants [
          if debug-reactive [
            output-print (word "[reactive-backward] visited-nodes " visited-nodes " ant " self)
          ]

          if debug-proactive [
            output-print (word "[proactive-backward] visited-nodes " visited-nodes " src " source-node " dst " destination-node)
          ]

          backtrack-ant-update-pheromone agent visited-nodes
        ]
      ]
      ;output-print (word "current-node --> " current-node)
      ;output-print (word "destination-node --> " destination-node)
    ][
      ; destination-node is not in the neighborhood of current-node so i look if the destination is in the routing table
      ;ifelse table:has-key? [routing-table] of current-node [who] of destination-node [
      ask current-node [
        ifelse nw:distance-to destination-node != false [
          ;
          let probabilities []
          let sum-pheromone 0

          ask [link-neighbors] of current-node [
            ; look for neighbors with a path to destination-node
            if nw:distance-to destination-node != false [
              let pheromone table:get [pheromone-table] of current-node [who] of self ; from pheromone-table of current node pick the entry of the neighbor
              ifelse [breed] of agent = messages [
                set sum-pheromone sum-pheromone + (pheromone ^ 2)
              ][
                set sum-pheromone sum-pheromone + pheromone ; no squared value if agent is an ant
              ]
            ]
          ]

          ; once i have the sum of pheromone - needed for normalization - i can ask to same nodes which one to pick
          ask [link-neighbors] of current-node [
            if nw:distance-to destination-node != false [
              let pheromone-of-neighbor table:get [pheromone-table] of current-node [who] of self
              let pair []
              set pair lput [who] of self pair ; first the id node
              ifelse [breed] of agent = messages [
                set pair lput ((pheromone-of-neighbor ^ 2) / sum-pheromone) pair ; then the pheromone value representing the weight
              ][
                set pair lput (pheromone-of-neighbor / sum-pheromone) pair
              ]
              set probabilities lput pair probabilities
            ]
          ]

          if probabilities != [] [
            if debug-routing [
              output-print (word "probabilities --> " probabilities )
            ]
            set current-node node first rnd:weighted-one-of-list probabilities [ [p] -> last p ] ; the function returns an integer number e.g. "2" instead of "node 2"
          ]

          set visited-nodes lput current-node visited-nodes
          move-to-node agent current-node
        ][
          ; current-node has no entry for destination node - pick a random neighbor node
          if count [link-neighbors] of current-node > 0 [
            ask one-of [link-neighbors] of current-node [
              set current-node self
              set visited-nodes lput current-node visited-nodes
            ]
          ]
        ]
      ]

    ]

    set cnt-hops cnt-hops + 1
    if debug-routing [
      output-print word "cnt-hops --> " cnt-hops
      output-print "##########################"
    ]
  ]

  ;output-print (word "src " source-node " dst " destination-node " visited-nodes " visited-nodes)

  let send-time timer - start-send-time
  set packet-counter packet-counter + 1
  set avg-hops-total avg-hops-total + ((cnt-hops - avg-hops-total) / packet-counter)

  update-metrics agent current-node destination-node cnt-hops send-time
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
@#$#@#$#@
GRAPHICS-WINDOW
0
10
762
612
-1
-1
7.33
1
10
1
1
1
0
0
0
1
-51
51
-40
40
0
0
1
ticks
30.0

SLIDER
767
49
902
82
radius
radius
1
100
20.0
1
1
NIL
HORIZONTAL

BUTTON
768
10
899
43
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

OUTPUT
767
212
1890
612
12

SLIDER
768
88
902
121
number-of-nodes
number-of-nodes
1
100
70.0
1
1
NIL
HORIZONTAL

SLIDER
768
127
902
160
number-of-ants
number-of-ants
1
100
5.0
1
1
NIL
HORIZONTAL

BUTTON
951
10
1139
43
NIL
reactive-path-setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
951
50
1141
83
number-of-packets-in-queue
number-of-packets-in-queue
2
30
2.0
1
1
NIL
HORIZONTAL

SLIDER
952
90
1143
123
avg-time-to-send-pkt
avg-time-to-send-pkt
0.1
1
0.2
0.01
1
s
HORIZONTAL

SLIDER
952
128
1143
161
Thop
Thop
0.001
10
0.004
0.001
1
NIL
HORIZONTAL

BUTTON
1539
621
1700
654
NIL
reset-tables
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1437
10
1585
43
NIL
send-message
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
1437
48
1586
81
number-of-messages
number-of-messages
1
100
4.0
1
1
NIL
HORIZONTAL

SLIDER
1196
50
1373
83
sending-rate
sending-rate
1
100
4.0
1
1
NIL
HORIZONTAL

SWITCH
1694
17
1885
50
debug-reactive
debug-reactive
1
1
-1000

BUTTON
1437
86
1587
119
NIL
move-nodes
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
1694
127
1884
160
debug-routing
debug-routing
1
1
-1000

BUTTON
1539
658
1700
691
NIL
clr-output
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
1196
92
1374
125
number-of-proactive-ants
number-of-proactive-ants
1
100
1.0
1
1
NIL
HORIZONTAL

SWITCH
1695
90
1884
123
debug-proactive
debug-proactive
1
1
-1000

SWITCH
1196
10
1373
43
proactive-maintenance
proactive-maintenance
0
1
-1000

SWITCH
1694
53
1885
86
debug-reactive-backtrack
debug-reactive-backtrack
1
1
-1000

PLOT
0
616
307
806
avg # hops for delivered packets
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot avg-hops-delivered"

PLOT
614
615
919
805
avg send time
NIL
NIL
0.0
10.0
0.0
0.5
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot avg-send-time"

PLOT
921
615
1224
805
pkt loss ratio
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot pkt-loss-ratio"

SWITCH
1694
163
1884
196
show-routing-params
show-routing-params
1
1
-1000

PLOT
1227
614
1530
802
pkt loss cnt
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot pkt-loss-cnt"

BUTTON
1539
695
1700
728
NIL
reset-metrics
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1438
122
1587
155
NIL
kill-random-link
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1539
731
1699
764
NIL
reset-packet-counter
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
309
616
612
805
avg # hops for all packets
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot avg-hops-total"

SLIDER
768
163
903
196
max-hops
max-hops
1
200
70.0
1
1
NIL
HORIZONTAL

BUTTON
1539
767
1700
800
NIL
export-all-plots-separately
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
1438
160
1587
193
node-speed
node-speed
0
1
0.6
0.01
1
NIL
HORIZONTAL

BUTTON
1703
621
1864
654
NIL
setting-globals
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

letter opened
false
0
Rectangle -7500403 true true 30 90 270 225
Rectangle -16777216 false false 30 90 270 225
Line -16777216 false 150 30 270 105
Line -16777216 false 30 105 150 30
Line -16777216 false 270 225 181 161
Line -16777216 false 30 225 119 161
Polygon -6459832 true false 30 105 150 30 270 105 150 180
Line -16777216 false 30 105 270 105
Line -16777216 false 270 105 150 180
Line -16777216 false 30 105 150 180

letter sealed
false
0
Rectangle -7500403 true true 30 90 270 225
Rectangle -16777216 false false 30 90 270 225
Line -16777216 false 270 105 150 180
Line -16777216 false 30 105 150 180
Line -16777216 false 270 225 181 161
Line -16777216 false 30 225 119 161

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
