;;Extensions
extensions [array]

;;globals
globals [
  nest-xcor
  nest-ycor
  pheromones-diffusion
  pheromones-evaporation
]
breed [ants ant]        ;; ants breed is declared

ants-own [              ;; ant atributes
  state
  loaded?               ;; this informs if the ant is or not carring food
  load-type             ;; type of food being transported by the ant
  steps                 ;; number of steps the ant do to after leaving the nest and until it find a food location
  location
  loss-count            ;; this variable determines when an ant is lost
  fullness              ;; this variable measures if the ant feels hungry, so it can start looking for food
  food
  food-x                ;; the x coordinate where the ant found food the last time
  food-y                ;; the y coordinate where the ant found food the last time
  f-memory              ;; indicate if the ant have found any food source
  leader                ;; use to indicate other ants to follow self to be guided to the food source
]

patches-own [
  chemical-return      ;; amount of chemical on this patch
  food?                ;; is there food on this patch?
  food-type            ;; type of food in this patch if any - 0: none - 1: seed - 2: bug - 3: leaves - 4 : honeydew
  nest?                ;; true on nest patches, false elsewhere
  nest-scent           ;; number that is higher closer to the nest
  food-scent           ;; the smell a food source produces in the neigbors around
]

;;;;;;;;;;;;;;;;;;;;;;;;
;;; Setup procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;
	
to setup
  clear-all
  set-default-shape ants "bug"
  ;;calculate random locations for the nest and the ants
  random-seed ran-seed ;; Useful to have repeatable experiments
  set nest-xcor random-location min-pxcor max-pxcor
  set nest-ycor random-location min-pycor max-pycor
  create-ants population
  [ set size   2         ;; easier to see
    set color  red       ;; red = not carrying food
    set state "waiting"
    set xcor nest-xcor
    set ycor nest-ycor
    set steps 0
    set loaded? false
    set fullness random max_fullness
    set f-memory false
    set leader false
    set load-type 0
    if trace? [ pen-down ]
  ]
  setup-patches
  reset-ticks
end

to setup-patches
  ask patches [
    ;; Initialize patches as not being food or nest
    set food? false
    set nest? false
    set food-scent 0
  ]
  setup-food-sources 1 seeds
  setup-food-sources 2 bugs
  setup-food-sources 3 leaves
  setup-food-sources 4 honeydew
  ask patches [
    setup-nest nest-xcor nest-ycor ;; Place the nest at a random point
    recolor-patch ;; Color all the patches depending if they are food source or nest
  ]
end

to setup-nest [patch-xcor patch-pycor]	
  set nest? (distancexy patch-xcor patch-pycor) < 5	
  if nest? [	
    ;; If this is part of the nest, disable food sources	
    set food? false	
  ]	
end

to setup-pheromones
  set pheromones-diffusion read-from-string pheromone-diffusion-rates
  set pheromones-evaporation read-from-string pheromone-evaporation-rates
end

	;; Sets the number of food sources indicated by the food-sources slider
to setup-food-sources [ftype number-of-sources]
  repeat number-of-sources [
    ;; Get center for new patch
    let x-coord random-location min-pxcor max-pxcor
    let y-coord random-location min-pycor max-pycor
    let food-size ftype
    ;; Get the patch for the center of the food source
    ask patch x-coord y-coord [
      ;; Find the patches around the center and set them as food
      ask patches in-radius food-size [
        set food-type ftype
        set food? food? OR (distancexy x-coord y-coord) < food-size ;; This condition is required to make sources round, can be replaced with true
      ]
    ]
  ]
end

	;; @**********@ patch procedure @**********@ ;;
to recolor-patch
  ifelse nest?
  [ set pcolor violet ]
  [ifelse food? [
      if food-type = 1 [ set pcolor orange ] ;; seed
      if food-type = 2 [ set pcolor brown ] ;; bug
      if food-type = 3 [ set pcolor green ] ;; leaves
      if food-type = 4 [ set pcolor yellow ] ;; honeydew
    ] [
      ;; If there is food-scent, show it
      set pcolor scale-color pink food-scent 0.1 20
      ;; If there is a trace of pheromone show it
      if chemical-return > 0.1 [
        set pcolor scale-color green chemical-return 0.01 5
      ]
    ]
  ]
end

	;; @**********@ patch procedure @**********@ ;;
to-report random-location [minvalue maxvalue]
  let locationPat (random maxvalue) * ((-1) ^ one-of[1 2])
  if (locationPat >= (maxvalue - 10)) [
  report locationPat - 10
  ]
  if (locationPat <= (maxvalue + 10)) [
  report locationPat + 10
  ]
  report locationPat
end

