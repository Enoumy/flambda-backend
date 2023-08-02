[@@@ocaml.warning "+a-9-40-41-42"]

type t = {
  sign : Subst.Lazy.signature;
  bound_globals : Global.t array;
}

let read_from_cmi (cmi : Cmi_format.cmi_infos_lazy) =
  let sign =
    (* Freshen identifiers bound by signature *)
    Subst.Lazy.signature Make_local Subst.identity cmi.cmi_sign in
  let bound_globals = cmi.cmi_globals in
  { sign; bound_globals }

let array_fold_left_filter_map f init array =
  let ans, new_array = Array.fold_left_map f init array in
  let new_array =
    (* To be replaced with something faster if we need it *)
    Array.of_seq (Seq.filter_map (fun a -> a) (Array.to_seq new_array))
  in
  ans, new_array

let subst t (args : (Global.Name.t * Global.t) list) =
  let { sign; bound_globals } = t in
  match args with
  | [] -> t
  | _ ->
      (* The global-level substitution *)
      let arg_subst = Global.Name.Map.of_list args in
      (* Take a bound global, substitute arguments into it, then return the
         updated global while also adding it to the term-level substitution *)
      let add_and_update_binding subst bound_global =
        let name = Global.to_name bound_global in
        if Global.Name.Map.mem name arg_subst then
          (* This will be handled by [add_arg] below *)
          subst, None
        else
          begin
            let value = Global.subst bound_global arg_subst in
            let name_id = Ident.create_global name in
            let value_as_name = Global.to_name value in
            let value_id = Ident.create_global value_as_name in
            let subst =
              if Global.Name.equal name value_as_name then subst else
                Subst.add_module name_id (Pident value_id) subst
            in
            let new_bound_global =
              if Global.is_complete value then
                (* No explicit binding for unparameterised or
                   completely-applied global *)
                None
              else
                Some value
            in
            subst, new_bound_global
          end
      in
      let subst = Subst.identity in
      let subst, bound_globals =
        array_fold_left_filter_map add_and_update_binding subst bound_globals
      in
      (* Add an argument to the substitution. *)
      let add_arg subst (name, value) =
        let name_id = Ident.create_global name in
        let value_as_name = Global.to_name value in
        let value_id = Ident.create_global value_as_name in
        Subst.add_module name_id (Pident value_id) subst
      in
      let subst = List.fold_left add_arg subst args in
      let sign = Subst.Lazy.signature Keep subst sign in
      { sign; bound_globals }
