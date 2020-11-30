(** Thread returning analysis. *)

open Prelude.Ana
open Analyses

let is_current (ask: Queries.ask): bool =
  match ask Queries.IsThreadReturn with
  | `Bool b -> b
  | `Top -> true
  | _ -> failwith "ThreadReturn.is_current"


module Spec : Analyses.Spec =
struct
  include Analyses.DefaultSpec

  let name () = "threadreturn"
  module D = IntDomain.Booleans
  module G = Lattice.Unit
  module C = D

  (* transfer functions *)
  let assign ctx (lval:lval) (rval:exp) : D.t =
    ctx.local

  let branch ctx (exp:exp) (tv:bool) : D.t =
    ctx.local

  let body ctx (f:fundec) : D.t =
    ctx.local

  let return ctx (exp:exp option) (f:fundec) : D.t =
    ctx.local

  let enter ctx (lval: lval option) (f:varinfo) (args:exp list) : (D.t * D.t) list =
    [ctx.local, false]

  let combine ctx (lval:lval option) fexp (f:varinfo) (args:exp list) fc (au:D.t) : D.t =
    ctx.local

  let special ctx (lval: lval option) (f:varinfo) (arglist:exp list) : D.t =
    ctx.local

  let startstate v = true
  let threadenter ctx lval f args = true
  let threadspawn ctx lval f args fctx = ctx.local
  let exitstate  v = D.top ()

  let query ctx x =
    match x with
    | Queries.IsThreadReturn -> `Bool ctx.local
    | _ -> `Top
end

let _ =
  MCP.register_analysis (module Spec : Spec)
