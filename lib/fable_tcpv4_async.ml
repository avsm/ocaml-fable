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

type flow_state = {
  start_time: float; (* Time the flow began *)
  mutable last_time: float;  (* Last time the float was read or written to *)
  mutable write_size: int64; (* Number of bytes written across the flow *)
  mutable read_size: int64;  (* Number of bytes read from the flow *)
  dst: Socket.Address.Inet.t;
  src: Socket.Address.Inet.t option;
} with sexp

type addr = Socket.Address.Inet.t
type reader = Cstruct.t Pipe.Reader.t
type writer = Cstruct.t Pipe.Writer.t

type flow = flow_state * reader * writer
type flow_accept = addr -> flow -> unit Deferred.t
type listener = (addr, int) Tcp.Server.t

let add_read_bytes flow amt =
  flow.last_time <- Unix.gettimeofday ();
  flow.read_size <- Int64.(flow.read_size + (of_int amt))

let create ?src ~dst =
  let start_time = Unix.gettimeofday () in
  { start_time;
    last_time = start_time;
    write_size = 0L;
    read_size = 0L;
    src; dst
  }

(* Wrap a Reader/Write pair with a flow that tracks the statistics
 * and apply a function with the resulting new end points *)
let wrap flow rd wr : flow =
  (* Construct a proxy pipe to track flow stats from the
   * real TCP Reader/Writer that we've been supplied. *)
  let rd',wr' = Pipe.create () in
  let rec read_t () =
    let buf = Cstruct.create 4096 in
    Printf.printf "block read\n%!";
    Async_cstruct.read rd buf 
    >>= function
    |`Eof -> 
      Printf.printf "read eof\n%!";
      Pipe.close wr'; return ()
    |`Ok len -> begin
        Printf.printf "unblock read\n%!";
        let buf = Cstruct.set_len buf len in
        Pipe.write_when_ready wr' 
          ~f:(fun wrfn -> add_read_bytes flow len; wrfn buf)
        >>= function
        |`Ok () -> read_t ()
        |`Closed -> Reader.close rd
      end
  in
  Deferred.don't_wait_for (read_t ());
  let rd'',wr'' = Pipe.create () in
  Deferred.don't_wait_for (
    Writer.transfer wr rd''
      (fun buf -> Async_cstruct.schedule_write wr buf)
  );
  flow, rd',wr''

let connect ?src ~dst ~port () =
  Tcp.connect (Tcp.to_host_and_port dst port)
  >>= fun (rd,wr) ->
  let dst = Socket.getpeername (Socket.of_fd (Reader.fd rd) Socket.Type.tcp) in
  let flow = create ?src ~dst in
  return (wrap flow rd wr)

(* The accept handler constructs flows as they are accepted, and
 * tracks the flow information via the Reader and Writer wrappers.
 * @param our_sock    The listening socket address.
 * @param their_sock  The connecting client's address.
*)
let accept_handler fn our_sock their_sock rd wr =
  let flow = create ?src:our_sock ~dst:their_sock in
  wrap flow rd wr

let accept ?max_connections ?max_pending_connections ?src ?port f =
  let listening_on =
    match port with
    |None -> Tcp.on_port_chosen_by_os
    |Some port -> Tcp.on_port port
  in
  let accept_handler their_sock rd wr =
    let flow = create ?src ~dst:their_sock in
    f their_sock (wrap flow rd wr)
  in
  Tcp.Server.create 
    ?max_connections
    ?max_pending_connections 
    listening_on
    accept_handler

let close_listener l = Tcp.Server.close l