;;;;;;;;;;;;;;;;;;;;;
;;; Go procedures ;;;
;;;;;;;;;;;;;;;;;;;;;

to go
  ask turtles
  [
  if who >= ticks [ stop ] ;; delay initial departure
  ;; works like an case statement so depending on the state the ant excecutes a particular behaviour
  if (state = "waiting" ) [hold]
  if (state = "searching" ) [search]
  if (state = "following" ) [follow-ant]
  if (state = "exploiting" ) [exploit]
  if (state = "recruiting" ) [recruit]
  ]

  setup-pheromones
  diffuse-chemical

  ;; Add the food-scent
  ask patches with [food?] [
    set food-scent 20
  ]
  ;; And diffuse it
  diffuse food-scent 0.3
  tick
end

;; @**********@ patch procedure @**********@ ;;
to diffuse-chemical
  diffuse chemical-return ((diffusion pheromone-return)/ 100)
  ask patches [
    set chemical-return chemical-return * (100 - (evaporation pheromone-return)) / 100  ;; slowly evaporate chemical
    recolor-patch
    ;; We need to lower the general level of food-scent since we are adding more constantly
    set food-scent food-scent / 1.1
  ]
end

;; @**********@ agent method @**********@ ;;
to hold
  set color white
  ;; While idle, the ant consumes its food reserves
  set fullness fullness - 1
  ifelse fullness = 0  [
    ;; Bellow the hunger threshold, switch to searching
    set state "searching"
  ] [
    ;; Move inside the nest
    let target one-of neighbors with [nest?]
    face target
    move-to target
  ]
  stop
end

	;; @**********@ agent method @**********@ ;;
to search
  set color red
  ;; Food has been found, proceed to exploiting state
  if food? OR food-scent > 0.1 [
    set state "exploiting"
    record-food-location
    stop
  ]
  ;; We are at the nest, define a heading at random and step out of it
  ifelse nest? and steps = 0
  [
    set steps 1
    set heading random 360
  ]
  [
    ;; when the ant remembers a location where it has found any food, it goes back to check if there is more
    ifelse f-memory
    [ go-last-food-source
    ]
    [
    ;; Otherwise just search at random
    ifelse (chemical-return >= 0.05) and (chemical-return < 2)    ;; original mecanism of pheromone following
       [join-chemical]
       [wiggle]
    ]
  ]
  fd 1
  set steps steps + 1
end

;; @**********@ agent method @**********@ ;;
;; this stores the coordinates where food source was found
to record-food-location
  set f-memory true
  set food-x xcor
  set food-y ycor
end

	;; @**********@ agent method @**********@ ;;	
to follow-ant	
  set color yellow	
 if loaded?	
  [ set state "searching"	
    stop]	
  let nearby-leaders turtles with [leader and (distance myself < 20)] ;; find nearby leaders	
  ifelse any? nearby-leaders [ ;; to avoid 'nobody'-error, check if there are any first	
    face min-one-of nearby-leaders [distance myself] ;; then face the one closest to myself	
    if not can-move? 1
    [ rt random 180 ]
    fd 1	
    set loss-count 0	
  ]	
  [	
    set loss-count loss-count + 1	
    if(loss-count > 100)	
    [set state "searching"	
     set loss-count 0	
    ] ;; if i was following some one but i dont see him for a period y go searching again	
  ]	
end

	;; @**********@ agent method @**********@ ;;	
to exploit	
  set color green	
  ifelse loaded? [	
    ;; we have food, lets get it to the nest	
    ;; If we got to the nest -> unload food and restart searching	
    ifelse nest? [	
      set loaded? false	
      ;; when the ant remembers a location where it has found any food, call others to show where the food source is	
      set leader true	
      ask ants in-radius 4 [ set state "following" ]	
      set state "searching"	
      stop	
    ] [	
      ;; Otherwise try to get to the nest	
      return-to-nest	
    ]	
  ] [	
    ;; We are not loaded, so we should try to grab food	
    ;; Is there food? ->  Grab it	
    if food? [	
      set food? false	
      set loaded? true	
      set load-type food-type
    ]	
    ;; Is there the scent of food? -> move towards higher concentrations of it	
      if food-scent > 0.1	
      [ uphill food-scent ]	
  ]	
end

;; @**********@ agent method @**********@ ;;
to recruit
  ;; here the mechanical recruitment (carry and tandem-->follow) should be implementes
  ;; also a chemical recruitment when a big food source is found asking for other ants help to move the food piece
  stop
end

;; @**********@ agent method @**********@ ;;
to join-chemical
  let scent-ahead chemical-scent-at-angle   0
  let scent-right chemical-scent-at-angle  45
  let scent-left  chemical-scent-at-angle -45
  if (scent-right > scent-ahead) or (scent-left > scent-ahead)
  [ ifelse scent-right > scent-left
    [ rt 45 ]
    [ lt 45 ] ]
