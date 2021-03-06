globals [
  food-regeneration-freq ;; (unit: ticks) when food disappears from a patch, how long does it take to re-appear?
  food-energy ;; (unit: energy units) when food is eating by an agent, how many units of energy does it give?
  turtle-reproduction-cost ;; (unit: energy units) when an agent reproduces, how many units of energy does he lose?
  foodprice ;; (unit: money) positive value: how many money units does a piece of food cost?
  max_foodprice_init ;; (unit: money) positive value: how many MAX money units does a piece of food cost?
  max_stockprice_init ;; (unit: money) positive value: how many MAX money units does a share of stock cost?
  min_turtleenergy ;; (unit: energy units) Below this level of energy the agent gets "desperate" for food.
  stock_asks ;; (unit: list of list of agent-id,amount. So ~ [[4,25], [5,31]]) What are agents asking for their stocks.
  stock_bids ;; (unit: list of list of agent-id,amount. So ~ [[14,31], [5,21]]) What are agents prepared to pay for stocks.
  total-num-stocks ;; (unit: int) number of stocks in the market
  gini-index-reserve ;; (unit: int)
  lorenz-points;; (unit: list)
  total-wealth;;
]
patches-own [
  p_foodappearonticks ;; value of ticks when food will appear here (if it's in the past => means that food is present)
]

turtles-own [
  optimalpricefood ;; price that an agent is ready to pay for food
  optimalpricestock ;; price that an agent thinks it's fait for a stock share
  energy ;; (unit: energy units) energy the agent has
  reproduce-freq ;; (unit: ticks) Probabilistically, how often this agent clones itself
  money ;; (unit: money units) how much money any agent owns
  num-stocks ;; (unit: int) how many stocks do I own
]

;; bids and asks

to add-ask [ agent-id ask-value ]
  (remove-asking-from agent-id) ;; if the agent is asking again, we assume it wants to forget about the first thing
  set stock_asks (lput (list agent-id ask-value) stock_asks)
  set stock_asks sort-by [ [tuple1 tuple2] -> (item 1 tuple1) < (item 1 tuple2) ] stock_asks ;; smaller asks come out first
end

to add-bid [ agent-id bid-value ]
  (remove-bidding-from agent-id) ;; if the agent is bidding again, we assume it wants to forget about the first thing
  set stock_bids (lput (list agent-id bid-value) stock_bids)
  set stock_bids sort-by [ [tuple1 tuple2] -> (item 1 tuple1) > (item 1 tuple2) ] stock_bids ;; larger bids come out first
end

to-report exists_ask
  report not empty? stock_asks
end

to-report exists_bid
  report not empty? stock_bids
end

to-report lowest_ask
  report (item 1 (first stock_asks))
end

to-report id_for_lowest_ask
  report (item 0 (first stock_asks))
end

to-report highest_bid
  report (item 1 (first stock_bids))
end

to-report id_for_highest_bid
  report (item 0 (first stock_bids))
end

to-report market-spread
  ifelse exists_ask and exists_bid [report lowest_ask - highest_bid] [report 0]
end

to-report agent-bidding [ ag-id ]
  report agent-participating ag-id stock_bids
end

to-report agent-asking [ ag-id ]
  report agent-participating ag-id stock_asks
end

to-report agent-participating [ ag-id list_of_ids_and_values ]
  foreach list_of_ids_and_values [ id_and_value ->
    if (first id_and_value = ag-id) [ report true ]
  ]
  report false
end

to-report delete-agent-reference-in [ ag-id list_of_ids_and_values ]
  report filter [ id_and_value -> not (first id_and_value = ag-id) ] list_of_ids_and_values
end

to remove-bidding-from [ ag-id ]
  set stock_bids (delete-agent-reference-in ag-id stock_bids)
end

to remove-asking-from [ ag-id ]
  set stock_asks (delete-agent-reference-in ag-id stock_asks)
end

to test-asks-and-bids
  add-ask 101 10
  add-ask 102 20
  add-ask 103 5
  print (word "asks => " stock_asks)
  print (word "Lowest ask is " lowest_ask)
  (remove-asking-from 102)
  print (word "Removing agent 102 from asking => " stock_asks)
  (remove-asking-from 444)
  print (word "Removing agent 444 from asking => " stock_asks)
  add-bid 101 10
  add-bid 102 20
  add-bid 103 5
  print (word "bids => " stock_bids)
  print (word "Highest bid is " highest_bid)
  (remove-bidding-from 102)
  print (word "Removing agent 102 from bidding => " stock_bids)
  (remove-bidding-from 333)
  print (word "Removing agent 333 from bidding => " stock_bids)
end

;; setup

to setup-globals
  set food-regeneration-freq 10
  set food-energy 10
  set turtle-reproduction-cost food-energy * 10
  set max_foodprice_init 100
  set max_stockprice_init 1000
  set foodprice random max_foodprice_init
  set min_turtleenergy random 10
  set stock_bids []
  set stock_asks []
  set total-num-stocks (number-of-agents + (random 9 * number-of-agents))
  set total-wealth 0
end

to setup
  clear-all
  setup-globals
  reset-ticks
  setup-patches
  setup-turtles
end

to setup-patches
  ask patches [set p_foodappearonticks random 10]
  draw-patches
end

to setup-turtles
  create-turtles number-of-agents [
    setxy random-xcor random-ycor
    set optimalpricefood (1 + random max_foodprice_init)
    set optimalpricestock (1 + random max_stockprice_init)
    set energy (random 10) + min_turtleenergy
    set color white
    set reproduce-freq (random 100)
    set money ((optimalpricefood + optimalpricestock) + (random (optimalpricefood + optimalpricestock)))
    set num-stocks 0
  ]
  ;; how much money do we need, in the worst of cases, to buy all stocks?
  let maxoptimalstockprice (max [optimalpricestock] of turtles)
  let total-money (maxoptimalstockprice * total-num-stocks)
  let money-per-agent total-money / number-of-agents
  print ( word "Max stock price: " maxoptimalstockprice ", " total-num-stocks " to distribute => total money needed = " total-money " (" money-per-agent "$ per agent)")
  ask turtles [
    set money money-per-agent
  ]
  ;; go around distributing stocks:
  while [total-num-stocks > 0] [
    ask one-of turtles [
      if money >= (optimalpricestock + optimalpricefood) [
        set money (money - optimalpricestock)
        set num-stocks (num-stocks + 1)
        set total-num-stocks (total-num-stocks - 1)
      ]
    ]
  ]
end

;; patches
to draw-patches
  ask patches [
    ifelse p_foodappearonticks <= ticks
    [ set pcolor lime + 3 ]
    [ ifelse p_foodappearonticks <= ticks + 3
      [set pcolor gray]
      [set pcolor black]
    ]
  ]
end

;; movements

to go
  if not any? turtles [ stop ]
  move-turtles
  try-to-eat
  try-to-buy-or-sell
  draw-patches
  update-lorenz-and-gini
  tick
end

to try-to-buy-or-sell
  ask turtles [
    ;; first of all: if I am bidding, but I don't have money to cover that deal, retreat it
    if (exists_ask and money < lowest_ask) [
      ;; print (word "Agent " who " was bidding, but now it can't cover the lowest ask (that is " lowest_ask "; agent's money is " money ". Retrieving bid.")
      remove-bidding-from who
    ]
    ;; selling?
    if not (agent-bidding who) [ ;; if I am bidding, I can't be asking
      if (num-stocks > 0) [
        ifelse (money <= 1.5 * foodprice) [ ;; this agent is desperate
                                            ;; print (word "Agent " who " is desperate: it has " money "$, and food is " foodprice)
          if exists_bid [
            add-ask who highest_bid
          ]
        ]
        [
          if (not exists_ask) or (lowest_ask > optimalpricestock) [
            add-ask who optimalpricestock
          ]
        ]
      ]
    ]
    ;; buying?
    if not (agent-asking who) [ ;; if I am asking, I can't be bidding
      if (money > optimalpricestock) [
        if exists_ask and (lowest_ask <= optimalpricestock) [
          add-bid who lowest_ask ;; I match the offer
        ]
      ]
    ]
  ]
  ;; let's match markets:
  match-market
end

to match-market
  if exists_ask and exists_bid [
    let the_ask lowest_ask
    if the_ask <= highest_bid [
      ;; print (word "[matching market] lowest ask = " the_ask ", highest_bid = " highest_bid)
      ;; update turtles involved in transaction
      ask turtle id_for_lowest_ask [
        set num-stocks (num-stocks - 1)
        set money (money + the_ask)
        ;; print (word "====> turtle " who " got paid " the_ask " $; it has now " num-stocks " stocks and " money " $")
      ]
      ask turtle id_for_highest_bid [
        set num-stocks (num-stocks + 1)
        set money (money - the_ask)
        ;; print (word "====> turtle " who " paid " the_ask " $ for a stock; it has now " num-stocks " stocks and " money " $")
      ]
      ;; update asks and bids
      set stock_bids (but-first stock_bids) ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; <========== MISSING ACTUALLY GIVING MONEY, TAKING MONEY!!!!!!
      set stock_asks (but-first stock_asks)
      ;; print (word "[END matching market] num asks = " (length stock_asks) ", num bids = " (length stock_bids))
      ;; and we do it until all matches are satisfied:
      match-market
    ]
  ]
end

to check-death
  ask turtles [
    if energy <= 0 [
      remove-bidding-from who
      remove-asking-from who
      die
    ]
  ]
end

to try-to-reproduce
  ask turtles [
    if (energy > turtle-reproduction-cost) and (reproduce-freq > 0) and ((random-float 1) <= (1 / reproduce-freq)) [
      hatch 1 [
        setxy xcor ycor
        set optimalpricefood (random-normal 1 0.1) * optimalpricefood
        ;; set optimalpricefood ((random-float 1) + 0.5) * optimalpricefood
        set energy (random 10) + min_turtleenergy
        set color white
        set reproduce-freq reproduce-freq
        set money foodprice + (random 2 * foodprice)
      ]
    ]
  ]
end

to move-turtles
  ask turtles [
    right random 360
    forward 1
    set energy (energy - 1)
    ifelse energy <= min_turtleenergy
    [ set label energy
      set color red
    ]
    [ set label ""
      set color white
    ]
  ]
  check-death
  try-to-reproduce
end

to try-to-eat
  ask turtles [
    if p_foodappearonticks <= ticks [ ;; there is food to be eaten
      if (energy <= min_turtleenergy or foodprice <= optimalpricefood) and (money >= foodprice) [ ;; turtle is eating the piece of food!
        set p_foodappearonticks ticks + food-regeneration-freq ;; set up when energy will re-appear
        set energy (energy + food-energy)
        set money (money - foodprice)
        set foodprice optimalpricefood ;; since I just bought it, this is the price of the food
      ]
    ]
  ]
end



; this procedure recomputes the value of gini-index-reserve
;; and the points in lorenz-points for the Lorenz and Gini-Index plots
to update-lorenz-and-gini
  let sorted-wealths sort [money] of turtles
  let current-num-agents length(sorted-wealths) ;; same as (count turtles)
  set total-wealth sum sorted-wealths
  let wealth-sum-so-far 0
  let index 0
  set gini-index-reserve 0
  set lorenz-points []

  ;; now actually plot the Lorenz curve -- along the way, we also
  ;; calculate the Gini index.
  ;; (see the Info tab for a description of the curve and measure)
  foreach sorted-wealths [ current-wealth ->
    set wealth-sum-so-far (wealth-sum-so-far + current-wealth)
    set lorenz-points lput ((wealth-sum-so-far / total-wealth) * 100) lorenz-points
    set index (index + 1)
    set gini-index-reserve
      gini-index-reserve +
      (index / current-num-agents) -
      (wealth-sum-so-far / total-wealth)
  ]
end

@#$#@#$#@
GRAPHICS-WINDOW
345
10
794
460
-1
-1
13.364
1
10
1
1
1
0
1
1
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
275
117
341
150
NIL
Setup
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
274
160
337
193
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

PLOT
802
275
1169
534
Food price
time
price
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"foodprice" 1.0 0 -16777216 true "" "plot foodprice"
"price bid (mean)" 1.0 0 -7500403 true "" "plot mean [optimalpricefood] of turtles"
"price bid (std dev)" 1.0 0 -2674135 true "" "plot standard-deviation [optimalpricefood] of turtles"

PLOT
801
12
1168
274
Totals
time
totals
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"agents" 1.0 0 -2674135 true "" "plot count turtles"
"food" 1.0 0 -5509967 true "" "plot count patches with [pcolor = lime + 3]"

SLIDER
32
18
288
51
number-of-agents
number-of-agents
0
10000
4080.0
10
1
individuals
HORIZONTAL

BUTTON
88
498
240
531
NIL
test-asks-and-bids
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

PLOT
1174
203
1480
376
Gini index
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
"default" 1.0 0 -16777216 true "" "plot (gini-index-reserve / (count turtles)) / 0.5"

PLOT
1173
12
1479
199
Market Spread
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
"default" 1.0 0 -16777216 true "" "plot market-spread"

PLOT
1176
378
1483
619
Lorenz Curve (Money)
Pop %
Wealth %
0.0
100.0
0.0
100.0
false
false
"" ""
PENS
"Lorenz Curve" 1.0 0 -10873583 true "" "plot-pen-reset\nset-plot-pen-interval 100 / (count turtles)\nplot 0\nforeach lorenz-points plot"
"Perfect Equality" 100.0 0 -7500403 true "plot 0\nplot 100" ""

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

To observe the equity (or the inequity) of the distribution of wealth, a graphical tool called the Lorenz curve is utilized.  We rank the population by their wealth and then plot the percentage of the population that owns each percentage of the wealth (e.g. 30% of the wealth is owned by 50% of the population).  Hence the ranges on both axes are from 0% to 100%.

Another way to understand the Lorenz curve is to imagine a society of 100 people with a fixed amount of wealth available.  Each individual is 1% of the population.  Rank the individuals in order of their wealth from greatest to least: the poorest individual would have the lowest ranking of 1 and so forth.  Then plot the proportion of the rank of an individual on the y-axis and the portion of wealth owned by this particular individual and all the individuals with lower rankings on the x-axis.  For example, individual Y with a ranking of 20 (20th poorest in society) would have a percentage ranking of 20% in a society of 100 people (or 100 rankings) --- this is the point on the y-axis.  The corresponding plot on the x-axis is the proportion of the wealth that this individual with ranking 20 owns along with the wealth owned by all the individuals with lower rankings (from rankings 1 to 19).  A straight line with a 45 degree incline at the origin (or slope of 1) is a Lorenz curve that represents perfect equality --- everyone holds an equal part of the available wealth.  On the other hand, should only one family or one individual hold all of the wealth in the population (i.e. perfect inequity), then the Lorenz curve will be a backwards "L" where 100% of the wealth is owned by the last percentage proportion of the population.  In practice, the Lorenz curve actually falls somewhere between the straight 45 degree line and the backwards "L".

For a numerical measurement of the inequity in the distribution of wealth, the Gini index (or Gini coefficient) is derived from the Lorenz curve.  To calculate the Gini index, find the area between the 45 degree line of perfect equality and the Lorenz curve.  Divide this quantity by the total area under the 45 degree line of perfect equality (this number is always 0.5 --- the area of 45-45-90 triangle with sides of length 1).  If the Lorenz curve is the 45 degree line then the Gini index would be 0; there is no area between the Lorenz curve and the 45 degree line.  If, however, the Lorenz curve is a backwards "L", then the Gini-Index would be 1 --- the area between the Lorenz curve and the 45 degree line is 0.5; this quantity divided by 0.5 is 1.  Hence, equality in the distribution of wealth is measured on a scale of 0 to 1 --- more inequity as one travels up the scale.  Another way to understand (and equivalently compute) the Gini index, without reference to the Lorenz curve, is to think of it as the mean difference in wealth between all possible pairs of people in the population, expressed as a proportion of the average wealth (see Deltas, 2003 for more).

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
NetLogo 6.0.2
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
