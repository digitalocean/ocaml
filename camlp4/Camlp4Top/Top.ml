(* camlp4r q_MLast.cmo *)
(****************************************************************************)
(*                                                                          *)
(*                              Objective Caml                              *)
(*                                                                          *)
(*                            INRIA Rocquencourt                            *)
(*                                                                          *)
(*  Copyright 2002-2006 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed under   *)
(*  the terms of the GNU Library General Public License, with the special   *)
(*  exception on linking described in LICENSE at the top of the Objective   *)
(*  Caml source tree.                                                       *)
(*                                                                          *)
(****************************************************************************)

(* Authors:
 * - Daniel de Rauglaudre: initial version
 * - Nicolas Pouillard: refactoring
 *)

(* $Id: Top.ml,v 1.1.4.2 2007/04/10 13:54:03 pouillar Exp $ *)

open Parsetree;
open Lexing;
open Camlp4;
open PreCast;
open Syntax;
open Camlp4.Sig;
module Ast2pt = Camlp4.Struct.Camlp4Ast2OCamlAst.Make Ast;
module Lexer = Camlp4.Struct.Lexer.Make Token;

external not_filtered : 'a -> Gram.not_filtered 'a = "%identity";

value wrap parse_fun =
  let token_stream_ref = ref None in
  fun lb ->
    let () = Register.iter_and_take_callbacks (fun (_, f) -> f ()) in
    let token_stream =
      match token_stream_ref.val with
      [ None ->
        let () = if Sys.interactive.val then
          Format.printf "\tCamlp4 Parsing version %s\n@." Camlp4_config.version
        else () in
        let not_filtered_token_stream = Lexer.from_lexbuf lb in
        let token_stream = Gram.filter (not_filtered not_filtered_token_stream) in
        do { token_stream_ref.val := Some token_stream; token_stream }
      | Some token_stream -> token_stream ]
    in try
      match token_stream with parser
      [ [: `(EOI, _) :] -> raise End_of_file
      | [: :] -> parse_fun token_stream ]
    with
    [ End_of_file | Sys.Break | (Loc.Exc_located _ (End_of_file | Sys.Break))
        as x -> raise x
    | x ->
        let () = Stream.junk token_stream in
        let x =
          match x with
          [ Loc.Exc_located loc x -> do { 
            Toploop.print_location Format.err_formatter
              (Loc.to_ocaml_location loc);
            x }
          | x -> x ]
        in
        do {
          Format.eprintf "@[<0>%a@]@." Camlp4.ErrorHandler.print x;
          raise Exit
        } ];

value toplevel_phrase token_stream =
  match Gram.parse_tokens_after_filter Syntax.top_phrase token_stream with
  [ Some phr -> Ast2pt.phrase phr
  | None -> raise End_of_file ];

value use_file token_stream =
  let (pl0, eoi) =
    loop () where rec loop () =
      let (pl, stopped_at_directive) =
        Gram.parse_tokens_after_filter Syntax.use_file token_stream
      in
      if stopped_at_directive <> None then
        match pl with
        [ [ <:str_item< #load $str:s$ >> ] ->
            do { Topdirs.dir_load Format.std_formatter s; loop () }
        | [ <:str_item< #directory $str:s$ >> ] ->
            do { Topdirs.dir_directory s; loop () }
        | _ -> (pl, False) ]
      else (pl, True)
  in
  let pl =
    if eoi then []
    else
      loop () where rec loop () =
        let (pl, stopped_at_directive) =
          Gram.parse_tokens_after_filter Syntax.use_file token_stream
        in
        if stopped_at_directive <> None then pl @ loop () else pl
  in List.map Ast2pt.phrase (pl0 @ pl);

Toploop.parse_toplevel_phrase.val := wrap toplevel_phrase;

Toploop.parse_use_file.val := wrap use_file;

current_warning.val :=
  fun loc txt ->
    Toploop.print_warning (Loc.to_ocaml_location loc) Format.err_formatter
      (Warnings.Camlp4 txt);

Register.iter_and_take_callbacks (fun (_, f) -> f ());
