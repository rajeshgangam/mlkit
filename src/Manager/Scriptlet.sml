signature SCRIPTLET =
    sig
	(* Parsing scriptlet form variable arguments *)
	type result = {funid:string, strid:string, valspecs: (string * string) list}

	val parseArgs     : TextIO.instream -> result 
	val parseArgsFile : string -> result

	(* Generation of abstract form interfaces *)
	type field = {name:string, typ:string}
	type script = {name:string, fields:field list}
	val gen     : TextIO.outstream -> script list -> unit
	val genFile : string -> script list -> unit
    end

functor Scriptlet(val error : string -> 'a) : SCRIPTLET =
    struct

	(* Parsing scriptlet form variable arguments *)
	type result = {funid:string, strid:string, valspecs: (string * string) list}

	fun isSymbol c =
	    case c of
		#"=" => true
	      | #"(" => true
	      | #")" => true
	      | #":" => true
	      | _ => false

	fun readSymbol is : string option =
	    case TextIO.lookahead is of
		SOME c => (if isSymbol c then (TextIO.input1 is; SOME (String.str c))
			   else NONE)
	      | NONE => NONE
		    
	fun readId is (acc:char list) : string option =
	    case TextIO.lookahead is of
		SOME c => (if Char.isSpace c orelse isSymbol c then 
			       if acc = nil then NONE
			       else SOME (implode (rev acc))					  
			   else (TextIO.input1 is; readId is (c::acc)))
	      | NONE => SOME (implode (rev acc))

	fun readSpace b is : bool =
	    case TextIO.lookahead is of
		SOME c => if Char.isSpace c then (TextIO.input1 is; readSpace true is)
			  else b
	      | NONE => b
			      
	fun readTokens is (xs:string list) : string list option =
	    case readSymbol is of
		SOME "(" =>
		    (case TextIO.lookahead is of
			 SOME #"*" => (TextIO.input1 is; readComment is xs 1)
		       | _ => readTokens is ("("::xs))
	      | SOME t => readTokens is (t::xs)
	      | NONE => 
		    (case readId is nil of
			 SOME "SCRIPTLET" => SOME (rev xs)
		       | SOME id => readTokens is (id :: xs)
		       | NONE => if readSpace false is then readTokens is xs
				 else NONE)
				     
	and readComment is xs 0 = readTokens is xs
	  | readComment is xs level = 
	     case TextIO.input1 is of
		 SOME #"*" => 
		     readComment is xs (case TextIO.lookahead is of
					    SOME #")" => (TextIO.input1 is; level - 1)
					  | SOME _ => level
					  | NONE => error "nonclosed comment")
	       | SOME #"(" =>
		     readComment is xs (case TextIO.lookahead is of
					    SOME #"*" => (TextIO.input1 is; level + 1)
					  | SOME _ => level
					  | NONE => error "nonclosed comment")
	       | SOME _ => readComment is xs level
	       | NONE => error "nonclosed comment"
		     
	fun isId token : bool = 
	    CharVector.foldl (fn (c,b) => b andalso 
			      Char.isAlphaNum c) true token

	fun isLongid token : bool = 
	    CharVector.foldl (fn (c,b) => b andalso 
			      (Char.isAlphaNum c orelse c = #".")) true token

	fun parseId tokens : string * string list =
	    case tokens of
		t::ts => if isId t then (t,ts)
			 else error "failed to parse functor identifier"
	      | _ => error "failed to parse functor identifier"

	fun parseToken s tokens =
	    case tokens of
		x :: xs => if s = x then xs
			   else error ("expecting `" ^ s ^ "'")
	      | _ => error ("expecting `" ^ s ^ "'")

	fun parseType (ts,acc) =
	    let
		fun spacify (x::y::ys) = if isLongid x andalso isLongid y then x :: " " :: spacify (y::ys)
					 else x :: spacify (y::ys)
		  | spacify x = x
		fun return acc ts = 
		    case concat(spacify(rev acc)) of
			"" => NONE
		      | s => SOME (s, ts)
	    in
		case ts of
		    t::ts' => if t <> "end" andalso t <> "val" then parseType (ts',t::acc)
			      else return acc ts
		  | nil => return acc ts
	    end
	fun parseSpecs ts : (string * string) list * string list =
	    let fun parseSpec ts : ((string * string) * string list) option =
		  case ts of
		      "val" :: ts => 
			  let val (id,ts) = parseId ts
			      val ts = parseToken ":" ts
			  in
			      case parseType (ts,nil) of
				  SOME (typ,ts) => SOME((id,typ),ts)
				| NONE => NONE
			  end
		    | _ => NONE
		fun parse (ts,acc) =
		    case parseSpec ts of
			SOME (p,ts) => parse (ts,p::acc)
		      | NONE => (rev acc,ts)
	    in parse (ts, nil)
	    end

	fun printss nil = print "\n"
	  | printss (x::xs) = (print x; print "\n"; printss xs)

	fun parseArgs (is : TextIO.instream) : result =
	    case readTokens is nil of
		NONE => error "not able to read all tokens before SCRIPTLET signature"
	      | SOME ts =>
		    let (* val _ = printss ts *)
			val ts = parseToken "functor" ts
			val (funid, ts) = parseId ts
			val ts = parseToken "(" ts
			val (strid, ts) = parseId ts
			val ts = parseToken ":" ts
			val ts = parseToken "sig" ts
			val (specs,ts) = parseSpecs ts
		    in {funid=funid,valspecs=specs,strid=strid}
		    end

	fun parseArgsFile (f: string) : result =
	    let val is = TextIO.openIn f
	    in parseArgs is before TextIO.closeIn is
		handle X => (TextIO.closeIn is; raise X)
	    end

	(* Generation of abstract form interfaces *)

	fun stripString s s2 =
	    let fun remove (c::cs,c2::cs2) = if c=c2 then remove(cs,cs2)
					     else NONE
		  | remove (nil,cs2) = SOME cs2
		  | remove _ = NONE
		val (cs,cs2) = (rev (explode s), rev (explode s2))
	    in case remove(cs,cs2) of 
		SOME cs => SOME(implode (rev cs))
	      | NONE => NONE
	    end

	fun stripFormtype typ =
	    case stripString " Obj.obj" typ of
		SOME typ => typ
	      | NONE => error "expecting value specification of type 'a Obj.obj"


	fun typToString "int" = "Int.toString"
	  | typToString "string" = ""
	  | typToString s = 
	    (case rev (String.tokens (fn c => c = #".") s) of
		 x::xs => concat (map (fn x => x ^ ".") (rev xs)) ^ "toString"
	       | _ => error ("Type '" ^ s ^ "' not known!"))


	type field = {name:string, typ:string}
	type script = {name:string, fields:field list}
	fun ind 0 = ""
	  | ind n = "  " ^ ind (n-1)

	fun gen (os: TextIO.outstream) (ss:script list) = 
	    let 
		fun outs s = TextIO.output(os,s)
		fun outnl() = TextIO.output(os,"\n")
		fun outl s = (outs s; outnl())
		fun outi i s = (outs (ind i); outl s)

		fun out_header_sig () =
		    (  outl   "signature SCRIPTS ="
		     ; outi 1 "sig"
		     ; outi 2 "include XHTML_EXTRA")

		fun appl f nil = ()
		  | appl f [x] = f(x,true)
		  | appl f (x::xs) = (f(x,false); appl f xs)

		fun out_script_sig {name,fields} =
		    (  outi 2 ("structure " ^ name ^ " :")
		     ; outi 3 "sig"
		     ; app (fn {name,...} => outi 4 ("type " ^ name)) fields
		     ; app (fn {name,typ} => outi 4 ("val " ^ name ^ " : (" ^ name ^ "," 
						     ^ stripFormtype typ ^ ") fname")) fields
		     ; outs (ind 4)
		     ; outs "val form : ("
		     ; app (fn {name,...} => outs (name ^ "->")) fields
		     ; outl "nil,'a,'p,block) form"
		     ; outi 10 "-> (nil,nil,'a,formclosed,'p,block) elt"
		     ; outs (ind 4)
		     ; outs "val link : {"
		     ; appl (fn ({name,typ},b) => outs (name ^ ":" ^ stripFormtype typ 
							^ (if b then "" else ", "))) fields
		     ; outl "}"
		     ; outi 10 "-> ('x,'y,ina,'f,'p,inline) elt"
		     ; outi 10 "-> ('x,'y,aclosed,'f,'p,inline) elt"
		     ; outi 3 "end")

		fun out_header_struct () = 
		    (  outl "structure Scripts :> SCRIPTS ="
		     ; outi 1 "struct"
		     ; outi 2 "open XHtml"
		     ; outi 2 "fun form0 t s = Unsafe.form {action=s,method=\"post\"} t"
		     ; outnl())

		fun out_script_struct {name=s,fields} = 
		    (  outi 2 ("structure " ^ s ^ " =")
		     ; outi 3 "struct"
		     ; app (fn {name,typ} => outi 4 ("type " ^ name ^ " = unit")) fields
		     ; outi 4 ("val " ^ s ^ " = \"" ^ s ^ ".sml\"")
		     ; app (fn {name,typ} => outi 4 ("val " ^ name ^ " = {script=" ^ s ^ 
						     ", n=\"" ^ name ^ "\"}")) fields
		     ; outi 4 ("fun form t = form0 t " ^ s)
		     ; outs (ind 4)
		     ; outs "fun link {"
		     ; appl (fn ({name,typ},b) => outs(name ^ "=" ^ name ^ "'" ^
						   (if b then "" else ","))) fields
		     ; outl "} e ="
		     ; outi 5 ("Unsafe.ahref {src=concat[\"/\", " ^ s ^ ",")
		     ; (let
			    fun outline p {name,typ} =
			      let val typ = stripFormtype typ
			      in outi 7 ("\"" ^ p ^ "\", #n " ^ name ^ ", \"=\", " 
					 ^ typToString typ ^ " " ^ name ^ "',")
			      end
			in case fields of
		                f::fs => (outline "?" f; app (outline "&") fs)
			      | nil => ()
			end)
		     ; outi 7 "\"\"]} e"
		     ; outi 4 "end")
	    in
	        outl "(* This script is auto generated by SMLserver, based on"
	      ; outl " * scriptlet functor arguments - DO NOT EDIT THIS FILE! *)"
	      ; outnl
	      ; out_header_sig()
	      ; app out_script_sig ss
	      ; outi 2 "end"
	      ; outl ""
	      ; out_header_struct()
	      ; app out_script_struct ss
	      ; outi 2 "end"
	    end	

	fun genFile (f:string) a =
	    let val os = TextIO.openOut f
	    in (gen os a before TextIO.closeOut os)
		handle X => (TextIO.closeOut os; raise X)
	    end
    end
	