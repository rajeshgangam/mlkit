(* Lambda variables *)

functor Lvars(structure Name : NAME
	      structure Report : REPORT
	      structure Crash : CRASH
	      structure PP : PRETTYPRINT
	      structure IntFinMap : MONO_FINMAP where type dom = int
		) : LVARS =
  struct

    (* Lambda variables are based on names which may be `matched'. In
     * particular, if two lambda variables, lv1 and lv2, are
     * successfully matched, eq(lv1,lv2) = true. This may affect the
     * canonical ordering of lambda variables. *)

    (* For pattern-mathing, we declare a datatype for
     * compiler-supported primitives and a function 
     * primitive: lvar -> primitive option *)

    datatype primitive = PLUS_INT | MINUS_INT | MUL_INT | NEG_INT | ABS_INT
                       | LESS_INT | LESSEQ_INT | GREATER_INT | GREATEREQ_INT
                       | PLUS_FLOAT | MINUS_FLOAT | MUL_FLOAT | DIV_FLOAT | NEG_FLOAT | ABS_FLOAT
                       | LESS_FLOAT | LESSEQ_FLOAT | GREATER_FLOAT | GREATEREQ_FLOAT

    type name = Name.name

    type lvar = {name : name,
		 str : string,
		 free : bool ref,
		 inserted : bool ref,
		 use : int ref,
		 prim : primitive option}

    fun new_named_lvar(str : string) : lvar = {name=Name.new(),
					       str=str,
					       free=ref false,
					       inserted=ref false,
					       use=ref 0,
					       prim=NONE}

    fun newLvar() : lvar = new_named_lvar ""

    fun new_prim(str,prim) : lvar = {name=Name.new(),
				     str=str,
				     free=ref false,
				     inserted=ref false,
				     use=ref 0,
				     prim=SOME prim}


    fun pr_lvar ({str="",name,...} : lvar) : string = "v" ^ Int.toString (Name.key name)
      | pr_lvar {str,...} = str

    fun pr_lvar' ({str="",name,...} : lvar) : string = "v_" ^ Int.toString (Name.key name)
      | pr_lvar' {str,name,...} = str ^ "_" ^ Int.toString (Name.key name)

    fun name ({name,...} : lvar) : name = name

    fun key lv = Name.key (name lv)

    fun leq(lv1,lv2) = key lv1 <= key lv2
    fun lt(lv1,lv2) = key lv1 < key lv2
    fun eq(lv1,lv2) = key lv1 = key lv2

    fun usage ({use,...} : lvar) = use
    fun reset_use lv = usage lv := 0
    fun incr_use lv = usage lv := (!(usage lv) + 1)
    fun decr_use lv = usage lv := (!(usage lv) - 1)
    fun zero_use lv = !(usage lv) = 0
    fun one_use lv = !(usage lv) = 1

    fun match(lv1,lv2) = Name.match(name lv1,name lv2)

    (* ------------------------------------ 
     * Compiler-supported primitives
     * ------------------------------------ *)

    val plus_int_lvar: lvar = new_prim("plus_int", PLUS_INT)         (* integer operations *)
    val minus_int_lvar: lvar = new_prim("minus_int", MINUS_INT)
    val mul_int_lvar: lvar = new_prim("mul_int", MUL_INT)
    val negint_lvar: lvar = new_prim("neg_int", NEG_INT)
    val absint_lvar: lvar = new_prim("abs_int", ABS_INT)
    val less_int_lvar: lvar = new_prim("less_int", LESS_INT)
    val lesseq_int_lvar: lvar = new_prim("lesseq_int", LESSEQ_INT)
    val greater_int_lvar: lvar = new_prim("greater_int", GREATER_INT)
    val greatereq_int_lvar: lvar = new_prim("greatereq_int", GREATEREQ_INT)

    val plus_float_lvar: lvar = new_prim("plus_float", PLUS_FLOAT)         (* real operations *)
    val minus_float_lvar: lvar = new_prim("minus_float", MINUS_FLOAT)
    val mul_float_lvar: lvar = new_prim("mul_float", MUL_FLOAT)
    val div_float_lvar: lvar = new_prim("div_float", DIV_FLOAT)
    val negfloat_lvar: lvar = new_prim("neg_float", NEG_FLOAT)
    val absfloat_lvar: lvar = new_prim("abs_float", ABS_FLOAT)
    val less_float_lvar: lvar = new_prim("less_float", LESS_FLOAT)
    val lesseq_float_lvar: lvar = new_prim("lesseq_float", LESSEQ_FLOAT)
    val greater_float_lvar: lvar = new_prim("greater_float", GREATER_FLOAT)
    val greatereq_float_lvar: lvar = new_prim("greatereq_float", GREATEREQ_FLOAT)

    val wild_card : lvar (* used in LineStmt/SubstAndSimplify *)
      = newLvar()

    fun primitive ({prim,...}: lvar) : primitive option = prim

    fun is_free ({free,...} : lvar) = free
    fun is_inserted ({inserted,...} : lvar) = inserted

    structure QD : QUASI_DOM =
      struct
	type dom = lvar
	type name = Name.name
	val name = name
	val pp = pr_lvar
      end
(*
    structure Map = EqFinMap(structure Report = Report
			     structure PP = PP
			     type dom = lvar
			     val eq = eq)
*)
    structure Map = QuasiMap(structure IntFinMap = IntFinMap
			     structure Name = Name
			     structure Crash = Crash
			     structure PP = PP
			     structure Report = Report
			     structure QD = QD)

    (* For the KAM machine *)
    val env_lvar = new_named_lvar("env")
    val notused_lvar = new_named_lvar("notused")

  end;


(***********************************************************************
  Applicative representation of finite sets of naturals, 1993-01-03
  sestoft@dina.kvl.dk
***********************************************************************)

functor Lvarset(structure Lvars : LVARS) : LVARSET = 
struct 

  val xorb = Word.xorb
  val lshift = Word.<<
  val andb = Word.andb
  val notb = Word.notb
  val rshift = Word.>>
  val orb = Word.orb

    type lvar = Lvars.lvar

    datatype lvarset = 
	LF 
      | BR of lvar option * lvarset * lvarset

    fun sing (0w0,lvar) = BR(SOME lvar, LF, LF)
      | sing (n,lvar) = if andb(n,0w1) <> 0w0 then
	                BR(NONE, sing(rshift(n,0w1),lvar), LF)
		 else
		     BR(NONE, LF, sing(rshift(n,0w1) - 0w1, lvar))

    fun singleton lvar = sing (Word.fromInt(Lvars.key lvar),lvar)
	
    fun cardinality LF             = 0
      | cardinality (BR(b, t1, t2)) = 
          case b of SOME _ => 1 + cardinality t1 + cardinality t2
          | NONE => cardinality t1 + cardinality t2

    fun mkBR (NONE, LF, LF) = LF
      | mkBR (b, t1, t2) = BR(b, t1, t2)
	
    infix orElse
    fun _ orElse (b2 as SOME _) = b2
      | (b1 as SOME _) orElse _ = b1
      | _ orElse _ = NONE

    fun union (LF, ns2) = ns2
      | union (ns1, LF) = ns1
      | union (BR(b1, t11, t12), BR(b2, t21, t22)) =
	BR(b1 orElse b2, union(t11, t21), union(t12, t22))
	
    fun add (set,lvar) = union(set, singleton lvar)

    infix andAlso
    fun (SOME _) andAlso (b2 as SOME _) = b2
      | _ andAlso _ = NONE

    fun intersection (LF, ns2) = LF
      | intersection (ns1, LF) = LF
      | intersection (BR(b1, t11, t12), BR(b2, t21, t22)) =
	mkBR(b1 andAlso b2, intersection(t11, t21), intersection(t12, t22))
	

    fun difference (LF, ns2) = LF
      | difference (ns1, LF) = ns1
      | difference (BR(b1, t11, t12), BR(SOME _, t21, t22)) =
        	mkBR(NONE, difference(t11, t21), difference(t12, t22))
      | difference (BR(b1, t11, t12), BR(NONE, t21, t22)) =
          	mkBR(b1, difference(t11, t21), difference(t12, t22))
		  
    fun delete (is, i) = difference(is, singleton i)

    fun present(SOME _) = true
      | present NONE = false

    fun disjoint (LF, ns2) = true
      | disjoint (ns1, LF) = true
      | disjoint (BR(b1, t11, t12), BR(b2, t21, t22)) =
	not (present b1 andalso present b2) 
	andalso disjoint(t11, t21) 
	andalso disjoint (t12, t22)  

(*  fun member (i, is) = not(disjoint(is, singleton i)) *)

    fun member (lvar, is) = 
	let fun mem (_, LF)             = false
	      | mem (0w0, BR(b, _, _))     = (case b of SOME _ => true | _ => false)
	      | mem (n, BR(_, ns1, ns2)) =
	        if andb(n,0w1) <> 0w0 then
	             mem(rshift(n,0w1), ns1)
		 else
		     mem(rshift(n,0w1) - 0w1, ns2)
	in mem(Word.fromInt(Lvars.key lvar), is) end

    fun lvarsetof []      = LF
      | lvarsetof (x::xs) = add(lvarsetof xs, x)

    fun foldset f (e, t) =
	let fun sl (n, d, LF, a)                 = a
	      | sl (n, d, BR(b, LF, LF), a) = 
                (case b of SOME lvar => f(a,lvar) | _ => a)
	      | sl (n, d, BR(b, t1,    LF), a) = 
		sl(n+d, 2*d, t1,(case b of SOME lvar => f(a,lvar) | _ => a) )
	      | sl (n, d, BR(b, t1,    t2), a)    = 
		sl(n+d, 2*d, t1, 
		   sl(n+2*d, 2*d, t2, (case b of SOME lvar => f(a,lvar) | _ => a)))
	in sl(0, 1, t, e) end

    fun mapset f t = foldset (fn (a,i) => f i :: a) ([], t)

    fun members t = foldset (fn (a,i) => i :: a) ([], t)

    fun findLvar (pred: lvar -> '_a option) lvarset = 
      let exception Found of (lvar * '_a)option
          fun search LF = ()
            | search (BR(SOME lvar, set1, set2)) =
               (case pred lvar of
                  SOME x => raise Found(SOME(lvar,x))
                | NONE => (search set1; search set2)
               )
            | search (BR(NONE, set1, set2)) = (search set1; search set2)
      in
        (search lvarset; NONE) handle Found result => result
      end
                    
  val empty = LF                

end
