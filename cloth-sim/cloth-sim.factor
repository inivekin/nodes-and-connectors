USING: accessors calendar kernel literals math.trig sequences threads
       models opengl opengl.demo-support opengl.gl
       ui ui.gadgets ui.gadgets.borders ui.gadgets.labels ui.gadgets.packs verlet ;
QUALIFIED-WITH: models.range mr
IN: cloth-sim

TUPLE: cloth-gadget < gadget paused nodes connectors constraints ;

: <cloth-gadget> ( -- gadget )
    cloth-gadget new
        t >>clipped?
        ${ 480 480 } >>pref-dim
        15 10 <cloth> [ >>connectors ] [ >>nodes ] bi* 
        H{ { gravity 1200 } { spring 0.5 } { wind 0.0 } } >>constraints ;

M: cloth-gadget ungraft*
    t >>paused drop ;

: vec>deg ( vec -- deg )
    first2 rect> arg rad>deg ; inline

: draw-node ( node -- )
    dup
    first [
        second dup first [ vec>deg 0 0 1 glRotated ] [ drop ] if
        GL_POLYGON [
            -10.0 10.0 glVertex2f
            -10.0 -10.0 glVertex2f
            10.0 -10.0 glVertex2f
            10.0 10.0 glVertex2f
        ] do-state
    ] with-translation ;

: draw-nodes ( nodes -- )
    0.8 0.8 0.8 0.5 glColor4f
    [ draw-node ] each ;

M: cloth-gadget draw-gadget* ( cloth-gadget -- )
    nodes>> concat draw-nodes ;
    

: iterate-system ( cloth-gadget -- )
    [ constraints>> ] [ connectors>> ] bi '[ _ resolve-node-graph ] with-variables ;

:: start-cloth-thread ( gadget -- )
    [
        [ gadget paused>> ]
        [
            3 [ gadget iterate-system ] times
            gadget relayout-1
            15 milliseconds sleep
        ] until
    ] in-thread ;

<PRIVATE
: find-cloth-gadget ( gadget -- cloth-gadget )
    dup cloth-gadget? [ children>> [ cloth-gadget? ] find  nip ] unless ;
PRIVATE>

: com-pause ( cloth-gadget -- )
    find-cloth-gadget
    dup paused>> not [ >>paused ] keep
    [ drop ] [ start-cloth-thread ] if ;

TUPLE: cloth-frame < pack ;

! TODO(kevinc) genericise
: set-constraint ( n cloth-gadget var -- )
    '[ constraints>> [  _ swap set-at ] keep ] keep constraints<< ;

TUPLE: range-observer quot ;

M: range-observer model-changed
    [ range-value ] dip quot>> call( value -- ) ;

:: simulation-panel ( cloth-gadget -- gadget )
    <pile>
    "pause" [ drop cloth-gadget com-pause ]
    <button> add-gadget
    
    2 3 <frame>

    "gravity" <label> { 0 0 } grid-add
    cloth-gadget constraints>> gravity swap at 0 -3600 3600 200 mr:<range>
    dup [ cloth-gadget gravity set-constraint ]
    range-observer boa swap add-connection
    horizontal <slider> { 1 0 } grid-add

    "spring" <label> { 0 1 } grid-add
    cloth-gadget constraints>> spring swap at 0 0.01 0.6 0.05 mr:<range>
    dup [ cloth-gadget spring set-constraint ]
    range-observer boa swap add-connection
    horizontal <slider> { 1 1 } grid-add

    "wind" <label> { 0 2 } grid-add
    cloth-gadget constraints>> wind swap at 0 0.0 0.7 0.1 mr:<range>
    dup [ cloth-gadget wind set-constraint ]
    range-observer boa swap add-connection
    horizontal <slider> { 1 2 } grid-add

    { 5 5 } <border>

    "constraints" COLOR: black <framed-labeled-gadget>
    add-gadget
    ;

:: <cloth-frame> ( -- cloth-frame )
    cloth-frame new horizontal >>orientation
    <cloth-gadget> :> cloth-gadget
    cloth-gadget [ start-cloth-thread ] keep
    white-interior 
    add-gadget

    cloth-gadget simulation-panel
    white-interior
    add-gadget

    <pile> { 5 5 } >>gap 1.0 >>fill

    { 5 5 } <border> white-interior add-gadget ;

MAIN-WINDOW: cloth-sim  { { title "Cloth-sim" } }
     <cloth-frame> >>gadgets ;
