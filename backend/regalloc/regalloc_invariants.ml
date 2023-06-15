[@@@ocaml.warning "+a-4-30-40-41-42"]

open! Regalloc_utils

let precondition : Cfg_with_layout.t -> unit =
 fun cfg_with_layout ->
  (* note: the `live` field is set, because we want to call the `Deadcode` pass
     before `Cfgize`. *)
  let desc_is_neither_spill_or_reload (id : Instruction.id) (desc : Cfg.basic) :
      unit =
    match desc with
    | Op op -> (
      match op with
      | Move -> ()
      | Spill -> fatal "instruction %d is a spill" id
      | Reload -> fatal "instruction %d is a reload" id
      | Const_int _ -> ()
      | Const_float _ -> ()
      | Const_symbol _ -> ()
      | Stackoffset _ -> ()
      | Load _ -> ()
      | Store _ -> ()
      | Intop _ -> ()
      | Intop_imm _ -> ()
      | Intop_atomic _ -> ()
      | Negf -> ()
      | Absf -> ()
      | Addf -> ()
      | Subf -> ()
      | Mulf -> ()
      | Divf -> ()
      | Compf _ -> ()
      | Csel _ -> ()
      | Floatofint -> ()
      | Intoffloat -> ()
      | Valueofint -> ()
      | Intofvalue -> ()
      | Probe_is_enabled _ -> ()
      | Opaque -> ()
      | Begin_region -> ()
      | End_region -> ()
      | Specific op ->
        if Arch.operation_can_raise op
        then
          fatal
            "architecture specific instruction %d that can raise but isn't a \
             terminator"
            id
      | Name_for_debugger _ -> ())
    | Reloadretaddr | Pushtrap _ | Poptrap | Prologue -> ()
  in
  let register_must_not_be_on_stack (id : Instruction.id) (reg : Reg.t) : unit =
    match reg.Reg.loc with
    | Unknown -> () (* most registers are not precolored *)
    | Reg _ ->
      () (* some register are precolored, e.g. to enforce constraints *)
    | Stack (Incoming _ | Outgoing _ | Domainstate _) ->
      (* incoming/outgoing/domainstate locations are for function parameters *)
      ()
    | Stack (Local _) ->
      (* local stack locations are for spilling, and will be introduced by the
         register allocator *)
      fatal "instruction %d has a register with a stack location" id
  in
  let registers_must_not_be_on_stack (id : Instruction.id) (regs : Reg.t array)
      : unit =
    ArrayLabels.iter regs ~f:(register_must_not_be_on_stack id)
  in
  (* CR xclerc for xclerc: the check below should not be in this function, since
     it is IRC-specific *)
  let register_must_be_on_unknown_list (id : Instruction.id) (reg : Reg.t) :
      unit =
    match reg.Reg.irc_work_list with
    | Unknown_list -> ()
    | Precolored -> ()
    | Initial | Simplify | Freeze | Spill | Spilled | Coalesced | Colored
    | Select_stack ->
      fatal "instruction %d has a register (%a) already in a work list (%S)" id
        Printmach.reg reg
        (Reg.string_of_irc_work_list reg.Reg.irc_work_list)
  in
  let register_must_be_on_unknown_list (id : Instruction.id)
      (regs : Reg.t array) : unit =
    ArrayLabels.iter regs ~f:(register_must_be_on_unknown_list id)
  in
  Cfg_with_layout.iter_instructions cfg_with_layout
    ~instruction:(fun instr ->
      let id = instr.id in
      desc_is_neither_spill_or_reload id instr.desc;
      registers_must_not_be_on_stack id instr.arg;
      registers_must_not_be_on_stack id instr.res;
      register_must_be_on_unknown_list id instr.arg;
      register_must_be_on_unknown_list id instr.res)
    ~terminator:(fun term ->
      let id = term.id in
      registers_must_not_be_on_stack id term.arg;
      registers_must_not_be_on_stack id term.res;
      register_must_be_on_unknown_list id term.arg;
      register_must_be_on_unknown_list id term.res);
  let fun_num_stack_slots =
    (Cfg_with_layout.cfg cfg_with_layout).fun_num_stack_slots
  in
  Array.iteri fun_num_stack_slots ~f:(fun reg_class num_slots ->
      if num_slots <> 0
      then fatal "register class %d has %d slots(s)" reg_class num_slots)

