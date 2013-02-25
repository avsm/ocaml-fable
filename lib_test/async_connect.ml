(*
 * Copyright (c) 2013 Anil Madhavapeddy <anil@recoil.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *)

open Core.Std
open Async.Std

open Fable_async
module L = Log.Global

let t =
  L.info "Start";
  let ctx = init () in
  let uri = Uri.of_string "http://anil.recoil.org" in
  connect ~ctx ~uri
  >>= fun (flow, rd, wr) ->
  let rd,wr = Async_cstruct.Pipe.map_string rd wr in
  L.info "%s" "Connected";
  L.sexp flow sexp_of_flow_state;
  Pipe.write wr "GET / HTTP/1.1\nHost: anil.recoil.org\nConnection: close\n\n"
  >>= fun () ->
  Pipe.iter rd ~f:(fun c -> Log.Global.debug "BODY %s\n%!" c; return ())
  >>= fun () ->
  L.sexp flow sexp_of_flow_state;
  L.info "%s" "End";
  return ()

let _ =
  L.set_level `Debug;
  L.set_output [Log.Output.screen];
  never_returns (Scheduler.go ())
