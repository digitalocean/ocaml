(***********************************************************************)
(*                                                                     *)
(*                                OCaml                                *)
(*                                                                     *)
(*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         *)
(*                                                                     *)
(*  Copyright 1996 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the Q Public License version 1.0.               *)
(*                                                                     *)
(***********************************************************************)

(* $Id: printinstr.mli 11156 2011-07-27 14:17:02Z doligez $ *)

(* Pretty-print lists of instructions *)

open Instruct

open Format

val instruction: formatter -> instruction -> unit
val instrlist: formatter -> instruction list -> unit