let postcondition_layout : Cfg_with_layout.t -> unit =
 fun cfg_with_layout ->
  let max_stack_slots = Array.init Proc.num_register_classes ~f:(fun _ -> -1) in
  let register_must_not_be_unknown (id : Instruction.id) (reg : Reg.t) : unit =
    match reg.Reg.loc with
    | Reg _ -> ()
    | Stack (Incoming _ | Outgoing _ | Domainstate _) -> ()
    | Stack (Local slot) ->
      if slot < 0
      then fatal "instruction %d is using an invalid slot (%d)" id slot;
      let reg_class = Proc.register_class reg in
      max_stack_slots.(reg_class) <- max max_stack_slots.(reg_class) slot
    | Unknown ->
      fatal "instruction %d has a register (%a) with an unknown location" id
        Printmach.reg reg
  in
  let registers_must_not_be_unknown (id : Instruction.id) (regs : Reg.t array) :
      unit =
    ArrayLabels.iter regs ~f:(register_must_not_be_unknown id)
  in
  let num_stack_locals (regs : Reg.t array) : int =
    Array.fold_left regs ~init:0 ~f:(fun acc reg ->
        match reg.Reg.loc with
        | Unknown | Reg _ | Stack (Incoming _ | Outgoing _ | Domainstate _) ->
          acc
        | Stack (Local _) -> succ acc)
  in
  let arch_constraints (id : Instruction.id) (desc : Cfg.basic)
      (arg : Reg.t array) (res : Reg.t array) : unit =
    match Config.architecture with
    (* CR xclerc for xclerc: what about cross-compilation? *)
    | "amd64" | "arm64" -> (
      let num_locals = num_stack_locals arg + num_stack_locals res in
      match desc with
      | Op (Spill | Reload) ->
        (* CR xclerc for xclerc: should check arg/res according to spill/reload,
           rather than the total number. *)
        if num_locals > 1
        then
          fatal "instruction %d is a move and refers to %d spilling slots" id
            num_locals
      | _ -> ())
    | arch -> fatal "unsupported architecture %S" arch
  in
  let register_classes_must_be_consistent (id : Instruction.id) (reg : Reg.t) :
      unit =
    match reg.Reg.loc with
    | Reg phys_reg ->
      let phys_reg = Proc.phys_reg phys_reg in
      if not (same_reg_class reg phys_reg)
      then
        fatal
          "instruction %d assigned %a to %a but they are in different classes"
          id Printmach.reg reg Printmach.reg phys_reg
    | Stack _ | Unknown -> ()
  in
  let register_classes_must_be_consistent (id : Instruction.id)
      (regs : Reg.t array) : unit =
    ArrayLabels.iter regs ~f:(register_classes_must_be_consistent id)
  in
  Cfg_with_layout.iter_instructions cfg_with_layout
    ~instruction:(fun instr ->
      let id = instr.id in
      registers_must_not_be_unknown id instr.arg;
      registers_must_not_be_unknown id instr.res;
      arch_constraints id instr.desc instr.arg instr.res;
      register_classes_must_be_consistent id instr.arg;
      register_classes_must_be_consistent id instr.res)
    ~terminator:(fun term ->
      let id = term.id in
      registers_must_not_be_unknown id term.arg;
      registers_must_not_be_unknown id term.res;
      register_classes_must_be_consistent id term.arg;
      register_classes_must_be_consistent id term.res);
  let fun_num_stack_slots =
    (Cfg_with_layout.cfg cfg_with_layout).fun_num_stack_slots
  in
  let reg_class = ref 0 in
  Array.iter2 max_stack_slots fun_num_stack_slots ~f:(fun max_slot num_slots ->
      (* CR-soon xclerc for xclerc: make the condition stricter. The present
         condition ensure safety: no access out of bounds (i.e. to another
         frame), but could be made stricter to ensure optimiality (i.e. we use
         every element from the frame). *)
      if max_slot >= num_slots
      then
        fatal
          "register class %d has a max slot of %d, but the number of slots is \
           %d"
          !reg_class max_slot num_slots;
      incr reg_class)

let postcondition_liveness : Cfg_with_liveness.t -> unit =
 fun cfg_with_liveness ->
  postcondition_layout (Cfg_with_liveness.cfg_with_layout cfg_with_liveness);
  let cfg = Cfg_with_liveness.cfg cfg_with_liveness in
  let entry_block = Cfg.get_block_exn cfg cfg.entry_label in
  let live_at_entry_point =
    Cfg_with_liveness.liveness_find cfg_with_liveness
      (Cfg.first_instruction_id entry_block)
  in
  Reg.Set.iter
    (fun reg ->
      match reg.Reg.loc with
      | Unknown -> assert false (* already tested in `postcondition_layout` *)
      | Reg _ -> ()
      | Stack (Local _) ->
        fatal "`Stack (Local _)`live at entry point: %a" Printmach.reg reg
      | Stack (Incoming _) -> ()
      | Stack (Outgoing _) ->
        fatal "`Stack (Outgoing _)` live at entry point: %a" Printmach.reg reg
      | Stack (Domainstate _) -> ())
    live_at_entry_point.before