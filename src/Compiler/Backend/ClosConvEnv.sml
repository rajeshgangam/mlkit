
functor ClosConvEnv(structure Lvars : LVARS
		    structure Con : CON
		    structure Excon : EXCON
		    structure Effect : EFFECT
		    structure MulExp : MUL_EXP
		    structure RegvarFinMap : MONO_FINMAP
		    structure PhysSizeInf : PHYS_SIZE_INF
		      sharing type RegvarFinMap.dom 
			= Effect.effect 
			= Effect.place 
			= MulExp.place 
			= PhysSizeInf.place
		    structure Labels : ADDRESS_LABELS
		    structure BI : BACKEND_INFO
                      sharing type BI.label = Labels.label
		    structure PP : PRETTYPRINT
		      sharing type PP.StringTree
			= RegvarFinMap.StringTree
			= Effect.StringTree
			= Lvars.Map.StringTree
			= Con.Map.StringTree
			= Excon.Map.StringTree
		    structure Crash : CRASH) :  CLOS_CONV_ENV =
  struct

    structure LvarFinMap = Lvars.Map
    structure ConFinMap = Con.Map
    structure ExconFinMap = Excon.Map

    fun die s = Crash.impossible("ClosConvEnv."^s)

    type lvar   = Lvars.lvar
    type place  = MulExp.place
    type con    = Con.con
    type excon  = Excon.excon
    type offset = int
    type phsize = PhysSizeInf.phsize
    type label  = Labels.label

    (*************************)
    (* Environment Datatypes *)
    (*************************)
    datatype con_kind =     (* the integer is the index in the datatype 0,... *)
        ENUM of int
      | UB_NULLARY of int
      | UB_UNARY of int
      | B_NULLARY of int
      | B_UNARY of int

    datatype arity_excon =
        NULLARY_EXCON
      | UNARY_EXCON

    datatype access_type =
        LVAR of lvar                            (* Variable                                  *)
      | RVAR of place                           (* Region variable                           *)
      | DROPPED_RVAR of place                   (* Dropped region variable                   *)
      | SELECT of lvar * int                    (* Select from closure or region vector      *)
      | LABEL of label                          (* Global declared variable                  *)
      | FIX of label * access_type option * int (* Label is code pointer, access_type is the *)
                                                (* shared closure and int is size of closure *)
                 * (place * phsize) list        (* for region profiling graph *)

    datatype rho_kind =
        FF (* Rho is formal and finite *)
      | FI (* Rho is formal and infinite *)
      | LF (* Rho is letregion bound and finite *)
      | LI (* Rho is letregion bound and infinite *)

    type ConEnv     = con_kind ConFinMap.map
    type VarEnv     = access_type LvarFinMap.map
    type ExconEnv   = (access_type * arity_excon) ExconFinMap.map
    type RhoEnv     = access_type RegvarFinMap.map
    type RhoKindEnv = rho_kind RegvarFinMap.map
    type env = {ConEnv    : ConEnv,
		VarEnv    : VarEnv,
		ExconEnv  : ExconEnv,
		RhoEnv    : RhoEnv,
		RhoKindEnv: RhoKindEnv}

    fun labelsEnv (labs : (label list * label list) -> access_type -> (label list * label list))
      {ConEnv: ConEnv, VarEnv: VarEnv,
       ExconEnv: ExconEnv, RhoEnv: RhoEnv,
       RhoKindEnv: RhoKindEnv} =
      let fun labs' (a,b) = labs b a 
	val acc : label list * label list = (nil,nil)
        val acc = LvarFinMap.fold (fn (a,b) => labs b a) acc VarEnv
        val acc = ExconFinMap.fold (fn ((a,_),b) => labs b a) acc ExconEnv
        val acc = RegvarFinMap.fold (fn (a,b) => labs b a) acc RhoEnv
      in acc
      end
    

    val initialConEnv  : ConEnv = ConFinMap.fromList
      (* Potential representations. The integer denotes the index of nullary/unary
       * constructors in the datatype. The actual tags are computed later. *)
      [(Con.con_FALSE, ENUM 0),         (* first nullary constructor *)
       (Con.con_TRUE, ENUM 1),          (* second nullary constructor *)
       (Con.con_NIL, UB_NULLARY 0),     (* first nullary constructor *)
       (Con.con_CONS, UB_UNARY 0)]      (* first unary constructor *)
    val initialVarEnv : VarEnv = LvarFinMap.empty
    val initialExconEnv: ExconEnv = ExconFinMap.fromList
      [(Excon.ex_DIV, (LABEL(BI.exn_DIV_lab),NULLARY_EXCON)),
       (Excon.ex_MATCH, (LABEL(BI.exn_MATCH_lab),NULLARY_EXCON)),
       (Excon.ex_BIND, (LABEL(BI.exn_BIND_lab),NULLARY_EXCON)),
       (Excon.ex_OVERFLOW, (LABEL(BI.exn_OVERFLOW_lab),NULLARY_EXCON))]
    val initialRhoEnv : RhoEnv = RegvarFinMap.fromList
      [(Effect.toplevel_region_withtype_top,LABEL(BI.toplevel_region_withtype_top_lab)),
       (Effect.toplevel_region_withtype_bot,   (* arbitrary binding, but some binding
                                                  is required, since DropRegions may 
                                                  leave a region with type bot in
                                                  the expression which CompLamb takes
                                                  as input (mads, Nov 16 1997)
                                               *)
        LABEL(BI.toplevel_region_withtype_bot_lab)),
       (Effect.toplevel_region_withtype_string, LABEL(BI.toplevel_region_withtype_string_lab)),
       (Effect.toplevel_region_withtype_real, LABEL(BI.toplevel_region_withtype_real_lab))]
    val initialRhoKindEnv : RhoKindEnv = RegvarFinMap.fromList
      [(Effect.toplevel_region_withtype_top,LI),
       (Effect.toplevel_region_withtype_bot,LI), (* arbitrary binding, but some binding
                                                    is required, since DropRegions may 
						    leave a region with type bot in
						    the expression which CompLamb takes
						    as input (mads, Nov 16 1997) *)
       (Effect.toplevel_region_withtype_string, LI),
       (Effect.toplevel_region_withtype_real, LI)]

    val initialEnv = {ConEnv     = initialConEnv,
		      VarEnv     = initialVarEnv,
		      ExconEnv   = initialExconEnv,
		      RhoEnv     = initialRhoEnv,
		      RhoKindEnv = initialRhoKindEnv}

    fun plus ({ConEnv,VarEnv,ExconEnv,RhoEnv,RhoKindEnv},
	      {ConEnv=ConEnv',VarEnv=VarEnv',ExconEnv=ExconEnv',RhoEnv=RhoEnv',RhoKindEnv=RhoKindEnv'}) =
      {ConEnv     = ConFinMap.plus(ConEnv,ConEnv'),
       VarEnv     = LvarFinMap.plus(VarEnv,VarEnv'),
       ExconEnv   = ExconFinMap.plus(ExconEnv,ExconEnv'),
       RhoEnv     = RegvarFinMap.plus(RhoEnv,RhoEnv'),
       RhoKindEnv = RegvarFinMap.plus(RhoKindEnv,RhoKindEnv')}

    fun declareCon (con,con_kind,{ConEnv,VarEnv,ExconEnv,RhoEnv,RhoKindEnv}) =
      {ConEnv     = ConFinMap.add(con,con_kind,ConEnv),
       VarEnv     = VarEnv,
       ExconEnv   = ExconEnv,
       RhoEnv     = RhoEnv,
       RhoKindEnv = RhoKindEnv}

    fun declareLvar (lvar,access_type,{ConEnv,VarEnv,ExconEnv,RhoEnv,RhoKindEnv}) =
      {ConEnv     = ConEnv,
       VarEnv     = LvarFinMap.add(lvar,access_type,VarEnv),
       ExconEnv   = ExconEnv,
       RhoEnv     = RhoEnv,
       RhoKindEnv = RhoKindEnv}

    fun declareExcon (excon,(access_type,arity_excon),{ConEnv,VarEnv,ExconEnv,RhoEnv,RhoKindEnv}) =
      {ConEnv     = ConEnv,
       VarEnv     = VarEnv,
       ExconEnv   = ExconFinMap.add(excon,(access_type,arity_excon),ExconEnv),
       RhoEnv     = RhoEnv,
       RhoKindEnv = RhoKindEnv}

    fun declareRho (place,access_type,{ConEnv,VarEnv,ExconEnv,RhoEnv,RhoKindEnv}) =
      {ConEnv     = ConEnv,
       VarEnv     = VarEnv,
       ExconEnv   = ExconEnv,
       RhoEnv     = RegvarFinMap.add(place,access_type,RhoEnv),
       RhoKindEnv = RhoKindEnv}

    fun declareRhoKind (place,rho_kind,{ConEnv,VarEnv,ExconEnv,RhoEnv,RhoKindEnv}) =
      {ConEnv     = ConEnv,
       VarEnv     = VarEnv,
       ExconEnv   = ExconEnv,
       RhoEnv     = RhoEnv,
       RhoKindEnv = RegvarFinMap.add(place,rho_kind,RhoKindEnv)}

    fun lookupCon ({ConEnv,...} : env) con = 
      case ConFinMap.lookup ConEnv con of
	SOME con_kind => con_kind
      | NONE  => die ("lookupCon(" ^ (Con.pr_con con) ^ ")")

    fun lookupVar ({VarEnv,...} : env) lvar = 
      case LvarFinMap.lookup VarEnv lvar of
	SOME access_type => access_type
      | NONE  => die ("lookupVar(" ^ (Lvars.pr_lvar lvar) ^ ")")

    fun lookupVarOpt ({VarEnv,...} : env) lvar = LvarFinMap.lookup VarEnv lvar

    fun lookupExcon ({ExconEnv,...} : env) excon =
      case ExconFinMap.lookup ExconEnv excon of
	SOME (access_type,arity_excon) => access_type
      | NONE  => die ("lookupExcon(" ^ (Excon.pr_excon excon) ^ ")")

    fun lookupExconOpt ({ExconEnv,...} : env) excon = 
      case ExconFinMap.lookup ExconEnv excon of
	SOME (access_type,arity_excon) => SOME access_type
      | NONE => NONE

    fun lookupExconArity ({ExconEnv,...} : env) excon =
      case ExconFinMap.lookup ExconEnv excon of
	SOME (access_type,arity_excon) => arity_excon
      | NONE  => die ("lookupExconArity(" ^ (Excon.pr_excon excon) ^ ")")

    fun lookupRho ({RhoEnv,...} : env) place =
      case RegvarFinMap.lookup RhoEnv place of
	SOME access_type => access_type
      | NONE  => die ("lookupRho(" ^ (PP.flatten1(Effect.layout_effect place)) ^ ")")

    fun lookupRhoOpt ({RhoEnv,...} : env) place = RegvarFinMap.lookup RhoEnv place

    fun lookupRhoKind ({RhoKindEnv,...} : env) place =
      case RegvarFinMap.lookup RhoKindEnv place of
	SOME rho_kind => rho_kind
      | NONE  => die ("lookupRhoKind(" ^ (PP.flatten1(Effect.layout_effect place)) ^ ")")

    (**********************************)
    (* Closure Conversion Environment *)
    (**********************************)
    val empty : env = {ConEnv     = ConFinMap.empty,
		       VarEnv     = LvarFinMap.empty,
		       ExconEnv   = ExconFinMap.empty,
		       RhoEnv     = RegvarFinMap.empty,
		       RhoKindEnv = RegvarFinMap.empty}

    (* --------------------------------------------------------------------- *)
    (*                     Enrichment and restriction                       *)
    (* --------------------------------------------------------------------- *)

    fun acc_type_eq(LABEL lab1,LABEL lab2) = Labels.eq(lab1,lab2)
      | acc_type_eq(FIX(lab1,SOME acc_ty1,i1,_),FIX(lab2,SOME acc_ty2,i2,_)) = Labels.eq(lab1,lab2) andalso acc_type_eq(acc_ty1,acc_ty2)
      | acc_type_eq(FIX(lab1,NONE,i1,_),FIX(lab2,NONE,i2,_)) = Labels.eq(lab1,lab2)
      | acc_type_eq(LABEL _,FIX _) = false
      | acc_type_eq(FIX _,LABEL _) = false
      | acc_type_eq _ = die "acc_type_eq"

    fun match_acc_type(LABEL lab1,LABEL lab2) = Labels.match(lab1,lab2)
      | match_acc_type(FIX(lab1,SOME acc_ty1,i1,_),FIX(lab2,SOME acc_ty2,i2,_)) = (Labels.match(lab1,lab2);match_acc_type(acc_ty1,acc_ty2))
      | match_acc_type(FIX(lab1,NONE,i1,_),FIX(lab2,NONE,i2,_)) = Labels.match(lab1,lab2)
      | match_acc_type(LABEL _,FIX _) = ()
      | match_acc_type(FIX _,LABEL _) = ()
      | match_acc_type _ = die "match_acc_type"

    fun enrich({ConEnv=ConEnv0,VarEnv=VarEnv0,ExconEnv=ExconEnv0,RhoEnv=RhoEnv0,RhoKindEnv=RhoKindEnv0},
	       {ConEnv,VarEnv,ExconEnv,RhoEnv,RhoKindEnv}) =
      ConFinMap.enrich (op =) (ConEnv0,ConEnv) andalso
      ExconFinMap.enrich (fn ((e1,a1:arity_excon),(e2,a2)) => acc_type_eq(e1,e2) andalso a1=a2) (ExconEnv0,ExconEnv) andalso (*!!!*)
      LvarFinMap.enrich acc_type_eq (VarEnv0,VarEnv)
	
    fun restrict_con_env(ConEnv,cons) = ConFinMap.restrict(Con.pr_con,ConEnv,cons)
      handle ConFinMap.Restrict s => die("restrict_con_env: " ^ s ^ " not found")

    fun restrict_excon_env(ExconEnv,excons) = ExconFinMap.restrict(Excon.pr_excon,ExconEnv,excons)
      handle ExconFinMap.Restrict s => die("restrict_excon_env: " ^ s ^ " not found")

    fun restrict_var_env(VarEnv,lvars) = LvarFinMap.restrict(Lvars.pr_lvar,VarEnv,lvars)
      handle LvarFinMap.Restrict s => die("restrict_var_env: " ^ s ^ " not found")

    fun restrict({ConEnv,VarEnv,ExconEnv,RhoEnv,RhoKindEnv},{lvars,cons,excons}) =
      {ConEnv=restrict_con_env(ConEnv,cons),
       VarEnv=restrict_var_env(VarEnv,lvars),
       ExconEnv=restrict_excon_env(ExconEnv,excons),
       RhoEnv=RhoEnv,
       RhoKindEnv=RhoKindEnv}

    fun match({ConEnv,VarEnv,ExconEnv,RhoEnv,RhoKindEnv},
	      {ConEnv=ConEnv0,VarEnv=VarEnv0,ExconEnv=ExconEnv0,RhoEnv=RhoEnv0,RhoKindEnv=RhoKindEnv0}) =
      (LvarFinMap.Fold (fn ((lv,acc_ty),m) =>
			case LvarFinMap.lookup VarEnv0 lv
			 of SOME acc_ty0 => match_acc_type(acc_ty,acc_ty0)
			  | NONE => ()) () VarEnv;
       ExconFinMap.Fold (fn ((excon,(acc_ty,_)), m) =>
			 case ExconFinMap.lookup ExconEnv0 excon
			   of SOME (acc_ty0,_)(*!!!*) => match_acc_type(acc_ty,acc_ty0)
			    | NONE => ()) () ExconEnv)

    (* --------------------------------------------------------------------- *)
    (*                          Pretty printing                              *)
    (* --------------------------------------------------------------------- *)

    type StringTree = PP.StringTree
    val rec layoutEnv : env -> StringTree = fn {ConEnv,VarEnv,ExconEnv,RhoEnv,RhoKindEnv} =>
      PP.NODE{start="ClosExpEnv(",finish=")",indent=2,
	      children=[layoutConEnv ConEnv,
			layoutVarEnv VarEnv,
			layoutExconEnv ExconEnv,
			layoutRhoEnv RhoEnv,
			layoutRhoKindEnv RhoKindEnv],
	      childsep=PP.RIGHT ","}

    and layoutConEnv = fn ConEnv =>
      PP.NODE{start="ConEnv = ",finish="",indent=2,childsep=PP.NOSEP,
	      children=[ConFinMap.layoutMap {start="{", eq=" -> ", sep=", ", finish="}"}
			(PP.layoutAtom Con.pr_con)
			layout_con_kind
			ConEnv]}

    and layoutVarEnv = fn VarEnv =>
      PP.NODE{start="VarEnv = ",finish="",indent=2,childsep=PP.NOSEP,
	      children=[LvarFinMap.layoutMap {start="{", eq=" -> ", sep=", ", finish="}"}
			(PP.layoutAtom Lvars.pr_lvar)
			layout_access_type
			VarEnv]}

    and layoutExconEnv = fn ExconEnv =>
      PP.NODE{start="ExconEnv = ",finish="",indent=2,childsep=PP.NOSEP,
	      children=[ExconFinMap.layoutMap {start="{",eq=" -> ", sep=", ", finish="}"}
			(PP.layoutAtom Excon.pr_excon)
			 (fn (acc_type,arity) => PP.LEAF("(" ^ pr_access_type acc_type ^ "," ^ pr_excon_arity arity ^ ")"))
			 ExconEnv]}

    and layoutRhoEnv = fn RhoEnv =>
      PP.NODE{start="RhoEnv = ",finish="",indent=2,childsep=PP.NOSEP,
	      children=[RegvarFinMap.layoutMap {start="{",eq=" -> ", sep=", ", finish="}"}
			(PP.layoutAtom (PP.flatten1 o Effect.layout_effect))
			layout_access_type
			RhoEnv]}

    and layoutRhoKindEnv = fn RhoKindEnv =>
      PP.NODE{start="RhoKindEnv = ",finish="",indent=2,childsep=PP.NOSEP,
	      children=[RegvarFinMap.layoutMap {start="{",eq=" -> ", sep=", ", finish="}"}
			(PP.layoutAtom (PP.flatten1 o Effect.layout_effect))
			layout_rho_kind
			RhoKindEnv]}

   and layout_con_kind =
      fn ENUM i => PP.LEAF ("enum con: " ^ Int.toString i)
       | UB_NULLARY i => PP.LEAF ("unboxed nullary con: " ^ Int.toString i) 
       | B_NULLARY i => PP.LEAF ("boxed nullary con: " ^ Int.toString i) 
       | UB_UNARY i => PP.LEAF ("unboxed unary con: " ^ Int.toString i) 
       | B_UNARY i => PP.LEAF ("boxed unary con: " ^ Int.toString i) 

    and layout_access_type =
      fn LVAR lvar => PP.LEAF(Lvars.pr_lvar lvar)
       | RVAR place => PP.LEAF(PP.flatten1(Effect.layout_effect place))
       | DROPPED_RVAR place => PP.LEAF("D" ^ PP.flatten1(Effect.layout_effect place))
       | SELECT (lvar,i) => PP.LEAF("#" ^ Int.toString i ^ "(" ^ Lvars.pr_lvar lvar ^ ")")
       | LABEL label => PP.LEAF(Labels.pr_label label)
       | FIX (label,SOME(LVAR lvar),size,_) => PP.LEAF("FIX(" ^ Labels.pr_label label ^ "," ^ Lvars.pr_lvar lvar ^ 
						     "," ^ Int.toString size ^ ")")
       | FIX (label,SOME(SELECT(lvar,i)),size,_) => PP.LEAF("FIX(" ^ Labels.pr_label label ^ ",#" ^ 
							  Int.toString i ^ "(" ^ Lvars.pr_lvar lvar ^ ")," ^
							  Int.toString size ^ ")")
       | FIX (label1,SOME(LABEL label2),size,_) => PP.LEAF("FIX(" ^ Labels.pr_label label1 ^ "," ^ 
							 Labels.pr_label label2 ^ 
							 "," ^ Int.toString size ^ ")")
       | FIX (label,NONE,0,_) => PP.LEAF("FIX(" ^ Labels.pr_label label ^ ",empty_clos)")
       | _ => die "layout_access_type"

    and layout_rho_kind =
      fn LI => PP.LEAF("LI")
      | LF => PP.LEAF("LF")
      | FI => PP.LEAF("FI")
      | FF => PP.LEAF("FF")

    and pr_access_type = 
      fn acc_ty => PP.flatten1(layout_access_type acc_ty)

    and pr_excon_arity =
      fn NULLARY_EXCON => "nullary excon"
       | UNARY_EXCON => "unary excon"
  end;