end

;; @**********@ patch procedure @**********@ ;;
to-report chemical-scent-at-angle [angle]
  let p patch-right-and-ahead angle 1
  if p = nobody [ report 0 ]
  report [chemical-return] of p
end


;; @**********@ agent method @**********@ ;;
to wiggle  ;; turtle procedure
  ;; Move with less variability when getting out of the nest
  ;;let max_angle per_step_max_rotation / (1 + (exp (-0.1 * (steps - (per_step_max_rotation / 2))) ) )
  let ranright random 40
  let ranleft random 40
  let delta ranright - ranleft
  rt delta
  if not can-move? 1
  [ rt 180 ]
end

;; @**********@ agent method @**********@ ;;
to return-to-nest
  if load-type > 1 [ ;; if we are harvesting seeds there is no need to leave a pheromene trail
    set chemical-return chemical-return + 60
    set leader false
  ]
  ;; this is to say that the ant has memory of nest location so it heads toward the next to return
  ;; this method should be canged for a path integration method
  facexy nest-xcor nest-ycor
  if not can-move? 1
  [ rt 180 ]
  fd 1
end

	;; @**********@ agent method @**********@ ;;	
to go-last-food-source	
  ifelse (distancexy food-x food-y) > 1	
  [	
    facexy food-x food-y ;; if i remember where i found food I turn in food direction.	
    if not can-move? 1
    [ rt random 180 ]
  ]	
  [	
    set f-memory false	
    set leader false
    ask ants in-radius 10 [ set state "searching" ]	
  ]	
end

;; @**********@ Pheromones helper methods @**********@ ;;	
to-report evaporation [pheromone]
  ;; gets the evaporation rate for the pheromone index
  report item (pheromone - 1) pheromones-evaporation
end

to-report diffusion [pheromone]
  ;; gets the diffusion rate for the pheromone index
  report item (pheromone - 1) pheromones-diffusion
end
@#$#@#$#@
GRAPHICS-WINDOW
350
10
1163
824
-1
-1
5.0
1
10
1
1
1
0
0
0
1
-80
80
-80
80
1
1
1
ticks
30.0

SLIDER
24
40
196
73
population
population
1
50
50.0
1
1
NIL
HORIZONTAL

BUTTON
26
99
89
132
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

BUTTON
113
100
176
133
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
1

SLIDER
26
607
198
640
ran-seed
ran-seed
0
10000
7197.0
1
1
NIL
HORIZONTAL

SLIDER
25
243
205
276
per_step_max_rotation
per_step_max_rotation
0
180
50.0
5
1
NIL
HORIZONTAL

SWITCH
58
661
161
694
trace?
trace?
1
1
-1000

SLIDER
25
564
197
597
max_fullness
max_fullness
0
200
190.0
5
1
NIL
HORIZONTAL

SLIDER
1204
50
1376
83
seeds
seeds
0
200
13.0
1
1
NIL
HORIZONTAL

SLIDER
1206
99
1378
132
bugs
bugs
0
100
9.0
1
1
NIL
HORIZONTAL

SLIDER
1207
149
1379
182
leaves
leaves
0
100
9.0
1
1
NIL
HORIZONTAL

SLIDER
1208
197
1380
230
honeydew
honeydew
0
20
3.0
1
1
NIL
HORIZONTAL

PLOT
24
301
302
521
Ants by State
NIL
NIL
0.0
80.0
0.0
50.0
true
true
"" ""
PENS
"waiting" 1.0 0 -16777216 true "" "plotxy ticks count turtles with [state = \"waiting\"]"
"searching" 1.0 0 -2674135 true "" "plotxy ticks count turtles with [state = \"searching\"]"
"following" 1.0 0 -1184463 true "" "plotxy ticks count turtles with [state = \"following\"]"
"exploiting" 1.0 0 -13840069 true "" "plotxy ticks count turtles with [state = \"exploiting\"]"
"recruiting" 1.0 0 -2382653 true "" "plotxy ticks count turtles with [state = \"recruiting\"]"

TEXTBOX
1191
27
1341
45
Food sources
11
0.0
1

TEXTBOX
1194
261
1344
279
Pheromones
11
0.0
1

INPUTBOX
1204
286
1479
346
pheromone-diffusion-rates
[ 2 5 100 ]
1
0
String

INPUTBOX
1204
358
1475
418
pheromone-evaporation-rates
[ 5 20 20 ]
1
0
String

CHOOSER
1205
433
1343
478
pheromone-return
pheromone-return
1 2 3
0

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
NetLogo 6.1.1
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
