open Prelude.Ana
open Analyses
open MyCFG

module type KMPParam =
sig
  type t
  val equal: t -> t -> bool

  val pattern: t array
end

module KMP (KMPParam: KMPParam) =
struct
  include KMPParam

  let m = Array.length pattern

  (* let next_inner prefix q x =
    let q' = ref q in
    while !q' > 0 && not (equal pattern.(!q') x) do
      q' := prefix.(!q' - 1)
    done;
    if equal pattern.(!q') x then begin
      q' := !q' + 1
    end;
    !q' *)
  let rec next_inner prefix q x =
    if q > 0 && not (equal pattern.(q) x) then
      next_inner prefix prefix.(q - 1) x
    else if equal pattern.(q) x then
      q + 1
    else
      q

  (* CLRS *)
  let prefix: int array =
    let pi = Array.make m 0 in
    let k = ref 0 in
    for q = 2 to m do
      k := next_inner pi !k pattern.(q - 1);
      pi.(q - 1) <- !k
    done;
    pi

  let next (q: int) (x: t): int =
    if q = m then
      m
    else
      next_inner prefix q x
end

module type Arg =
sig
  val path: (node * node) list
end

(* TODO: instead of multiple observer analyses, use single list-domained observer analysis? *)
let get_fresh_spec_id =
  let fresh_id = ref 0 in
  fun () ->
    let return_id = !fresh_id in
    fresh_id := return_id + 1;
    return_id

module MakeSpec (Arg: Arg) : Analyses.Spec =
struct
  include Analyses.DefaultSpec

  let id = get_fresh_spec_id ()
  let name () = "observer" ^ string_of_int id

  module ChainParams =
  struct
    let n = List.length Arg.path
    let names x = "state " ^ string_of_int x
  end
  module D = Lattice.Flat (Printable.Chain (ChainParams)) (Printable.DefaultNames)
  module G = Lattice.Unit
  module C = D

  let should_join x y = D.equal x y (* fully path-sensitive *)

  module KMP = KMP (
    struct
      type t = node * node
      let equal (p1, n1) (p2, n2) = Node.equal p1 p2 && Node.equal n1 n2
      let pattern = Array.of_list Arg.path
    end
  )

  (* let () = Arg.path
    |> List.map (fun (p, n) -> Printf.sprintf "(%d, %d)" p n)
    |> String.concat "; "
    |> Printf.printf "observer path: [%s]\n" *)

  let step d prev_node node =
    match d with
    | `Lifted q -> begin
        let q' = KMP.next q (prev_node, node) in
        if q' = KMP.m then
          raise Deadcode
          (* TODO: undo. currently observer doesn't kill paths, just splits for nice ARG viewing purposes *)
          (* `Lifted q' *)
        else
          `Lifted q'
      end
    | _ -> d

  let step_ctx ctx = step ctx.local ctx.prev_node ctx.node

  (* transfer functions *)
  let assign ctx (lval:lval) (rval:exp) : D.t =
    (* match lval with
    | (Var v, NoOffset) ->
      begin match ctx.local with
      | `Lifted 2 -> raise Deadcode
      | `Lifted x -> `Lifted (x + 1)
      | _ -> ctx.local
      end
    | _ ->
      ctx.local *)
    step_ctx ctx

  let vdecl ctx (_:varinfo) : D.t =
    step_ctx ctx

  let branch ctx (exp:exp) (tv:bool) : D.t =
    (* match ctx.node with
    | Statement s when s.sid = 32 ->
      begin match ctx.local with
      | `Lifted 0 -> `Lifted 1
      | _ -> ctx.local
      end
    | _ ->
      ctx.local *)
    step_ctx ctx

  let body ctx (f:fundec) : D.t =
    step_ctx ctx

  let return ctx (exp:exp option) (f:fundec) : D.t =
    step_ctx ctx

  let enter ctx (lval: lval option) (f:varinfo) (args:exp list) : (D.t * D.t) list =
    (* ctx.local doesn't matter here? *)
    [ctx.local, step ctx.local ctx.prev_node (FunctionEntry f)]

  let combine ctx (lval:lval option) fexp (f:varinfo) (args:exp list) fc (au:D.t) : D.t =
    step au (Function f) ctx.node

  let special ctx (lval: lval option) (f:varinfo) (arglist:exp list) : D.t =
    step_ctx ctx

  let startstate v = `Lifted 0
  let otherstate v = D.top ()
  let exitstate  v = D.top ()
end

(* let _ =
  let module Spec = MakeSpec (
    struct
      (* let path = [(23, 24); (24, 25)] *)
      (* let path = [(30, 32); (32, 34); (34, 26); (26, 29)] *)

      (* junker, nofun, no-SV, observer 1 *)
      (* let path = [(1, 2); (2, 6); (6, 8); (8, 10)] *)
      (* junker, nofun, SV, observer 1 *)
      (* let path = [(17, 18); (18, 22); (22, 24); (24, 26)] *)
      (* junker, observer 3 *)
      (* let path = [(14, 16); (16, 18); (18, 10); (10, 13)] *)
      (* junker, SV, observer 3 *)
      (* let path = [(30, 32); (32, 34); (34, 26); (26, 29)] *)

      (* FSE15, nofun, swapped a *)
      (* let path = [(20, 22); (22, 24); (24, 28); (28, 29); (29, 30); (30, 32)] *)

      (* path_nofun *)
      (* let path = [(20, 21); (21, 25); (25, 27)] *)
      let path = [(23, 24); (24, 25); (25, 27)]
    end
  )
  in
  MCP.register_analysis (module Spec) *)