[@@@ocaml.warning "+a-4-30-40-41-42"]

(** The implementation below is based on the following article:
    A Simple, Fast Dominance Algorithm
    Keith D. Cooper, Timothy J. Harvey, and Ken Kennedy *)

module List = ListLabels

let fatal = Misc.fatal_errorf

(* CR-soon xclerc for xclerc: switch back to `false`. *)
let debug = true

type doms = Label.t Label.Tbl.t

type dominators = Label.Set.t Label.Map.t

type dominance_frontiers = Label.Set.t Label.Tbl.t

type dominator_tree =
  { label : Label.t;
    children : dominator_tree list
  }

type t =
  { doms : doms;
    dominators : dominators;
    dominance_frontiers : dominance_frontiers;
    dominator_tree : dominator_tree
  }

let rec is_dominating (doms : doms) left right =
  if Label.equal left right
  then true
  else
    let parent = Label.Tbl.find doms right in
    if Label.equal right parent then false else is_dominating doms left parent

let is_strictly_dominating (doms : doms) left right =
  (not (Label.equal left right)) && is_dominating doms left right

let invariant_doms : Cfg.t -> doms -> unit =
 fun cfg doms ->
  (* Check that `doms` has the same keys as the CFG. *)
  if Label.Tbl.length cfg.blocks <> Label.Tbl.length doms
  then fatal "Cfg_dominators.invariant_doms: invalid doms length";
  Label.Tbl.iter
    (fun key _ ->
      if not (Label.Tbl.mem doms key)
      then fatal "Cfg_dominators.invariant_doms: missing label %d" key)
    cfg.blocks;
  (* Check that (i) the immediate dominator is a strict dominator, and (ii)
     there is no other intermediate strict dominator - except for the entry
     block. *)
  Label.Tbl.iter
    (fun n idom_n ->
      if Label.equal n cfg.entry_label
      then (
        if not (Label.equal idom_n cfg.entry_label)
        then
          fatal "Cfg_dominators.invariant_doms: invalid binding for entry label")
      else (
        if not (is_strictly_dominating doms idom_n n)
        then
          fatal
            "Cfg_dominators.invariant_doms: the immediate dominator of %d, %d, \
             is not strictly dominating it"
            n idom_n;
        Label.Tbl.iter
          (fun m _ ->
            if is_strictly_dominating doms idom_n m
               && is_strictly_dominating doms m n
            then
              fatal
                "Cfg_dominators.invariant_doms: there is a strict dominator, \
                 %d, between %d and its immediate dominator, %d"
                m n idom_n)
          doms))
    doms

(* CR-soon xclerc for xclerc: factor out with the function in
   `Regalloc_ls_utils`; the only difference is the point where `f` is called. *)
let iter_blocks_dfs : Cfg.t -> f:(Cfg.basic_block -> unit) -> unit =
 fun cfg ~f ->
  let marked = ref Label.Set.empty in
  let rec iter (label : Label.t) : unit =
    if not (Label.Set.mem label !marked)
    then (
      marked := Label.Set.add label !marked;
      let block = Cfg.get_block_exn cfg label in
      Label.Set.iter
        (fun succ_label -> iter succ_label)
        (Cfg.successor_labels ~normal:true ~exn:true block);
      f block)
  in
  iter cfg.entry_label;
  (* note: some block may not have been seen since we currently cannot remove
     all non-reachable blocks. *)
  if Label.Set.cardinal !marked <> Label.Tbl.length cfg.blocks
  then
    Cfg.iter_blocks cfg ~f:(fun label block ->
        if not (Label.Set.mem label !marked) then f block)

type stack = Cfg.basic_block Stack.t

let reverse_post_order : Cfg.t -> stack =
 fun cfg ->
  let stack : stack = Stack.create () in
  iter_blocks_dfs cfg ~f:(fun block -> Stack.push block stack);
  stack

type order = int Label.Tbl.t

let build_order : Cfg.t -> stack -> order =
 fun cfg stack ->
  let order = Label.Tbl.create (Label.Tbl.length cfg.blocks) in
  Stack.iter
    (fun (block : Cfg.basic_block) ->
       let label = block.start in
       Label.Tbl.replace order label (Label.Tbl.length order))
    stack;
  order

(* See Figure 3 in the cited article. The only difference is the comparison,
   which is reversed because of the way we distribute the idenfier when we build
   `post_order`. *)
let intersect : doms -> order -> Label.t -> Label.t -> Label.t =
 fun doms post_order b1 b2 ->
  let finger1 = ref b1 in
  let finger2 = ref b2 in
  let before_in_post_order (left : Label.t) (right : Label.t) =
    Label.Tbl.find post_order left > Label.Tbl.find post_order right
  in
  while not (Label.equal !finger1 !finger2) do
    while before_in_post_order !finger1 !finger2 do
      match Label.Tbl.find_opt doms !finger1 with
      | None -> assert false
      | Some f -> finger1 := f
    done;
    while before_in_post_order !finger2 !finger1 do
      match Label.Tbl.find_opt doms !finger2 with
      | None -> assert false
      | Some f -> finger2 := f
    done
  done;
  !finger1

