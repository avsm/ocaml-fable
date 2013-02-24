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

(* The main name service interface on which clients connect and accept
 * flows from other end points.  This is the Async-specialised one. *)

open Core.Std
open Async.Std

type flow_state = [
  |`TCPv4 of Fable_tcpv4_async.flow_state
] with sexp_of

type listener = [ 
  |`TCPv4 of unit Ivar.t * unit Ivar.t
]

type reader = Cstruct.t Pipe.Reader.t
type writer = Cstruct.t Pipe.Writer.t
type flow = flow_state * reader * writer
type flow_accept = flow -> unit Deferred.t

type ctx = {
  (* TODO bind source port here for tcpv4 *)
  tcpv4_listeners: Fable_tcpv4_async.listener Queue.t;
}

let init () =
  let tcpv4_listeners = Queue.create () in
  { tcpv4_listeners }

exception Connection_error
let connect ~ctx ~uri =
  let open Fable_resolver_async in
  resolve_flow uri
  >>= function
  |None -> 
    raise Connection_error  (* TODO sexp *)
  |Some (`TCPv4_host (dst, port)) ->
    Fable_tcpv4_async.connect (* TODO src *) ~dst ~port ()
    >>= fun (flow, rd, wr) ->
    return (`TCPv4 flow, rd, wr)

let accept ~ctx ~uri ~f =
  let src = None (* TODO *) in
  let open Fable_resolver_async in
  resolve_flow uri
  >>= function
  |None -> raise Connection_error (* TODO sexp *)
  |Some (`TCPv4_host (_,port)) ->
    Fable_tcpv4_async.accept ?src ~port
      (fun srcaddr (flow,rd,wr) -> 
         let flow : flow = (`TCPv4 flow), rd, wr in
         (* TODO srcaddr needs to be passed through resolver somehow *)
         f flow
      )
    >>= fun s ->
    Queue.enqueue ctx.tcpv4_listeners s;
    Log.Global.info "accept[started]: %s" (Uri.to_string uri);
    let iv = Ivar.create () in
    let iv' = Ivar.create () in
    don't_wait_for (
      Ivar.read iv 
      >>= fun () ->
      Queue.iter ctx.tcpv4_listeners 
        ~f:(fun f -> don't_wait_for (Fable_tcpv4_async.close_listener f));
      Queue.clear ctx.tcpv4_listeners;
      Ivar.fill iv' ();
      return ()
    );
    return (`TCPv4 (iv,iv'))

let close_listener =
  function
  |`TCPv4 (l,l') ->
    Ivar.fill_if_empty l ();
    Ivar.read l
