;;Extensions
extensions [array queue csv]

;;globals
globals [
  date
  time
  filename
  nest-xcor
  nest-ycor
  ;; trails
  pheromones-diffusion
  pheromones-evaporation
  pheromones-help-evaporation
  ;; memory
  last-feedernumber
  MemoryArray
  honeyDewLoc
  lstHoneyDew
  BugsLoc
  lstBugsLoc
  lstDeadBugsLoc
  DeadBugsLoc
  memory-switches       ;; global counter to indicate how many times ants have change food-location memory
  ;; measures
  elapsed-days          ;; a tiem frame is requiere to measure the amount collected
  food-collected-day    ;; how many food is collected by day
  food-collected        ;; total quantity of  collected food
  energy-collected-day  ;; how many energy is collected by day
  energy-collected      ;; total quantity of collected energy
  energy-units          ;; protein units
  energy-avg            ;; o	Average amount of energy per unit of energy collected
  protein-colleted-day  ;; how many protein is collected by day
  protein-colleted      ;; total quantity of collected protein
  protein-units         ;; protein units
  protein-avg           ;; o	Average amount of protein per unit of protein collected
  trail-patches         ;; number of patches that have enough chemical to be considered a trail
  debug                 ;; stop the execution for debugging
  maxNutritionalValue   ;; the value food quality from the food source with best quality
  antsFTSeed-count      ;; number of ants that are collecting seeds
  antsFTBug-count       ;; number of ants that are collecting bugs
  antsFTDeadBug-count   ;; number of ants that are collecting dead bugs
  antsFTHoneyDew-count  ;; number of ants that are collecting hobey dews
]

breed [ants ant]        ;; ants breed is declared

ants-own [              ;; ant atributes
  state
  loaded?               ;; this informs if the ant is or not carring food
  load-type             ;; type of food being transported by the ant
  steps                 ;; number of steps the ant do to after leaving the nest and until it find a food location
  loss-count            ;; this variable determines when an ant is lost
  fullness              ;; this variable measures if the ant feels hungry, so it can start looking for food
  energy                ;; this measures the enegetic expense of the colony while looking foor food.
  f-memory              ;; indicate if the ant have found any food source
  f-type-memory
  nutriQuality-memory   ;; related to the quality of the last food source that was found
  memstrength
  newfeedermemstrength
  leader                ;; use to indicate other ants to follow self to be guided to the food source
  bug-size
  bug-leader
  serendipity           ;; Number of ticks for which the ant will ignore pheromone trails to look for new food sources
  memory-waypoints      ;; List of list of x-y coordinates leading to a food source
  memory-next           ;; Index of the current point in the waypoints we are trying to reach
  memory-old-waypoints  ;; Waypoints to the previous food source, set before looking for other sources, will be restored if a better food source is not found
  memory-old-next       ;; Position of the next waypoint from the old list of waypoints
  memory-x
  memory-y
]

patches-own [
  chemical-return      ;; amount of chemical on this patch
  pheromone-recruit    ;; a type of pheromone that is droped when help to carry big food source is requiered
  food?                ;; is there food on this patch?
  food-type            ;; type of food in this patch if any - 0: none - 1: seed - 2: bug - 3: dead bugs - 4 : honeydew
  nutritionalQuality   ;; this value represents the food quality for the simulation we want to make ants search in other place than close to the nest so this value is to be directly relate to the nest distance
  nest?                ;; true on nest patches, false elsewhere
  nest-scent           ;; number that is higher closer to the nest
  food-scent           ;; the smell a food source produces in the neigbors around
  feedernumber         ;; id of the food source
]

;;;;;;;;;;;;;;;;;;;;;;;;
;;; Setup procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;
	
to setup
  clear-all
  setup-globals
  set-default-shape ants "bug"
  set last-feedernumber 0
  ;;calculate random locations for the nest and the ants
  random-seed ran-seed ;; Useful to have repeatable experiments
  nest-location
  setup-ants
  setup-patches
  reset-ticks
  stop-inspecting-dead-agents
  if trace? [ inspect ant 0 ]
  carefully [file-delete "temp.txt"] []
  prepare-csv-file
end

to prepare-csv-file
  file-close-all
  set date (remove "-" (substring date-and-time 16 27))
  set time (remove "." remove ":" remove " " (substring date-and-time 0 15))
  set filename (word "./logs/test-" date "-" time ".csv")
  if file-exists? filename
     [file-close
      file-delete filename
     ]
     file-open filename
  writeCSVrow filename  ["day" "energy-collected-day" "protein-colleted-day" "food-collected-day" "energy-avg" "protein-avg" "trail-patches" "antsFTSeed" "antsFTBug" "antsFTDeadbug" "antsFTHoneydew" "antsSearching" "antsFollowing" "antsExploiting" "antsExploit-bug" "antsRecruiting" "foodAvailable"]
end

to writeCSVrow [#fname #vals]
  file-open #fname
  file-type first #vals
  foreach but-first #vals [[?] ->
    file-type "," file-type ?
  ]
  file-print ""  ;;terminate line with CR
  file-close