(* See Figure 3 in the cited article. The only difference is "Undefined", which
   is encoded here as a missing key. *)
let compute_doms : Cfg.t -> doms =
 fun cfg ->
  let doms = Label.Tbl.create (Label.Tbl.length cfg.blocks) in
  Label.Tbl.replace doms cfg.entry_label cfg.entry_label;
  let stack = reverse_post_order cfg in
  let order = build_order cfg stack  in
  let changed = ref true in
  while !changed do
    changed := false;
    Stack.iter
      (fun (block : Cfg.basic_block) ->
         let label = block.start in
         if not (Label.equal label cfg.entry_label)
        then (
          let new_idom = ref None in
          let predecessor_labels = Cfg.predecessor_labels block in
          List.iter predecessor_labels ~f:(fun predecessor_label ->
              match Label.Tbl.find_opt doms predecessor_label with
              | None -> ()
              | Some _ -> (
                match !new_idom with
                | None -> new_idom := Some predecessor_label
                | Some new_idom_pred ->
                  new_idom
                    := Some
                         (intersect doms order predecessor_label new_idom_pred)));
          match !new_idom with
          | None -> assert false
          | Some new_idom -> (
            match Label.Tbl.find_opt doms label with
            | None ->
              Label.Tbl.replace doms label new_idom;
              changed := true
            | Some dom_label ->
              if not (Label.equal dom_label new_idom)
              then (
                Label.Tbl.replace doms label new_idom;
                changed := true))))
      stack
  done;
  if debug then invariant_doms cfg doms;
  doms

let invariant_dominance_frontiers : Cfg.t -> doms -> dominance_frontiers -> unit
    =
 fun cfg doms dominance_frontiers ->
  Label.Tbl.iter
    (fun label frontier_labels ->
      Label.Set.iter
        (fun frontier_label ->
          if is_strictly_dominating doms label frontier_label
          then
            fatal
              "Cfg_dominators.invariant_dominance_frontiers: %d is strictly \
               dominating %d"
              label frontier_label;
          let block = Cfg.get_block_exn cfg frontier_label in
          let dominates_a_predecessor =
            Label.Set.exists
              (fun predecessor -> is_dominating doms label predecessor)
              block.predecessors
          in
          if not dominates_a_predecessor
          then
            fatal
              "Cfg_dominators.invariant_dominance_frontiers: %d does not \
               dominate any predecessor of %d"
              label frontier_label)
        frontier_labels)
    dominance_frontiers

(* See Figure 5 in the cited article. *)
let compute_dominance_frontiers (cfg : Cfg.t) (doms : doms) :
    dominance_frontiers =
  let res = Label.Tbl.create (Label.Tbl.length doms) in
  Label.Tbl.iter
    (fun label _idom -> Label.Tbl.replace res label Label.Set.empty)
    doms;
  Label.Tbl.iter
    (fun label _idom ->
      let block = Cfg.get_block_exn cfg label in
      let predecessor_labels = Cfg.predecessor_labels block in
      match predecessor_labels with
      | [] | [_] -> ()
      | _ :: _ :: _ ->
        List.iter predecessor_labels ~f:(fun predecessor_label ->
            let runner = ref predecessor_label in
            while not (Label.equal !runner (Label.Tbl.find doms label)) do
              let curr =
                match Label.Tbl.find_opt res !runner with
                | None -> Label.Set.empty
                | Some set -> set
              in
              Label.Tbl.replace res !runner (Label.Set.add label curr);
              runner := Label.Tbl.find doms !runner
            done))
    doms;
  if debug then invariant_dominance_frontiers cfg doms res;
  res

let iter_breadth_dominator_tree : dominator_tree -> f:(Label.t -> unit) -> unit
    =
 fun dominator_tree ~f ->
  let queue = Queue.create () in
  Queue.add dominator_tree queue;
  while not (Queue.is_empty queue) do
    let dom_tree = Queue.take queue in
    f dom_tree.label;
    List.iter dom_tree.children ~f:(fun child -> Queue.add child queue)
  done

