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

(* Every FABLE resolver has a context which tracks the node it is bound
 * to, and the network connections that are active from this context *)
type ctx
val init : unit -> ctx

(* Every established connection has a [reader] and [writer] Async interface,
 * and a connection-specific abstract [flow_state] *)
type flow_state with sexp_of
type 'a flow = flow_state * 'a Pipe.Reader.t * 'a Pipe.Writer.t

(* Establish a connection to a remote URI. *)
val connect : ctx:ctx -> uri:Uri.t -> Cstruct.t flow Deferred.t

(* New flow handler for building flows.  If the [Deferred.t] returned
 * here is ever determined, or the handler raises an exception, then the
 * [Reader] and [Writer] will be closed. *)
type flow_accept = Cstruct.t flow -> unit Deferred.t

(* Listen for incoming network flows *)
type listener
val listen : ctx:ctx -> uri:Uri.t -> f:flow_accept -> listener Deferred.t
val close_listener : listener -> unit Deferred.t

(* FABLE uses [Cstruct] buffers by default, which are heap-allocated
 * memory buffers. This module lets them be conveniently converted into
 * equivalent structures such as [string] (which involves a copy)
 *)
val map_flow_to_string : Cstruct.t flow -> string flow