end

to writeListToFile [#mylist #fname]
  carefully [file-delete #fname] []
  file-open #fname
  foreach #mylist [[?] ->
    file-print ?
  ]
  file-close
end

to nest-location
  ifelse fixed-food?
  [ set nest-xcor -21
    set nest-ycor -12 ]
  [ set nest-xcor random-location min-pxcor max-pxcor
    set nest-ycor random-location min-pycor max-pycor ]
end

to setup-globals
  set food-collected 0
  set energy-units 1
  set protein-units 1
  set maxNutritionalValue 0
  set energy-collected 0
  set protein-colleted-day 0
  set trail-patches 0

  set antsFTSeed-count 0
  set antsFTBug-count 0
  set antsFTDeadBug-count 0
  set antsFTHoneyDew-count 0

  set MemoryArray array:from-list
    [
     0  0.469879518  0.759036145  0.879518072  0.88  0.9375  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  0  0.3095  0.38  0.558255284  0.8145  0.8524  0.9204  0.913040429  0.9527  0.984  1  1  1  1  1  1  1  1  1  1  1  1  0  0.15942029  0.434782609  0.463768116  0.768115942  0.710144928  0.803030303  0.852459016  0.87037037  0.952380952  1  0.961538462  1  1  1  1  1  1  1  1  1  1  0  0.1849  0.2888  0.346276625  0.6193  0.7182  0.8176  0.843085381  0.8929  0.944  0.9638  0.9844  1  1  1  1  1  1  1  1  1  1  0  0.014492754  0.173913043  0.304347826  0.565217391  0.753623188  0.823529412  0.830769231  0.919354839  0.960784314  0.973684211  1  1  1  1  1  1  1  1  1  1  1  0  0  0.1274  0.261876361  0.4665  0.6048  0.7308  0.804676029  0.8451  0.912  0.9292  0.9694  0.99  1  1  1  1  1  1  1  1  1  0  0  0.083  0.235488639  0.406  0.5559  0.6934  0.790536967  0.8257  0.899  0.9134  0.9634  0.98  1  1  1  1  1  1  1  1  1  0  0  0.058  0.214789728  0.3561  0.5122  0.66  0.778490127  0.8093  0.888  0.8986  0.9584  0.97  1  1  1  1  1  1  1  1  1  0  0  0.0488  0.198047525  0.3168  0.4737  0.6306  0.768016533  0.7959  0.879  0.8848  0.9544  0.96  1  1  1  1  1  1  1  1  1  0  0  0.033333333  0.152542373  0.237288136  0.389830508  0.593220339  0.745762712  0.762711864  0.842105263  0.833333333  0.921568627  0.95  1  1  1  1  1  1  1  1  1  0  0  0.035  0.172473727  0.27  0.4123  0.5838  0.750495857  0.7781  0.867  0.8602  0.9494  0.95  1  1  1  1  1  1  1  1  1  0  0  0.036  0.162437625  0.2625  0.3894  0.5664  0.743023611  0.7737  0.864  0.8494  0.9484  0.95  1  1  1  1  1  1  1  1  1  0  0  0.037  0.153721828  0.2656  0.3717  0.553  0.736215526  0.7723  0.863  0.8396  0.9484  0.948  1  1  1  1  1  1  1  1  1  0  0  0.038  0.146069752  0.2793  0.3592  0.5436  0.729967851  0.7739  0.864  0.8308  0.9494  0.946  1  1  1  1  1  1  1  1  1  0  0.013157895  0.039473684  0.157894737  0.328947368  0.355263158  0.539473684  0.736842105  0.776315789  0.864864865  0.826086957  0.95  0.944444444  1  1  1  1  1  1  1  1  1
    ]
  ;; this are x & y locartion for each food patch Honeydews, Bugs & dead Bugs
  set lstHoneyDew
   [
      -25 15 -26 36 -25 46 -65 0 -45 -25 -38  -35 -77  -43 6 -37 0 -15 17 -2 31 -6 35 -32 23 -29 58 -6 49 -25 63 39 74 36 105 9
   ]
  set honeyDewLoc array:from-list lstHoneyDew
  set lstBugsLoc
   [
      -48 -10 -55 -10 -51 -10 -57 -10 -82 -11 -99 -16 -102 -16 -62 30 -57 26 -57 23 -82 13 -82 16 -82 19 -79 16 -85 19 -79 19 -101 60 -104 60 -107 60 -110 60 -10 10 -10 7 -7 10 -13 10  3 7 3 49 3 51 6 49 9 49 0 51
      -3 51 0 54 -3 54  0 71 0 73 3 73 -16 75 -14 78 -14 81 -11 78 -11 75 -13 75  -23 78 -23 81 -23 84 40 -7 37 -7 35 -7 47 2 50 2 53 2 84 28 87 29 87 26 89 26 107 46 110 46 113 46 111 48 111 43
   ]
  set BugsLoc array:from-list lstBugsLoc
   set lstDeadBugsLoc
   [
      -93 45 -96 45 -13 16 3 14 -18 65  -18 62 63 23 66 23 100 64
   ]
  set DeadBugsLoc array:from-list lstDeadBugsLoc
end

to setup-ants
   create-ants population
  [ set size   2         ;; easier to see
    set color  red       ;; red = not carrying food
    set state "waiting"
    set xcor nest-xcor
    set ycor nest-ycor
    set steps 0
    set loaded? false
    set fullness random max_fullness
    set memstrength 1
    set f-memory 0
    set leader false
    set bug-leader false
    set load-type 0
    if trace? [ pen-down ]
    set memory-waypoints ( list ( list nest-xcor nest-ycor ) )
    set memory-next 0
    set energy 50
    set f-type-memory 0
  ]
end

to setup-patches
  ask patches [
    ;; Initialize patches as not being food or nest
    set food? false
    set nest? false
    set food-scent 0
  ]
  ifelse fixed-food?
  [ fixed-patches ]
  [ random-patches ]
end

to random-patches
  spawn-food-sources 1 seeds 1
  spawn-food-sources 2 bugs 1
  spawn-food-sources 3 dead-bugs 1
  spawn-food-sources 4 honeydew 1
  ask patches [
    setup-nest nest-xcor nest-ycor ;; Place the nest at a random point
    recolor-patch ;; Color all the patches depending if they are food source or nest
  ]
end

to fixed-patches
   set nest-xcor -21
   set nest-ycor -12
   let numfood length lstHoneyDew ;; these are the corrdinates of food as they are x & y coordinates the list must be divided be 2 in order to find the location number
   locate-fix-food 2 BugsLoc (length lstBugsLoc) 2
   locate-fix-food 3 DeadBugsLoc (length lstDeadBugsLoc) 2
   locate-fix-food 4 honeyDewLoc (length lstHoneyDew) 3
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
  set pheromones-help-evaporation 13
end

;; Sets the number of food sources indicated by the food-sources slider
to spawn-food-sources [ftype number-of-sources probability]
  ;; Only spawn food sources with a given probability
  let random-draw random-float 1
  if random-draw < probability [
    repeat number-of-sources [
      ;; Get center for new patch
      let x-coord random-location min-pxcor max-pxcor
      let y-coord random-location min-pycor max-pycor
      let food-size ftype ;; In general the food size is the type
      if ftype = 3 [
        ;; Except for dead bugs that have the same size as live bugs
        set food-size 2
      ]
      set last-feedernumber (last-feedernumber + 1)
      ;; Get the patch for the center of the food source
      ask patch x-coord y-coord [
        ;; Find the patches around the center and set them as food
        spread-food ftype last-feedernumber x-coord y-coord food-size
      ]
    ]
  ]
end

to spread-food [ftype last-feed-num x-coord y-coord food-size]
  let nutriQuality 0
  ifelse ftype = 3
    [set nutriQuality one-of[ 20 40 60 ]
    print word "nutriQuality: " nutriQuality]
    [set nutriQuality ((random 10) + 1) * ftype]
  ask patches in-radius food-size [
    set food-type ftype
    set feedernumber last-feed-num
    set food? food? OR (distancexy x-coord y-coord) < food-size ;; This condition is required to make sources round, can be replaced with true
    set nutritionalQuality nutriQuality
    if maxNutritionalValue < nutritionalQuality [set maxNutritionalValue nutritionalQuality]
    ]
end

to locate-fix-food [ftype coordarray numfood food-size]
  let contador 0
  while [contador < numfood]
  [
    let x-coord array:item coordarray contador
    let y-coord array:item coordarray (contador + 1)
    set last-feedernumber (last-feedernumber + 1)
      ;; Get the patch for the center of the food source
      ask patch x-coord y-coord [
        ;; Find the patches around the center and set them as food
        spread-food ftype last-feedernumber x-coord y-coord food-size
      ]
    set contador contador + 2
  ]

end

;; @**********@ patch procedure @**********@ ;;
to recolor-patch
  ifelse nest?
  [ set pcolor violet ]
  [ifelse food? [
      if food-type = 1 [ set pcolor blue ] ;; seed
      if food-type = 2 [ set pcolor green ] ;; bug
      if food-type = 3 [ set pcolor brown ] ;; dead bugs
      if food-type = 4 [ set pcolor yellow ];; honeydew
      ;[
       ;set pcolor (ifelse-value
        ;nutritionalQuality = 20 [ yellow ]
        ;nutritionalQuality = 40 [ orange ]
        ;nutritionalQuality = 60 [ red ]
        ;[ black ]
      ;)
        ;;if nutritionalQuality = 20 [ set pcolor yellow ]
        ;;if nutritionalQuality = 40 [ set pcolor orange ]
        ;;if nutritionalQuality = 60 [ set pcolor red ]
      ;]
    ] [
      ;; If there is food-scent, show it
      set pcolor scale-color pink food-scent 0.1 20
      ;; If there is a trace of pheromone show it
      if chemical-return > 0.1 [
        set pcolor scale-color green chemical-return 0 1
      ]

    if pheromone-recruit > 0.1 [
        set pcolor scale-color brown pheromone-recruit 0.01 5
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
  ask ants  [
    if who >= ticks [ stop ] ;; delay initial departure
                             ;; works like an case statement so depending on the state the ant excecutes a particular behaviour
    if (state = "waiting" ) [hold]
    if (state = "searching" ) [search]
    if (state = "following" ) [follow-ant]
    if (state = "exploiting" ) [exploit]
    if (state = "exploit-bug" ) [exploiting-bug]
    if (state = "recruiting" ) [recruit]
    set energy energy - 0.2
    if energy < 0 [ set energy 0]  ;; this keeps the energy minimum value to be 0
  ]

  setup-pheromones
  diffuse-chemical
  diffuse-pheromones
  global-measures

  respawn-food

  ;; Add the food-scent
  ask patches with [food?] [
    set food-scent 20
  ]
  ;; And diffuse it
  diffuse food-scent 0.3
  tick

  if debug [
    stop
  ]
end

to global-measures
  let days-comparator  elapsed-days
  set elapsed-days floor (ticks / ticks-per-day)
  if days-comparator != elapsed-days ;; the time frame defined has change this estimates the amount collected during that frame
  [
    set food-collected-day precision food-collected 3
    set energy-collected-day precision energy-collected 3
    set protein-colleted-day precision protein-colleted 3
    set energy-avg precision (energy-collected-day / energy-units) 3
    set protein-avg precision (protein-colleted-day / protein-units) 3
    set trail-patches count patches with [ chemical-return > 0.5]
    set food-collected 0
    set energy-units 1
    set protein-units 1
    set energy-collected 0
    set protein-colleted 0

    let antsFTSeed precision (antsFTSeed-count / ticks-per-day) 3
    let antsFTBug precision (antsFTBug-count / ticks-per-day) 3
    let antsFTDeadbug precision (antsFTDeadbug-count / ticks-per-day) 3
    let antsFTHoneydew precision (antsFTHoneydew-count / ticks-per-day) 3
    set antsFTSeed-count 0
    set antsFTBug-count 0
    set antsFTDeadbug-count 0
    set antsFTHoneydew-count 0

    ;;let antsFTSeed count ants with [f-type-memory = 1]
    ;;let antsFTBug count ants with [f-type-memory = 2]
    ;;let antsFTDeadbug count ants with [f-type-memory = 3]
    ;;let antsFTHoneydew count ants with [f-type-memory = 4]
    let antsSearching count ants with [state = "searching"]
    let antsFollowing count ants with [state = "following"]
    let antsExploiting count ants with [state = "exploiting"]
    let antsExploit-bug count ants with [state = "exploit-bug"]
    let antsRecruiting count ants with [state = "recruiting"]
    let foodAvailable count patches with [food?]
    writeCSVrow filename  (list elapsed-days energy-collected-day protein-colleted-day food-collected-day energy-avg protein-avg trail-patches antsFTSeed antsFTBug antsFTDeadbug antsFTHoneydew antsSearching antsFollowing antsExploiting antsExploit-bug antsRecruiting foodAvailable)
  ]
end


to respawn-food
  spawn-food-sources 1 1 (seeds-spawn-probability / 100)
  spawn-food-sources 2 1 (bugs-spawn-probability / 100)
  spawn-food-sources 3 1 (dead-bugs-spawn-probability / 100)
  ;;evaluate-honeydew     ;; mechanism to cahnge honeydew location in order to validate memori efect over pheromone track
end

;; @**********@ patch procedure @**********@ ;;
to diffuse-chemical
  diffuse chemical-return ((diffusion pheromone-return)/ 100)
  ask patches [
    set chemical-return chemical-return * (100 - (evaporation pheromone-return)) / 100  ;; slowly evaporate chemical
    ;;set chemical-return chemical-return - evaporation pheromone-return ;;
    ;; We need to lower the general level of food-scent since we are adding more constantly
    set food-scent food-scent / 1.1
  ]
end

;; @**********@ patch procedure @**********@ ;;
to diffuse-pheromones
  diffuse pheromone-recruit ((pheromones-help-evaporation)/ 100)
  ask patches [
    set pheromone-recruit pheromone-recruit * (100 - (pheromones-help-evaporation)) / 100  ;; slowly evaporate chemical
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
  ifelse fullness <= 0  [
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
  ;; Food has been found and we are not trying to explore different sources, proceed to exploiting state
  if should-exploit? [
    set serendipity 0
    set energy energy + ((nutriQuality-memory / maxNutritionalValue) * 100)
    set state "exploiting"
    stop
  ]
  ;; We are at the nest, define a heading at random and step out of it
  ifelse nest? and steps = 0 [
    set steps 1
    set heading ( random 360 )
  ]
  [
    ;; when the ant remembers a location where it has found any food, it goes back to check if there is more unless it is trying to search for more sources
    ifelse serendipity = 0 AND f-memory != 0 [
      go-last-food-source
      ;; Stray the ant from the direct route to the food with a probability setting its serendipity to ignore trails
      if serendipity-on [try-stray-from-path]
    ]
    [
      ;; Otherwise follow a pheromone or just search at random
      ifelse (pheromone-recruit >= 0.05) and (pheromone-recruit < 2) [   ;; original mecanism of pheromone following
        join-chemical "pheromone"
      ][
        ifelse serendipity = 0 and (chemical-return >= 0.05) and (chemical-return < 2) [   ;; original mecanism of pheromone following
          join-chemical "chemical"
          ;; Stray the ant from the pheromone trail with a probability setting its serendipity to ignore trails
          if serendipity-on [try-stray-from-path]
        ] [
          wiggle
          decrease-serendipity
        ]
      ]
    ]
  ]
  move-forward
  set steps steps + 1
end

;; @**********@ agent method @**********@ ;;
to-report should-exploit?
  ;; Checks if the ant should transition to the exploit status
  ;; If we are not in a food location or perceive food scent, do not transition
  if not food? OR food-scent < 0.1 [ report False ]
  ;; If we are not looking for a new food source and arrive at our prefered food source, exploit!
  if serendipity <= 0 AND f-memory = feedernumber [ report True ]
  ;; we should also exploit if we find a new food source while looking for one
  if serendipity > 0 AND f-memory != feedernumber [ report True ]
  ;; If we get here this is the first food souce found by the ant, exploit!
  report True
end

;; @**********@ agent method @**********@ ;;
to record-food-location
  set f-memory feedernumber
  set f-type-memory food-type
  set nutriQuality-memory nutritionalQuality
  set memory-x xcor
  set memory-y ycor
end

;; @**********@ agent method @**********@ ;;
to decrease-serendipity
  ;; No serendipity, nothing to do here
  if serendipity = 0 [
    stop
  ]

  ;; Serendipity is 1, restore the previous waypoints
  if serendipity = 1 [
      set memory-waypoints memory-old-waypoints
      set memory-next memory-old-next
  ]

  ;; Decrease the serendipity
  set serendipity ( serendipity - 1 )
end

;; @**********@ agent method @**********@ ;;
to do-memstrength
     ;;when an ant first finds a full feeder it remembers it. If it comes there again it strengthens the memory by 1.
     ;;If it gets there but it's empty it starts scouting, but keeps its memory.
     ;;if it finds a different, productive feeder it sets newfeedermemstrength 1 higher.
     ;;The probability of memory switching is governed by the relationship between memstrength and newfeedermemstrength
     ;;The ants look up the probability in a lookup table called MemoryArray

  if memstrength > max-memory [set memstrength max-memory]  ;sets a maximum memory strength, as defined by a slider in the interface tab
  if newfeedermemstrength > 23 [set newfeedermemstrength 22]  ;prevents the newmemstrength to get above 22, as the look up table doesn't go higher than that
  if memstrength < 0 [set memstrength 0] ;prevents memory going lower than 0

  ifelse f-memory != 0               ; ifelse makes it so the ants learn the first feeder they find. If they don't have a memory, they can gain one.
  [
    ifelse f-memory = feedernumber
      [set memstrength memstrength + 1 ]
      [
      if nutriQuality-memory < nutritionalQuality  ;; if the ant rembers having food a more nutritive food source then he wont chance the preference, but if he founs a more nutritional one he well change his mind acording to the quality
        [set newfeedermemstrength newfeedermemstrength + floor(nutritionalQuality / 10 ) ]

        SwitchNow?
      ]
  ]

  [
     set memstrength 1
     add-waypoint xcor ycor
     set f-memory feedernumber
  ]

  if f-memory = 0 [
    set f-memory feedernumber
  ] ;allows naive or switching ants to memorise new feeders

end

to SwitchNow?
    if random-float 1 > SwitchChance memstrength newfeedermemstrength [switch-memory]           ;;;takes a random floating-point number between 0 and 1. If the number is bigger than the chance of memory switching, memory reset happens
End


to-report SwitchChance [CurrentMemStrength CurrentNewFeederMemStrength]
  report array:item MemoryArray (min list (((CurrentMemStrength - 1) * 22) + CurrentNewFeederMemStrength) (array:length MemoryArray - 1) )
end

to switch-memory       ;;;this  resets the ants memory: it now acts as if it is finding the new feeder it is on for the first time. In effect it switches its favoured feeder to this new feeder
  set memstrength 1
  set newfeedermemstrength 0
  set f-memory 0
  add-waypoint xcor ycor
  set memory-switches memory-switches + 1
end

	;; @**********@ agent method @**********@ ;;	
to follow-ant	
  ;; Regular following logic bellow
  set color yellow	
  if loaded?	
  [ set state "exploiting"	
    stop]	
  let nearby-leaders ants with [leader and (distance myself < 10)] ;; find nearby leaders	
  ifelse any? nearby-leaders [ ;; to avoid 'nobody'-error, check if there are any first	
    face min-one-of nearby-leaders [distance myself] ;; then face the one closest to myself	
    if not can-move? 1
    [ rt random 180 ]
    move-forward	
    set loss-count loss-count + 1	
    if(loss-count > 100)	[
      set state "searching"	
      set loss-count 0	
    ] ;; if i was following some one but i dont see him for a period i rather go searching again	
  ]	[
    ;; We don't have a leader nearby, switch back to searching
    set state "searching"	
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
      update-instant-measures
      ;; when the ant remembers a location where it has found any food, call others to show where the food source is	
      if mechanical-recruit
      [
         set leader true	
         ask ants in-radius 5 [ set state "following" ]	
      ]
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
      if memory-on [ do-memstrength ]
      set energy energy + ((nutriQuality-memory / maxNutritionalValue) * 100)
      if energy > 100  [set energy 100]
      record-food-location
      ifelse (food-type = 3) [
        ifelse chemical-recruit
        [
          set bug-size measure-bug          ;; see how many comrades would be needed to carry th bug
          set state "recruiting"
          stop
        ]
        [
          set loaded? true	
          set load-type food-type
          set food? false
        ]
      ][
        ;; The ant consumes the food unless it is honeydew
        if food-type != 4 [
          set food? false	
          set food-type 0
        ]
        set loaded? true	
        set load-type food-type
      ]
    ]	
    ;; Is there the scent of food? -> move towards higher concentrations of it	
      if food-scent > 0.1	
      [ uphill food-scent ]	
  ]	
end

to update-instant-measures
  set food-collected food-collected + 1 ;; if the ant is loaded ans arrives to the nest then he has collected a food unit

  ifelse f-type-memory = 3
  [set energy-collected energy-collected + nutriQuality-memory
   set energy-units energy-units + 1] ;; if the ant is loaded ans arrives to the nest then he has collected a food unit
  [set protein-colleted protein-colleted + nutriQuality-memory
   set protein-units protein-units + 1]

  set antsFTSeed-count ( antsFTSeed-count + count ants with [f-type-memory = 1] )
  set antsFTBug-count ( antsFTSeed-count + count ants with [f-type-memory = 2] )
  set antsFTDeadBug-count ( antsFTSeed-count + count ants with [f-type-memory = 3] )
  set antsFTHoneyDew-count ( antsFTSeed-count + count ants with [f-type-memory = 4] )
end

to-report measure-bug
  let inrad5 patches in-radius 5
  report count patches with [ member? self inrad5 and pcolor = brown ]
end

;; @**********@ agent method @**********@ ;;
to recruit
  let comrades count ants with [state = "recruiting"] in-radius 12
  ifelse (comrades >  (bug-size / 2))
  [
    ask ants with [state = "recruiting"] in-radius 10 [
      set state "exploit-bug"
      set loaded? true	
      set load-type food-type
    ]
    ifelse (distancexy memory-x memory-y) > 1
    [find-bug-source
    set bug-leader true]
    [set bug-leader true]
  ][
   set pheromone-recruit pheromone-recruit + 50
    recruit-circles
    move-forward
  ]
  stop
end

to exploiting-bug
  set color brown
   ifelse bug-leader [
    ask patches with [food? and food-type = 3] in-radius 10 [
      set food? false
      set food-type 0
    ]
    ask patches in-radius 2 [
      set food? true
      set food-type 3
    ]
    ifelse nest? [
      set bug-leader false
      ask patches with [food? and food-type = 3] in-radius 10 [
      set food? false
      set food-type 0
      set food-scent 0
      ]
      set loaded? false	
      set state "searching"
    ]
    [ return-to-nest ]
  ]
  [ return-to-nest
    if nest? [set state "searching"]
  ]
end

	;; @**********@ agent method @**********@ ;;	
to find-bug-source	
    facexy memory-x memory-y ;; if i remember where i found food I turn in food direction.	
    if not can-move? 1
    [ rt random 180 ]
end

;; @**********@ agent method @**********@ ;;
to join-chemical [kind]
  let scent-ahead chemical-scent-at-angle   0  kind
  let scent-right chemical-scent-at-angle  45  kind
  let scent-left  chemical-scent-at-angle -45  kind
  if (scent-right > scent-ahead) or (scent-left > scent-ahead)
  [ ifelse scent-right > scent-left
    [ rt 45 ]
    [ lt 45 ] ]
end

;; @**********@ patch procedure @**********@ ;;
to-report chemical-scent-at-angle [angle kind]
  let p patch-right-and-ahead angle 1
  if p = nobody [ report 0 ]
  if (kind = "pheromone")[
    report 0
    ;;report [pheromone-recruit] of p
  ]
  if (kind = "chemical")[
     report [chemical-return] of p
  ]
end

;; @**********@ patch procedure @**********@ ;;
to try-stray-from-path
  let random-draw random-float 1
  ;; Only stray if there is no serendipity and we are either at this ant selected memory source or pheromone trail
  if f-memory != 0 AND serendipity = 0 AND random-draw < stray-probability AND ( chemical-return > 0.1 OR f-memory = feedernumber ) [
    ;; Save the previous path
    set memory-old-waypoints memory-waypoints
    set memory-old-next memory-next
    ;; And generate a number of steps to be in the serendipity state
    set serendipity ((random random-serendipity ) + 30)
    ;; Add this point to our list of way points
    change-last-waypoint xcor ycor
  ]
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


to recruit-circles
  ifelse(loss-count < 100)
  [
    rt 15
    if not can-move? 1
    [ rt 180 ]
  ]
  [
    if(loss-count > 120)	
    [set state "searching"	
      set loss-count 0	
    ] ;; if i was following some one but i dont see him for a period i rather go searching again	
  ]
  set loss-count loss-count + 1	
end

;; @**********@ agent method @**********@ ;;
to return-to-nest
  ifelse return-nest-direct
  [
    ifelse serendipity-on[
      if load-type != 1 or load-type != 3 [ ;; if we are harvesting seeds or bug there is no need to leave a pheromene trail
        if deposit-pheromone
        ;;[set chemical-return chemical-return + ( 0.03 * load-type)]
        [ set chemical-return chemical-return + (0.002 * nutriQuality-memory)] ;; this cause that the amount of pheromone change acording to the nutitional value the ant is carring
        set leader false
      ]
      ;; this is to say that the ant has memory of nest location so it heads toward the next to return
      ;; this method should be canged for a path integration method
      if (distancexy waypoint-x waypoint-y) < 3.0 [
        ;; We arrieved at the waypoint, go to the next one if we not on the nest
        set-previous-waypoint
      ]
      facexy waypoint-x waypoint-y
      if not can-move? 1
      [ rt 180 ]
    ]
    [
      if load-type != 1 or load-type != 3 [ ;; if we are harvesting seeds or bug there is no need to leave a pheromene trail
        if deposit-pheromone
        ;;[set chemical-return chemical-return + ( 0.03 * load-type)]
        [ set chemical-return chemical-return + ( 0.002 * nutriQuality-memory)] ;; this cause that the amount of pheromone change acording to the nutitional value the ant is carring
        set leader false
      ]
      facexy nest-xcor nest-ycor
     if not can-move? 1
     [ rt 180 ]
    ]
  ]
  [wiggle]
  move-forward
end

;; @**********@ agent method @**********@ ;;	
to go-last-food-source	
  ifelse serendipity-on [
    ifelse (distancexy waypoint-x waypoint-y) > 1	
    [

      facexy waypoint-x waypoint-y ;; if i remember where i found food I turn in food direction.	
      if not can-move? 1
      [ rt random 180 ]

    ]	
    [	
      set-next-waypoint
      ;; switch-memory
    ]	
  ]

  [
    ifelse (distancexy memory-x memory-y) > 1	
     [
      facexy memory-x memory-y
      if not can-move? 1
      [ rt random 180 ]
    ]
    [
      set leader false
      set f-memory 0
      ask ants in-radius 10 [ set state "searching" ]	
    ]

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

;; @**********@ Movement helper methods @**********@ ;;	

;; @**********@ agent method @**********@ ;;	
to-report waypoint-x
  report item 0 waypoint
end

;; @**********@ agent method @**********@ ;;	
to-report waypoint-y
  report item 1 waypoint
end

;; @**********@ agent method @**********@ ;;	
to-report waypoint
  report item memory-next memory-waypoints
end

;; @**********@ agent method @**********@ ;;	
to set-next-waypoint
  if memory-next < ( length memory-waypoints - 1 ) [
     set memory-next memory-next + 1
  ]
end

;; @**********@ agent method @**********@ ;;	
to set-previous-waypoint
  if memory-next > 0 [
     set memory-next memory-next - 1
  ]
end

;; @**********@ agent method @**********@ ;;	
to add-waypoint [x y]
  ;; Add the waypoiunt to the list
  set memory-waypoints lput ( list x y )  memory-waypoints
  ;; And increase the next return target
  set memory-next memory-next + 1
end

;; @**********@ agent method @**********@ ;;	
to change-last-waypoint [x y]
  ;; Replace the last waypoint with the new values
  let last-index ( length memory-waypoints ) - 1
  set memory-waypoints replace-item last-index memory-waypoints ( list x y )
end

;; @**********@ agent method @**********@ ;;	
to move-forward
  fd 1
end
@#$#@#$#@
GRAPHICS-WINDOW
383
15
1395
828
-1
-1
4.0
1
10
1
1
1
0
0
0
1
-125
125
-100
100
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
100
100.0
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
192
133
go
set debug False\ngo
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
24
147
196
180
ran-seed
ran-seed
0
10000
6370.0
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
35.0
5
1
NIL
HORIZONTAL

SWITCH
28
569
131
602
trace?
trace?
1
1
-1000

SLIDER
26
483
198
516
max_fullness
max_fullness
0
200
0.0
5
1
NIL
HORIZONTAL

SLIDER
1426
54
1598
87
seeds
seeds
0
200
16.0
1
1
NIL
HORIZONTAL

SLIDER
1428
103
1600
136
bugs
bugs
0
100
12.0
1
1
NIL
HORIZONTAL

SLIDER
1429
153
1601
186
dead-bugs
dead-bugs
0
100
15.0
1
1
NIL
HORIZONTAL

SLIDER
1430
201
1602
234
honeydew
honeydew
0
20
8.0
1
1
NIL
HORIZONTAL

PLOT
28
610
306
830
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
"waiting" 1.0 0 -16777216 true "" "plotxy ticks count ants with [state = \"waiting\"]"
"searching" 1.0 0 -2674135 true "" "plotxy ticks count ants with [state = \"searching\"]"
"following" 1.0 0 -1184463 true "" "plotxy ticks count ants with [state = \"following\"]"
"exploiting" 1.0 0 -13840069 true "" "plotxy ticks count ants with [state = \"exploiting\"]"
"recruiting" 1.0 0 -5207188 true "" "plotxy ticks count ants with [state = \"recruiting\" or state = \"exploit-bug\"]"

TEXTBOX
1434
27
1584
45
Food sources
11
0.0
1

TEXTBOX
1429
260
1579
278
Pheromones
11
0.0
1

INPUTBOX
1426
290
1701
350
pheromone-diffusion-rates
[ 2 0 100 ]
1
0
String

INPUTBOX
1426
362
1697
422
pheromone-evaporation-rates
[ 5 0.01 20 ]
1
0
String

CHOOSER
1427
437
1565
482
pheromone-return
pheromone-return
1 2 3
1

SLIDER
1629
55
1841
88
seeds-spawn-probability
seeds-spawn-probability
0
10
0.0
0.1
1
%
HORIZONTAL

SLIDER
1631
101
1837
134
bugs-spawn-probability
bugs-spawn-probability
0
10
0.0
0.1
1
%
HORIZONTAL

SLIDER
1632
152
1859
185
dead-bugs-spawn-probability
dead-bugs-spawn-probability
0
10
0.0
0.1
1
%
HORIZONTAL

SLIDER
25
197
197
230
stray-probability
stray-probability
0
5
5.0
0.01
1
%
HORIZONTAL

TEXTBOX
1429
491
1579
509
Memoria\n
11
0.0
1

SLIDER
1426
514
1598
547
max-memory
max-memory
0
20
3.0
1
1
NIL
HORIZONTAL

SWITCH
139
570
243
603
fixed-food?
fixed-food?
1
1
-1000

SLIDER
26
525
198
558
random-serendipity
random-serendipity
0
100
65.0
1
1
NIL
HORIZONTAL

SWITCH
1426
670
1579
703
deposit-pheromone
deposit-pheromone
0
1
-1000

SWITCH
1594
671
1721
704
memory-on
memory-on
0
1
-1000

SWITCH
1424
714
1580
747
mechanical-recruit
mechanical-recruit
0
1
-1000

SWITCH
1594
714
1723
747
chemical-recruit
chemical-recruit
0
1
-1000

SWITCH
1595
757
1725
790
serendipity-on
serendipity-on
0
1
-1000

SWITCH
1424
757
1582
790
return-nest-direct
return-nest-direct
0
1
-1000

TEXTBOX
1428
647
1578
665
Mechanism Activation
11
0.0
1

MONITOR
1626
509
1735
554
memory-switches
memory-switches
17
1
11

PLOT
24
286
224
436
colony enegy
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
"energy" 1.0 0 -955883 true "plotxy ticks / 10 sum [energy] of Ants" "plotxy ticks / 30 sum [energy] of Ants"
"collectedfood" 1.0 0 -13840069 true "" "plotxy ticks / 30 food-collected * 300"
"available-food" 1.0 0 -5825686 true "" "plotxy ticks / 30 count (patches with [food?]) * 20"
"collectedenergy" 1.0 0 -13791810 true "" "plotxy ticks / 30 energy-collected * 20"
"collectedprotein" 1.0 0 -15637942 true "" "plotxy ticks / 30 protein-colleted * 20"

SLIDER
1427
587
1599
620
ticks-per-day
ticks-per-day
0
1000
150.0
1
1
NIL
HORIZONTAL

TEXTBOX
1432
562
1582
580
day length in ticks
11
0.0
1

MONITOR
1727
579
1837
624
amount-collected
food-collected-day
17
1
11

MONITOR
1621
580
1708
625
elapsed-days
elapsed-days
17
1
11

MONITOR
1745
511
1823
556
energy-avg
energy-avg
3
1
11

SLIDER
25
441
263
474
ant-speed
ant-speed
0.01
0.1
0.07
0.01
1
m/s
HORIZONTAL

PLOT
231
286
431
436
ants by food type
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
"pen-1" 1.0 2 -2674135 true "" "plotxy ticks count ants with [f-type-memory = 1]"
"pen-2" 1.0 2 -13840069 true "" "plotxy ticks count ants with [f-type-memory = 2]"
"pen-3" 1.0 2 -6459832 true "" "plotxy ticks count ants with [f-type-memory = 3]"
"pen-4" 1.0 2 -1184463 true "" "plotxy ticks count ants with [f-type-memory = 4]"

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