let invariant_dominator_tree : Cfg.t -> doms -> dominator_tree -> unit =
 fun cfg doms dominator_tree ->
  let seen_by_iter = ref Label.Set.empty in
  iter_breadth_dominator_tree dominator_tree ~f:(fun label ->
      seen_by_iter := Label.Set.add label !seen_by_iter);
  let seen_by_cfg =
    Cfg.fold_blocks cfg ~init:Label.Set.empty
      ~f:(fun label _block seen_by_cfg -> Label.Set.add label seen_by_cfg)
  in
  if not (Label.Set.equal !seen_by_iter seen_by_cfg)
  then
    fatal
      "Cfg_dominators.invariant_dominator_tree: iterator did not see all blocks";
  let rec check_parent ~parent tree =
    let immediate_dominator : Label.t option =
      match Label.Tbl.find_opt doms tree.label with
      | None -> None
      | Some idom -> if Label.equal idom tree.label then None else Some idom
    in
    if not (Option.equal Label.equal immediate_dominator parent)
    then
      fatal
        "Cfg_dominators.invariant_dominator_tree: unexpected parent (%s) for \
         label %d"
        (Option.fold ~none:"none" ~some:string_of_int parent)
        tree.label;
    List.iter tree.children ~f:(fun child ->
        check_parent ~parent:(Some tree.label) child)
  in
  check_parent ~parent:None dominator_tree

let compute_dominator_tree : Cfg.t -> doms -> dominator_tree =
 fun cfg doms ->
  let rec children_of parent =
    Label.Tbl.fold
      (fun label (immediate_dominator : Label.t) acc ->
        if Label.equal parent immediate_dominator
           && not (Label.equal label immediate_dominator)
        then { label; children = children_of label } :: acc
        else acc)
      doms []
  in
  let res =
    { label = cfg.entry_label; children = children_of cfg.entry_label }
  in
  if debug then invariant_dominator_tree cfg doms res;
  res

let compute_dominators_reference (cfg : Cfg.t) =
  let all_labels =
    Cfg.fold_blocks cfg ~init:Label.Set.empty ~f:(fun label _block acc ->
        Label.Set.add label acc)
  in
  let init =
    Cfg.fold_blocks cfg ~init:Label.Map.empty ~f:(fun label _block acc ->
        Label.Map.add label
          (if Label.equal label cfg.entry_label
          then Label.Set.singleton cfg.entry_label
          else all_labels)
          acc)
  in
  let rec loop curr =
    let get_curr label =
      match Label.Map.find_opt label curr with
      | None ->
        fatal "Cfg_dominators.compute_dominators: unknown label %d" label
      | Some set -> set
    in
    let dominators, changed =
      Label.Set.fold
        (fun label (dominators, changed) ->
          let new_value =
            if Label.equal label cfg.entry_label
            then Label.Set.singleton cfg.entry_label
            else
              let predecessor_labels =
                Cfg.predecessor_labels (Cfg.get_block_exn cfg label)
              in
              match predecessor_labels with
              | [] -> Label.Set.singleton label
              | hd :: tl ->
                Label.Set.add label
                  (List.fold_left tl ~init:(get_curr hd) ~f:(fun acc label ->
                       Label.Set.inter acc (get_curr label)))
          in
          ( Label.Map.add label new_value dominators,
            changed || not (Label.Set.equal new_value (get_curr label)) ))
        all_labels (Label.Map.empty, false)
    in
    if changed then loop dominators else dominators
  in
  loop init

let is_dominating_reference dominators left right =
  match Label.Map.find_opt right dominators with
  | None -> fatal "Cfg_dominators.is_dominating: unknown label %d" right
  | Some set -> Label.Set.mem left set

let is_strictly_dominating_reference dominators left right =
  (not (Label.equal left right))
  && is_dominating_reference dominators left right

type immediate_dominators = Label.t Label.Map.t

let compute_immediate_dominators_reference :
    Cfg.t -> dominators -> immediate_dominators =
 fun cfg dominator_map ->
  let immediate_dominators =
    Label.Map.filter_map
      (fun label dominators ->
        let strict_dominators = Label.Set.remove label dominators in
        match Label.Set.choose_opt strict_dominators with
        | None ->
          if not (Label.equal label cfg.entry_label)
          then
            fatal
              "Cfg_dominators.compute_immediate_dominators: label %d has no \
               immediate dominator but is not the entry point (%d)"
              label cfg.entry_label
          else None
        | Some strict_dominator ->
          let immediate_dominator =
            Label.Set.fold
              (fun other_dominator immediate_dominator ->
                if is_strictly_dominating_reference dominator_map
                     immediate_dominator other_dominator
                then other_dominator
                else immediate_dominator)
              strict_dominators strict_dominator
          in
          Some immediate_dominator)
      dominator_map
  in
  immediate_dominators

