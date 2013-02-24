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

type result = [
  |`TCPv4_host of string * int  (* hostname and port *)
]

(* This resolver maps URLs to Fable Flows via network lookups using
 * the system resolver (via the Async.Tcp module) *)
module System = struct

  (* A flow resolution will request a TCP connection using this
   * resolver, as the best byte-stream protocol.  It could also
   * use alternatives such as SCTP in the future. *)
  let resolve_flow uri : result option Deferred.t =
    let host = Option.value (Uri.host uri) ~default:"localhost" in
    match Uri_services.tcp_port_of_uri uri with
    |None -> return None
    |Some port -> return (Some (`TCPv4_host (host, port)))
end

let resolve_flow uri = System.resolve_flow uri
