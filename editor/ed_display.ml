
open Format
open Ed_hyper
open Ed_graph

let debug = ref false


(* Original window size *)
let (w,h)= (600.,600.)


(* differents colors deffinitions *)
let color_intern_edge = "SlateGrey"
let color_successor_edge ="black"
let color_vertex = "grey"

let color_selected_intern_edge = "DarkSlateGray2" 
let color_selected_successor_edge =  "DarkSlateGray2"
let color_selected_vertex =  "DarkSlateGray2"

let color_focused_intern_edge = "blue" 
let color_focused_successor_edge =  "blue" 
let color_focused_vertex =  "blue" 

let color_selected_focused_intern_edge =  "IndianRed" 
let color_selected_focused_vertex ="IndianRed"
let color_selected_focused_successor_edge =  "IndianRed" 


 
(* two tables for two types of edge :
   successor_edges = edges with successor of root
   intern_edges = edges between  successors of root *)
let successor_edges = H2.create 97
let intern_edges = H2.create 97


(* table of all nodes *)
let nodes = H.create 97



(* GTK to hyperbolic coordinates *)
let to_turtle(x,y)=
  let zx,zy as r = ((float x*.(2./.w) -. 1.),(1. -. float y *.(2./.h))) in
  let zn = sqrt(zx*.zx +. zy*.zy) in
  if zn > rlimit then
    (rlimit*.zx/.zn, rlimit*.zy/.zn)
  else
    r

(* Hyperbolic to GTK coordinates *)
let from_turtle (x,y) =
  let xzoom = (w/.2.)
  and yzoom = (h/.2.) in
  (truncate (x*.xzoom +. xzoom), truncate(yzoom -. y*.yzoom))


(* the middle of the screen used when init a graoh drawing *)
let start_point = to_turtle (truncate(w/.2.), truncate(h/.2.))

(* origine is a reference to the start point drawing for the graph in GTK coordinates *)
let origine = ref start_point

(* Current point in Hyperbolic view with an initialization in center of hyperbolic circle *)
let current_point = ref (0,0)

(* Change hyperbolic current point *)
let moveto_gtk x y = current_point := (x,y)

(* Change hyperbolic current point with turtle coordinates *)
let tmoveto_gtk turtle = 
  let (x,y)= from_turtle turtle.pos in
  moveto_gtk x y

(* Create a turtle with origine's coordinates *)
let make_turtle_origine () = 
  let (x,y) = let (x,y) = !origine in (truncate x, truncate y) in  
  moveto_gtk  x y;
  make_turtle !origine 0.0

(* Append turtle coordinates to line, set current point and return the "new" line *)
let tlineto_gtk turtle line =
  tmoveto_gtk turtle; 
  let (x,y) = !current_point in
  List.append line [(float x); (float y) ] 



(* Set line points for a distance with a number of steps, 
   set current point to last line's point, by side-effect of tlineto_gtk,
   and return the final turtle *)
let set_successor_edge turtle distance steps line =
  let d = distance /. (float steps) in
  let rec list_points turtle liste = function
    | 0 -> (turtle,liste)
    | n ->let turt = advance turtle d in
      list_points turt (tlineto_gtk turt liste) (n-1)
  in
  let start = 
    let (x,y) = from_turtle turtle.pos in [(float x); (float y)] in 
  let turtle,lpoints = list_points turtle start steps in
   let points = Array.of_list lpoints in
  line#set [`POINTS points]


(* Set Bpath between turtles tv and tw where line is a gtk widget *) 
let set_intern_edge tv tw bpath line =
  let (x,y) = let (x ,y ) = from_turtle tv.pos in ((float_of_int x),(float_of_int y)) in
  let (x',y') = let (x',y') = from_turtle tw.pos in ((float_of_int x'),(float_of_int y')) in
  let rate = 1.95 in
  GnomeCanvas.PathDef.reset bpath;
  GnomeCanvas.PathDef.moveto bpath x y ;
  GnomeCanvas.PathDef.curveto bpath ((x+. x')/.rate) ((y +. y')/.rate) 
    ((x  +.x')/.rate) ((y +. y')/.rate)
    x' y';
  line#set [`BPATH bpath]
  


(* Set ellipse coordinate to turtle's and set current point too *)
let tdraw_string_gtk v turtle  =
  let node,ellipse,texte = H.find nodes v in  
  tmoveto_gtk turtle;  
  let factor = (shrink_factor ((G.V.label v).turtle.pos)) in
  let factor = if factor < 0.5 then 0.5 else factor in
  let w = factor*. 12. in
  texte#set [`SIZE_POINTS w];
  let w = texte#text_width in 
  let h = texte#text_height in
  ellipse#set [ `X1  (-.( w+.8.)/.2.); `X2 ((w+.8.)/.2.);
		`Y1  (-.( h+.6.)/.2.); `Y2 ((h+.6.)/.2.)];
  let (x,y) = !current_point in
  node#move ~x:(float x) ~y:(float y);
  node#set  [`X (float x); `Y (float y)];
  node
    
let add_node canvas v =
  let s = string_of_label v in
  let node_group = GnoCanvas.group ~x:0.0 ~y:0.0 canvas in
  let ellipse = GnoCanvas.ellipse 
    ~props:[ `FILL_COLOR "grey" ; `OUTLINE_COLOR "black" ; 
	     `WIDTH_PIXELS 0 ] node_group  
  in
  let texte = GnoCanvas.text ~props:[`X 0.0; `Y 0.0 ; `TEXT s;  
				     `FILL_COLOR "black"] node_group
  in
  node_group#hide();
  H.add nodes v (node_group,ellipse,texte)

let init_nodes canvas =
  H.clear nodes;
  G.iter_vertex (add_node canvas) !graph






(* Color functions*)
(* let color_change_intern_edge color node = 
   G.iter_succ (fun w -> 
   try
   let _,n = H2.find intern_edges (node,w) in 
   n#set [`OUTLINE_COLOR color] 
   with Not_found -> 
   try 
   let _,n = H2.find intern_edges (w,node) in 
   n#set [`OUTLINE_COLOR color] 
   with Not_found -> () 
   )
   !graph node


   let color_change_successor_edge color node = 
   G.iter_succ
   (fun w ->
   try
   let n = H2.find successor_edges (node,w) in
   n#set [`FILL_COLOR color]
   with Not_found ->
   try
   let n = H2.find successor_edges (w,node) in
   n#set [`FILL_COLOR color]
   with Not_found ->
   ()
   )
   !graph node
   
   let color_change_no_event (node,item) =
   color_change_all_edge node color_intern_edge color_successor_edge;
   color_change_vertex item color_vertex

   let color_change_focused (node,item) =
   color_change_all_edge node color_focused_intern_edge color_focused_successor_edge;
   color_change_vertex item color_focused_vertex

   let color_change_selected (node,item) =
   color_change_all_edge node color_selected_intern_edge color_selected_successor_edge;
   color_change_vertex item color_selected_vertex
