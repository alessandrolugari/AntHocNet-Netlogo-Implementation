extensions [
  table
  rnd
]

breed [nodes node]
breed [ants ant]
breed [messages message]

; ants and messages behave in a similar way

globals [
  maxhops
  maxtriptime
  ; params for reactive path setup
  alpha
  gamma
]

nodes-own [
  routing-table ; contains paths to reach other nodes
  pheromone-table ; contains value of pheromone to all destinations
]

ants-own [
  speed ; 0 <= speed <= 1 if below 1 the ant is slower, 1 equals to normal velocity
]

messages-own [
  speed
]

to clr
  ; ca
  clear-output
  reset-ticks
  reset-timer

  ask nodes [
    ; initialize tables
    set routing-table table:make
    set pheromone-table table:make
  ]
end

to setup
  ca
  reset-ticks
  reset-timer

  ; setting globals
  set maxhops 50
  set maxtriptime 50 ; seconds
  set alpha 0.7
  set gamma 0.7

  create-nodes number-of-nodes [
    set size 2
    setxy random-xcor random-ycor
    set label who
    set shape "circle"
    create-links-with other nodes in-radius radius
  ]

  create-ants number-of-ants [
    set size 1
    set shape "bug"
  ]

  ask links [
    ;output-print link-length
    ifelse link-length <= radius [
      set color white
    ][
      set color red
      die
    ]
  ]

  ask ants [
    set speed (1 - random-float 0.7) ; max decrease in speed is 0.7 in order to have a minimum speed = 0.3
  ]

end