let compute_dominance_frontiers_reference :
    Cfg.t -> immediate_dominators -> Label.Set.t Label.Map.t =
 fun cfg immediate_dominators ->
  let idom l =
    match Label.Map.find_opt l immediate_dominators with
    | None ->
      fatal
        "Cfg_dominators.compute_dominance_frontiers: no immediate dominator \
         for %d"
        l
    | Some idom -> idom
  in
  let dominance_frontiers =
    ref
      (Cfg.fold_blocks cfg ~init:Label.Map.empty ~f:(fun label _block acc ->
           Label.Map.add label Label.Set.empty acc))
  in
  Cfg.iter_blocks cfg ~f:(fun label block ->
      let num_predecessors = Label.Set.cardinal block.predecessors in
      if num_predecessors >= 2
      then
        let idom_predecessor = idom label in
        Label.Set.iter
          (fun predecessor ->
            let curr = ref predecessor in
            while not (Label.equal !curr idom_predecessor) do
              dominance_frontiers
                := Label.Map.update !curr
                     (function
                       | None ->
                         fatal
                           "Cfg_dominators.compute_dominance_frontiers: \
                            frontier for %d has not been initialized"
                           !curr
                       | Some df -> Some (Label.Set.add label df))
                     !dominance_frontiers;
              curr := idom !curr
            done)
          block.predecessors);
  !dominance_frontiers

let compute_dominator_tree_reference :
    Cfg.t -> immediate_dominators -> dominator_tree =
 fun cfg immediate_dominators ->
  let rec children_of parent =
    Label.Map.fold
      (fun label (immediate_dominator : Label.t) acc ->
        if Label.equal parent immediate_dominator
        then { label; children = children_of label } :: acc
        else acc)
      immediate_dominators []
  in
  let res =
    { label = cfg.entry_label; children = children_of cfg.entry_label }
  in
  res

let check_dominance_frontiers (reference : Label.Set.t Label.Map.t)
    (result : dominance_frontiers) : unit =
  if Label.Map.cardinal reference <> Label.Tbl.length result
  then
    fatal
      "Cfg_dominators.check_dominance_frontiers: different number of frontiers";
  Label.Map.iter
    (fun ref_label ref_frontier ->
      match Label.Tbl.find_opt result ref_label with
      | None ->
        fatal
          "Cfg_dominators.check_dominance_frontiers: no frontier for label %d"
          ref_label
      | Some res_frontier ->
        if not (Label.Set.equal ref_frontier res_frontier)
        then
          fatal
            "Cfg_dominators.check_dominance_frontiers: frontiers differ for \
             label %d"
            ref_label)
    reference

let rec check_dominator_tree (reference : dominator_tree)
    (result : dominator_tree) : unit =
  let cmp (left : dominator_tree) (right : dominator_tree) : int =
    Label.compare left.label right.label
  in
  if not (Label.equal reference.label result.label)
  then
    fatal "Cfg_dominators.check_dominator_tree: different label %d vs %d"
      reference.label result.label;
  if List.length reference.children <> List.length result.children
  then
    fatal
      "Cfg_dominators.check_dominator_tree: different number of children for \
       label %d"
      reference.label;
  List.iter2 (List.sort ~cmp reference.children)
    (List.sort ~cmp result.children) ~f:(fun ref_child res_child ->
      check_dominator_tree ref_child res_child)

let build : Cfg.t -> t =
 fun cfg ->
  let doms = compute_doms cfg in
  let dominance_frontiers = compute_dominance_frontiers cfg doms in
  let dominator_tree = compute_dominator_tree cfg doms in
  let dominators_reference = compute_dominators_reference cfg in
  let immediate_dominators_reference =
    compute_immediate_dominators_reference cfg dominators_reference
  in
  let dominance_frontiers_reference =
    compute_dominance_frontiers_reference cfg immediate_dominators_reference
  in
  check_dominance_frontiers dominance_frontiers_reference dominance_frontiers;
  let dominator_tree_reference =
    compute_dominator_tree_reference cfg immediate_dominators_reference
  in
  check_dominator_tree dominator_tree_reference dominator_tree;
  { doms;
    dominators = dominators_reference;
    dominance_frontiers;
    dominator_tree
  }

let is_dominating t left right =
  let reference = is_dominating_reference t.dominators left right in
  let result = is_dominating t.doms left right in
  if reference <> result
  then
    fatal
      "Cfg_dominators.is_dominating: result and reference disagree for %d/%d"
      left right;
  result

let is_strictly_dominating t left right =
  let reference = is_strictly_dominating_reference t.dominators left right in
  let result = is_strictly_dominating t.doms left right in
  if reference <> result
  then
    fatal
      "Cfg_dominators.is_strictly_dominating: result and reference disagree \
       for %d/%d"
      left right;
  result

let find_dominance_frontier t label =
  match Label.Tbl.find_opt t.dominance_frontiers label with
  | Some frontier -> frontier
  | None ->
    fatal "Cfg_dominators.find_dominance_frontier: no frontier for label %d"
      label

let dominator_tree t = t.dominator_tree

let iter_breadth_dominator_tree t ~f =
  iter_breadth_dominator_tree t.dominator_tree ~f