*)


(* change color for all edge connected to a node 
let color_change_all_edge node c_intern c_succ =
  color_change_intern_edge c_intern node ;
  color_change_successor_edge c_succ node*)

(* change color for a vertex *)
let color_change_vertex item color =
  item#set [ `FILL_COLOR color ; ]

(* change color for a successor edge *)
let color_change_intern_edge (line:GnoCanvas.bpath) color = 
  line#set [`OUTLINE_COLOR color]

(* change color for an intern edge *)
let color_change_successor_edge (line:GnoCanvas.line) color = 
  line#set [`FILL_COLOR color]





(* draws but don't show intern edges, and return a couple bpath (gtk_object), and line (gtw_widget)*)
let draw_intern_edge vw edge tv tw canvas =
  let bpath,line = 
    try
      let _,line as pl = H2.find intern_edges vw in
      pl
    with Not_found ->
      let bpath = GnomeCanvas.PathDef.new_path () in
      let line = GnoCanvas.bpath canvas
	~props:[ `BPATH bpath ; `WIDTH_PIXELS 2 ] 
      in
      line#lower_to_bottom ();
      H2.add intern_edges vw (bpath,line);
      let v,w  =  vw in
      if (is_selected w) || (is_selected v)  
      then edge.edge_mode <-  Selected;
      bpath,line
  in
  set_intern_edge tv tw bpath line;
  bpath,line
 

    
    
let draw_successor_edge vw edge canvas =
  let line =
    try
      H2.find successor_edges vw
    with Not_found ->
      let line = GnoCanvas.line canvas ~props:[ `FILL_COLOR color_successor_edge ;
						`WIDTH_PIXELS 2; `SMOOTH true] 
      in
      line#lower_to_bottom ();
      H2.add successor_edges vw line;	 
      let v,w  =  vw in
      if (is_selected w) || (is_selected v)  
      then edge.edge_mode <-  Selected;
      line
  in
  set_successor_edge edge.edge_turtle edge.edge_distance edge.edge_steps  line;
  line







(* set origine to new mouse position and return associated turtle *)
let motion_turtle item ev =
  let bounds = item#parent#get_bounds in
  let z1 = to_turtle(truncate((bounds.(0)+. bounds.(2))/.2.),
		    truncate((bounds.(1)+. bounds.(3))/.2.)) in
  let z2 = to_turtle (truncate (GdkEvent.Motion.x ev),
		     truncate (GdkEvent.Motion.y ev)) in
  let (x,y) = drag_origin !origine z1 z2 in
  origine := (x,y);
  make_turtle !origine 0.0


let hide_intern_edge vw =
  try let _,line = H2.find intern_edges vw in line#hide () with Not_found -> ()

let hide_succesor_edge vw =
  try let line = H2.find successor_edges vw in line#hide () with Not_found -> ()

(*
let refresh_vertex_edges vertex canvas=
(* vertex *)
let vertex_info = G.V.label vertex in
begin
  let _,item,_=H.find nodes vertex in
  match vertex_info.vertex_mode with
    | Normal -> color_change_vertex item color_vertex;
    | Selected -> color_change_vertex item color_selected_vertex;
    | Focused ->  color_change_vertex item color_focused_vertex;
    | Selected_Focused -> color_change_vertex item color_selected_focused_vertex;
end;
(*  edges *)           
G.iter_succ_e
  (fun e ->
     let edge = G.E.label e in
     let v = G.E.src e in
     let w = G.E.dst e in
     let vw = (v,w) in
         if edge.visited 
     then 
       (* successor edge *)
       begin
	 let line = draw_successor_edge vw edge canvas
	 in
	 begin
	     match edge.edge_mode with
	       | Normal -> color_change_successor_edge line color_successor_edge;
	       | Selected -> color_change_successor_edge line color_selected_successor_edge;
	       | Focused ->  color_change_successor_edge line color_focused_successor_edge;
	       | Selected_Focused -> color_change_successor_edge line color_selected_focused_successor_edge;
	   end;
	 line#show ();
	 hide_intern_edge vw
       end 
     else 
       (* intern edges *)
       begin
	 hide_succesor_edge vw;
	   let labv = G.V.label v in
	   let labw = G.V.label w in
	   let turv = labv.turtle in
	   let turw = labw.turtle in
	   if labv.visible = Visible 
	     && labw.visible = Visible 
	     && v!=w
	   then begin
	     let _,line = draw_intern_edge vw edge turv turw canvas in
	     begin
	       match edge.edge_mode with
		 | Normal -> color_change_intern_edge line color_intern_edge;
		 | Selected -> color_change_intern_edge line color_selected_intern_edge;
		 | Focused ->  color_change_intern_edge line color_focused_intern_edge;
		 | Selected_Focused -> color_change_intern_edge line color_selected_focused_intern_edge;
	     end;
	     line#show()
	   end else
	     hide_intern_edge vw
	 end) 
    !graph vertex
  
*)


(* graph drawing *)
let draw_graph root canvas  =
  (* vertexes *)
  G.iter_vertex
    (fun v -> 
       let ( l : node_info) = G.V.label v in
       if l.visible = Visible then 
	 begin
	   let node = tdraw_string_gtk v l.turtle in 
	   node#raise_to_top();
	   node#show();
	   let _,item,_=H.find nodes v in
	   match l.vertex_mode with
	     | Normal -> color_change_vertex item color_vertex;
	     | Selected -> color_change_vertex item color_selected_vertex;
	     | Focused ->  color_change_vertex item color_focused_vertex;
	     | Selected_Focused -> color_change_vertex item color_selected_focused_vertex;
	 end
       else
	 let node,_,_= H.find nodes v in
	 node#hide()
    )
    !graph;

  (*  edges *)           
  G.iter_edges_e
    (fun e ->
       let edge = G.E.label e in
       let v = G.E.src e in
       let w = G.E.dst e in
       let vw = (v,w) in
       if edge.visited 
       then 
	 (* successor edge *)
	 begin
	   let line = draw_successor_edge vw edge canvas
	   in
	   begin
	     match edge.edge_mode with
	       | Normal -> color_change_successor_edge line color_successor_edge;
	       | Selected -> color_change_successor_edge line color_selected_successor_edge;
	       | Focused ->  color_change_successor_edge line color_focused_successor_edge;
	       | Selected_Focused -> color_change_successor_edge line color_selected_focused_successor_edge;
	   end;
	   line#show ();
	   hide_intern_edge vw
	 end 
       else 
	 (* intern edges *)
	 begin
	   hide_succesor_edge vw;
	   let labv = G.V.label v in
	   let labw = G.V.label w in
	   let turv = labv.turtle in
	   let turw = labw.turtle in
	   if labv.visible = Visible 
	     && labw.visible = Visible 
	     && v!=w
	   then begin
	     let _,line = draw_intern_edge vw edge turv turw canvas in
	     begin
	       match edge.edge_mode with
		 | Normal -> color_change_intern_edge line color_intern_edge;
		 | Selected -> color_change_intern_edge line color_selected_intern_edge;
		 | Focused ->  color_change_intern_edge line color_focused_intern_edge;
		 | Selected_Focused -> color_change_intern_edge line color_selected_focused_intern_edge;
	     end;
	     line#show()
	   end else
	     hide_intern_edge vw
	 end) 
    !graph
    



let reset_display canvas =
  init_nodes canvas