to reactive-path-setup
  output-print "reactive-path-setup"
  ; move to start-node

  ask nodes [
    ; initialize tables
    set routing-table table:make
    set pheromone-table table:make
  ]

  ask nodes with [count link-neighbors > 0][
    let start-node self

    ask nodes with [who != [who] of start-node] [
      ask ants [
        move-to start-node
        let destination-node myself

        ;output-print (word "start-node -> " start-node " destination-node -> " destination-node " ant -> " self)
        let current-node start-node
        let hops 0
        let visited-nodes []
        let exit-while false

        let total-hop-time 0
        while [(current-node != destination-node or hops < maxhops) and exit-while = false][
          if hops > maxhops [
            set exit-while true
          ]
          ifelse current-node = destination-node [
            set visited-nodes lput destination-node visited-nodes
            ;output-print (word "visited-nodes -> " visited-nodes)
            set exit-while true

            ;output-print word "total-hop-time " total-hop-time
            ; update routing table only if hops/time are below certain threshold
            ifelse table:has-key? [routing-table] of start-node [who] of destination-node [
              ; already existing entry in the table, append path only if below time threshold in order to discard bad paths
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
            ; current-node is not destination-node
            ifelse member? destination-node [link-neighbors] of current-node [
              ; move ant to destination
              let start-time timer
              move-to-node self destination-node
              let hop-time timer - start-time

              set total-hop-time total-hop-time + hop-time
              set visited-nodes lput current-node visited-nodes
              set current-node destination-node
            ][
              ; if destination node is not directly reachable from current-node (no destination in link-neighborhors)
              let next-hop one-of [link-neighbors] of current-node
              let start-time timer
              move-to-node self next-hop
              let hop-time timer - start-time

              set total-hop-time total-hop-time + hop-time
              set visited-nodes lput current-node visited-nodes
              set current-node next-hop
            ]
          ]
          set hops hops + 1
          ;output-print (word "time delta " time-delta)
        ]
      ]
    ]
  ]

  ask nodes [
    let start-node self
    ask nodes with [who != [who] of start-node][
      let destination-node self
      ask ants[
        move-to destination-node
        if table:has-key? [routing-table] of start-node [who] of destination-node[
          let list-path table:get [routing-table] of start-node [who] of destination-node ; there could be multiple paths
          let path one-of list-path
          ;output-print (word "start " start-node " destination " destination-node " path " path)
          backtrack-ant-update-pheromone self path
        ]
      ]
    ]
  ]

  if debug [
    ask nodes [
      output-print (word "routing-table of node " self)
      output-print routing-table
      output-print (word "pheromone-table of node " self)
      output-print pheromone-table
      output-print ""
    ]
  ]
end

to backtrack-ant-update-pheromone [backward-ant visited-nodes]
  let last-node last visited-nodes
  set visited-nodes but-last visited-nodes

  let Tmac (number-of-packets-in-queue + 1) * avg-time-to-send-pkt
  let total-time 0
  let cnt-hop 1
  while [length visited-nodes > 1][ ; if length = 1 means that the list contain only the start node
    ;output-print word "debugging backtrack -- visited nodes " visited-nodes
    let previous-node last visited-nodes

    let start-time timer
    move-to-node self previous-node
    let hop-time timer - start-time ; this represent time to send pkt - in this case is the ant itself


    set total-time total-time + start-time
    ; update Tmaxc
    set Tmac (alpha * Tmac) + ((1 - alpha) * hop-time)

    ; update pheromone value
    let pheromone-value ((total-time + ((cnt-hop)*(Thop)))/(2))^(-1)
    ;output-print word "pheromone-value " pheromone-value
    ifelse table:has-key? [pheromone-table] of previous-node [who] of last-node [
      let tmp-pheromone table:get [pheromone-table] of previous-node [who] of last-node
      set tmp-pheromone (gamma * tmp-pheromone) + ((1 - gamma) * pheromone-value)
      table:put [pheromone-table] of previous-node [who] of last-node tmp-pheromone
    ][
      ; no pheromone value - add entry to the table
      table:put [pheromone-table] of previous-node [who] of last-node pheromone-value
    ]

    set cnt-hop cnt-hop + 1
    set last-node previous-node
    set visited-nodes but-last visited-nodes

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

to send-message
  ask messages [die]
  create-messages number-of-messages [
    set size 1
    set shape "letter sealed"
  ]
  ; implementation of stocastic data routing
  let current-node one-of nodes
  let destination-node one-of nodes with [who != [who] of current-node]

  ;let current-node one-of nodes with [who = 1]
  ;let destination-node one-of nodes with [who = 2]

  let msg 0
  ask messages [
    set msg self
    move-to current-node
  ]

  let cnt-hops 0
  let exit-while false
  while [current-node != destination-node or cnt-hops < maxhops][
    if debug [
      output-print (word "current-node " current-node " destination-node " destination-node)
      output-print (word "link-neighbors of current-node " current-node " -> " [link-neighbors] of current-node)
    ]
    ifelse member? destination-node [link-neighbors] of current-node [
      ; if destination is in neighbors of the current node
      set current-node destination-node
      move-to-node msg destination-node
      set exit-while true
    ][
      ; destination-node is not in the neighborhood of current-node
      if table:has-key? [routing-table] of current-node [who] of destination-node [
        let paths-list table:get [routing-table] of current-node [who] of destination-node

        ifelse length paths-list = 1 [
          ; no multiple paths
          let path first paths-list
          let current node first path
          move-to-node msg current-node
        ][
          ; multiple paths
          let probabilities []
          let sum-pheromone 0

          ask [link-neighbors] of current-node [
            ; look for neighbors with a path to destination-node
            if table:has-key? [routing-table] of self [who] of destination-node [
              let pheromone table:get [pheromone-table] of current-node [who] of self ; from pheromone-table of current node pick the entry of the neighbor
              set sum-pheromone sum-pheromone + (pheromone ^ 2)
            ]
          ]

          ; once i have the sum of pheromone - needed for normalization - i can ask to same nodes which one to pick
          ask [link-neighbors] of current-node [
            if table:has-key? [routing-table] of self [who] of destination-node[
              let pheromone-of-neighbor table:get [pheromone-table] of current-node [who] of self
              let pair []
              set pair lput [who] of self pair ; first the id node
              set pair lput ((pheromone-of-neighbor ^ 2) / sum-pheromone) pair ; then the pheromone value representing the weight
              set probabilities lput pair probabilities
            ]
          ]

          set current-node node first rnd:weighted-one-of-list probabilities [ [p] -> last p ]
          move-to-node msg current-node
        ]
      ]
    ]

    set cnt-hops cnt-hops + 1
    print "loop nel while del routing"
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
4
13
586
596
-1
-1
17.4
1
10
1
1
1
0
0
0
1
-16
16
-16
16
0
0
1
ticks
30.0

SLIDER
610
60
809
93
radius
radius
1
100
15.0
1
1
m
HORIZONTAL

BUTTON
611
18
678
51
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
610
187
1723
596
12

SLIDER
611
99
811
132
number-of-nodes
number-of-nodes
1
100
7.0
1
1
NIL
HORIZONTAL

SLIDER
611
139
811
172
number-of-ants
number-of-ants
1
100
2.0
1
1
NIL
HORIZONTAL

BUTTON
862
20
1019
53
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
862
60
1087
93
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
862
101
1086
134
avg-time-to-send-pkt
avg-time-to-send-pkt
0.1
1
0.5
0.01
1
s
HORIZONTAL

SLIDER
863
142
1086
175
Thop
Thop
0.001
0.7
0.003
0.001
1
NIL
HORIZONTAL

BUTTON
1705
13
1870
96
NIL
clr
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
1128
20
1254
53
NIL
send-message
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
1129
62
1321
95
number-of-messages
number-of-messages
1
100
1.0
1
1
NIL
HORIZONTAL

SLIDER
1130
107
1342
140
number-of-starting-node
number-of-starting-node
1
number-of-nodes
1.0
1
1
NIL
HORIZONTAL

SWITCH
1768
120
1871
153
debug
debug
1
1
-1000

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
