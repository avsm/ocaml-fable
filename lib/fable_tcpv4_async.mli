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

open Async.Std

(* The per-flow state and associated pipes *)
type flow_state with sexp_of
type reader = Cstruct.t Pipe.Reader.t
type writer = Cstruct.t Pipe.Writer.t
type flow = flow_state * reader * writer

(* Handler for constructing new flows from listeners.
 * The first parameter is the remote endpoint. *)
type flow_accept = 
  Socket.Address.Inet.t -> 
  flow -> 
  unit Deferred.t

(* Establish a remote flow *)
val connect : 
  ?src:Socket.Address.Inet.t ->
  dst:string -> 
  port:int ->
  unit -> 
  flow Deferred.t 

(* A listening flow that accepts incoming connections *)
type listener

(* Accept new connections *)
val listen :
  ?max_connections:int ->
  ?max_pending_connections:int ->
  ?src:Socket.Address.Inet.t ->
  ?port:int ->
  flow_accept ->
  listener Deferred.t

(* Stop accepting new connections *)
val close_listener : 
  listener ->
  unit Deferred.t
