! Copyright (C) 2021 Kevin Cope.
! See http://factorcode.org/license.txt for BSD license.
USING: arrays assocs columns graphs hashtables kernel math
       math.functions math.matrices math.vectors sequences
       sequences.windowed sets random ;
IN: verlet

SYMBOL: gravity
SYMBOL: spring
SYMBOL: wind
gravity [ 1200 ] initialize
spring [ 0.5 ] initialize
wind [ 0.0 ] initialize

CONSTANT: stable-spacing 15.0

! only 2 dimensions for now
! each node will be a 2x2 matrix, row 1:xy-position, row 2:xy-previous (for calculating derivative/velocity)
: <verlet-node> ( x y -- n )
    2array dup 2array ;

: <pinned-node> ( x y -- n )
    2array { f } 2array ;

: unpack-node-slice ( (n) -- n )
    first ;

: pinned-node? ( n -- ? )
    unpack-node-slice second first ;

: unless-pinned ( ..n quot: ( ..n -- ) -- ..n )
    [ dup pinned-node? ] dip [ drop ] if ; inline

: node-axis-position-distance ( n1 n2 -- seq )
    [ unpack-node-slice first ] bi@ v- ;
    
: node-position-difference ( seq -- dist )
    [ sq ] map sum sqrt ;

: node-%distance-from-stable ( dist spacing -- %dist )
    over - swap / ;

: spring-distance ( distance-seq %dist spring -- node-change-seq )
    * '[ _ * ] map ;
    
: verlet-distances ( n1 n2 -- axis-dist-seq dist )
    node-axis-position-distance dup node-position-difference ;

! only update positions, velocities are updated by gravity constraint
: resolve-spring ( n1 n2 spring-force -- n1-newpos n2-newpos )
    [ '[ _ [ unpack-node-slice first ] dip v+ ] ] keep
    '[ _ [ unpack-node-slice first ] dip v- ] bi* ;

: (spring-force) ( spacing -- quot: ( n1 n2 -- n1-newpos n2-newpos ) )
    '[ 2dup 2dup verlet-distances _ node-%distance-from-stable spring get spring-distance resolve-spring ] ; 

! internode edge
: spring-force ( spacing --  quot: ( n1 n2 -- ) )
    ! bi@ curries the new positions into the +/- thing, bi* applies the change to the og positions
    (spring-force) [ [ '[ [ _ swap unpack-node-slice set-first ] unless-pinned ] ] bi@ bi* ] compose ; 

: (inertia-force) ( n1 -- )
    unpack-node-slice dup [ second 2 v*n ] [ first ] bi v- swap set-first ;

! self edge
: inertia-force ( n1 -- )
    [ dup unpack-node-slice reverse! drop (inertia-force) ] unless-pinned ;

! self edge
: gravity-force ( n1 -- )
    unpack-node-slice first 1 swap [ gravity get 0.5 * 0.015 sq * + ] change-nth ;

: (coattails-noise) ( n1 -- )
    unpack-node-slice first 0 swap [ wind get dup 3 * normal-random-float over over > [ + ] [ drop 0 + ] if ] change-nth ; 

: connect-cloth-self-connectors ( n1 graph -- )
    '[ 1array 0 head-slice* { [ inertia-force ] [ (coattails-noise) ] [ gravity-force ] } _ add-vertex ] each ;

: <cloth-matrix> ( height width -- nseq )
    ! only pins top two corners...
    over '[ 2dup 2dup [ [ _ 1 - = ] [ zero? ] bi* and ] [ [ zero? ] bi@ and ] 2bi* or [ [ 5.0 + 15.0 * ] bi@ <pinned-node> ] [ [ 5.0 + 15.0 * ] bi@ <verlet-node> ] if ] <matrix-by-indices> ;

: <cloth-graph> ( height width -- graph )
    * <hashtable> ;

: (cloth-intrinsics) ( nrow graph -- )
    [ swap connect-cloth-self-connectors ] with each ;

: default-spring ( winseq -- n1 quot: ( n2 -- ) )
    1 cut-slice stable-spacing spring-force curry ;

:: connect-row-succ-nodes ( graph nseq -- )
    nseq 2 <windowed-sequence> rest-slice [ default-spring 1array graph add-vertex ] each ;

:: (cloth-pinned-corners) ( nseq graph -- )
    nseq 1 cut-slice
    [ unpack-node-slice 1 head-slice* rest-slice graph connect-cloth-self-connectors ]
    [ graph swap (cloth-intrinsics) ]
    bi* ;


: cloth-coattails-noise ( nseq graph -- )
    '[ B 1array 0 head-slice* { (coattails-noise) } _ add-vertex ] [ B 1 tail-slice* first B ] dip each ; 

:: <cloth> ( width height -- graph nseq )
    height width [ <cloth-graph> ] [ <cloth-matrix> ] 2bi :> node-matrix :> node-graph
    node-matrix <flipped> node-graph (cloth-pinned-corners)
    node-graph node-matrix [ connect-row-succ-nodes ] with each
    node-graph node-matrix <flipped> [ connect-row-succ-nodes ] with each
    ! node-matrix node-graph cloth-coattails-noise
    node-graph node-matrix
    ;

: resolve-node-graph ( graph -- )
    dup keys [ [ swap at ] keep swap members [ swap call( n1 -- ) ] with each ] with each ;
