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

(* Every established connection has a [reader] and [writer] Async interface,
 * and a connection-specific abstract [flow_state] *)
type reader = Cstruct.t Pipe.Reader.t
type writer = Cstruct.t Pipe.Writer.t
type flow_state with sexp_of

type flow = flow_state * reader * writer
type flow_accept = flow -> unit Deferred.t
type listener

val init : unit -> ctx

val connect : ctx:ctx -> uri:Uri.t -> flow Deferred.t
val accept : ctx:ctx -> uri:Uri.t -> f:flow_accept -> listener Deferred.t
