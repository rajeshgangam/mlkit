signature SCS_FORM_VAR =
  sig
    (* Checking form variables are very important but also 
       tedious, because the same kind of code is written 
       in almost every file. This module overcomes the 
       tedious part by defining several functions that can 
       be used to test form variables throughout a large
       system.

       The idea is that you define a list of form types, 
       corresponding to the values used in forms. For instance, 
       you may have an email type representing all possible
       email-values. For every form type, you define a
       function getFormtype, that takes three arguments, 
         (1) the name of the form-variable holding the value, 
         (2) the name of the field in the form; the user may 
	     be presented an errorpage with more than one 
	     error and it is important that the error message 
	     refer to a given field in the form
         (3) an error container of type errs used to hold 
	     the error messages sent back to the user.
       The type formvar_fn represents the type of 
       functions used to check form variables. The functions
       are named getFormtypeErr.

       When you have checked all the form values, you can 
       call the function any_errors, which returns an 
       error-page if any errors occurred and otherwise 
       proceeds with the remainder of the script. If an 
       error-page is returned, then the script is terminated.

       If you do not want an error page returned to the user
       then use one of the wrapper functions:

         wrapOpt : on success returns SOME v where v is the 
                   form value; otherwise NONE
         wrapExn : raises exception FormVar if it fails to
                   parse the form variable
         wrapPanic: executes a function on fail; this may
                    be used to control system failures. Say,
                    you have a hidden form variable seq_id
                    (a sequence id in the database) and it
                    can't be parsed then the function may
                    log the error, send mail to the system
                    maintainer etc. 
         wrapFail: on failure, a page is returned. The 
                   difference from the getFormtypeErr 
                   functions is that with wrapFail only
                   one error is shown on the error page
                   at the time.
       The file /www/formvar_chk shows how to use the 
       wrap-functions. *)
	
    exception FormVar of string
    type quot = string frag list
    type errs = quot list
    type 'a formvar_fn = string * string * errs -> 'a * errs

    val emptyErr : errs
    val addErr : quot * errs -> errs
    val buildErrMsg : errs -> quot
    val anyErrors : errs -> unit
    val isErrors  : errs -> bool

    val getIntErr      : int formvar_fn
    val getNatErr      : int formvar_fn
    val getRealErr     : real formvar_fn
    val getStringErr   : string formvar_fn
    val getStringLenErr: int -> string formvar_fn
    val getIntRangeErr : int -> int -> int formvar_fn
    val getEmailErr    : string formvar_fn 
    val getNameErr     : string formvar_fn 
    val getAddrErr     : string formvar_fn
    val getLoginErr    : string formvar_fn
    val getPhoneErr    : string formvar_fn
    val getHtmlErr     : string formvar_fn
    val getUrlErr      : string formvar_fn
    val getCprErr      : string formvar_fn
    val getEnumErr     : string list -> string formvar_fn
    val getYesNoErr    : string formvar_fn
    val getDateErr     : Date.date formvar_fn
    val getDateIso     : string formvar_fn
    val getTableName   : string formvar_fn
    val getLangErr     : ScsLang.lang formvar_fn
    val getRegExpErr   : RegExp.regexp formvar_fn
    val getRoleIdErr   : string * errs -> int * errs

    val wrapQQ  : string formvar_fn -> (string * string) formvar_fn
    val wrapOpt : 'a formvar_fn -> (string -> 'a option)
    val wrapMaybe : 'a formvar_fn -> 'a formvar_fn
    val wrapMaybe_nh : 'a -> 'a formvar_fn -> 'a formvar_fn 
    val wrapExn : 'a formvar_fn -> (string -> 'a)
    val wrapFail : 'a formvar_fn -> (string * string -> 'a)
    val wrapPanic : (quot -> 'a) -> 'a formvar_fn -> (string -> 'a)
    val wrapIntAsString : int formvar_fn -> string formvar_fn

    val getStrings : string -> string list

    (* For extensions *)
    val trim : string -> string
    val getErr : 'a -> (string->'a) -> string -> (string->quot) -> (string->bool) -> 'a formvar_fn
  end

structure ScsFormVar :> SCS_FORM_VAR =
  struct
    type quot = string frag list
    type errs = quot list
    type 'a formvar_fn = string * string * errs -> 'a * errs

    val regExpMatch   = RegExp.match   o RegExp.fromString
    val regExpExtract = RegExp.extract o RegExp.fromString

    val % = ScsDict.d ScsLang.en "scs_lib" "ScsFormVar.sml"
    val %% = ScsDict.dl ScsLang.en "scs_lib" "ScsFormVar.sml"

    exception FormVar of string

    val emptyErr : errs = []

    fun addErr (emsg:quot,errs:errs) = emsg :: errs
    fun genErrMsg (f_msg:string,msg:quot) : quot = `^(%"Error in field") ^f_msg. ` ^^ msg
    fun errNoFormVar(f_msg:string,ty:string) : quot = `^(%"Error in field") ^f_msg. ^(%"You must provide a") <b>^ty</b>.`
    fun errTypeMismatch(f_msg:string,ty:string,v:string) : quot = 
      `^(%"Error in field") ^f_msg. ^(%"You must provide a") <b>^ty</b> - <i>^v</i> ^(%"is not a") ^ty.`
    fun errTooLarge(f_msg:string,ty:string,v:string) : quot =
      `^(%"Error in field") ^f_msg. ^(%"The provided") ^ty (<i>^v</i>) ^(%"is too large").`
    fun errTooMany(f_msg:string) : quot =
      `^(%"Error in field") ^f_msg. ^(%"More than one dataitem is provided").`

    fun buildErrMsg (errs: errs) : quot =
      (case ScsLogin.user_lang of
	 ScsLang.en => `
	   We had a problem processing your entry:

	   <ul>` ^^ 
	   Quot.concatFn (fn q => `<li>` ^^ q) (List.rev errs) ^^ `
	   </ul>

	   Please back up using your browser, correct it, and resubmit your entry<p>
	   
	   Thank you.`
	 | ScsLang.da => 
	   let
	     val (problem_string, please_correct) = if List.length errs = 1 then
	       ("en fejl","fejlen") else ("nogle fejl","fejlene")
	   in
	     `Vi har fundet ^problem_string i dine indtastede data:
	     <ul>` ^^ 
	     Quot.concatFn (fn q => `<li>` ^^ q) (List.rev errs) ^^ `
	     </ul>

	     V�r venlig at klikke p� "tilbage"-knappen i din browser, og ret
	     ^please_correct. Derefter kan du indsende dine oplysninger igen<p>
	     P� forh�nd tak.`
	   end)

    fun returnErrorPg (errs: errs) : Ns.status = ScsPage.returnPg (%"Form Error") (buildErrMsg errs)

    fun anyErrors ([]:errs) = ()
      | anyErrors (errs) = (returnErrorPg errs; Ns.exit())

    fun isErrors ([]:errs) = false
      | isErrors (errs) = true

    fun wrapQQ (f : string formvar_fn) : string * string * errs -> (string * string) * errs =
      fn arg =>
      case f arg of
	(v,e) => ((v,Db.qq v),e)

    fun wrapOpt (f : 'a formvar_fn) : string -> 'a option =
      fn fv => 
      case f (fv,"",[]) of
	(v,[]) => SOME v
      | _ => NONE

    fun wrapIntAsString (f : int formvar_fn) =
      (fn (fv,emsg,errs) => 
       case f(fv,emsg,[]) of
	 (i,[]) => (Int.toString i,errs)
	|(_,[e]) => ("",addErr(e,errs))
	| _ => ScsError.panic `ScsFormVar.wrapIntAsString failed on ^fv`)

    fun trim s = Substring.string (Substring.dropr Char.isSpace (Substring.dropl Char.isSpace (Substring.all s)))
    fun wrapMaybe (f : 'a formvar_fn) =
      (fn (fv,emsg,errs) => 
       (case Ns.Conn.formvarAll fv of
	  [] => (case f(fv,emsg,[]) of (v,_) => (v,errs)) (* No formvar => don't report error *)
	| [v] => 
	   (if trim v = "" then
	      (case f(fv,emsg,[]) of (v,_) => (v,errs)) (* Don't report error *)
	    else f(fv,emsg,errs))
	| _ => f(fv,emsg,errs))) (* Multiple formvars => report error *)

    fun wrapMaybe_nh empty_val (f : 'a formvar_fn) =
      (fn (fv,emsg,errs) => 
       (case Ns.Conn.formvarAll fv of
	  [] => (empty_val,errs) (* No formvar => don't report error *)
	| [v] => 
	   (if trim v = "" then
	      (case f(fv,emsg,[]) of (v,_) => (v,errs)) (* Don't report error *)
	    else f(fv,emsg,errs))
	| _ => f(fv,emsg,errs))) (* Multiple formvars => report error *)

    fun wrapExn (f : 'a formvar_fn) : string -> 'a =
      fn fv =>
      case f (fv,fv,[]) of
	(v,[]) => v
      | (_,x::xs) => raise FormVar (Quot.toString x)

    fun wrapFail (f : 'a formvar_fn) : string * string -> 'a =
      fn (fv:string,emsg:string) =>
      case f (fv,emsg,[]) of
	(v,[]) => v
       | (_,errs) => (returnErrorPg errs; Ns.exit())

    fun wrapPanic (f_panic: quot -> 'a) (f : 'a formvar_fn) : string -> 'a =
      fn fv =>
      ((case f (fv,fv,[]) of
	(v,[]) => v
       | (_,x::xs) => f_panic(`^("\n") ^fv : ` ^^ x))
	  handle X => f_panic(`^("\n") ^fv : ^(General.exnMessage X)`))

    local
      fun getErrWithOverflow (empty_val:'a) (ty:string) (chk_fn:string->'a option) =
	fn (fv:string,emsg:string,errs:errs) =>
	(case Ns.Conn.formvarAll fv of
	   [] => (empty_val,addErr(errNoFormVar(emsg,ty),errs))
	 | [""] => (empty_val,addErr(errNoFormVar(emsg,ty),errs))
	 | [v] =>
	     (case chk_fn v of
		SOME v => (v,errs)
	      | NONE => (empty_val, addErr(errTypeMismatch(emsg,ty,v),errs)))
		handle Overflow => (empty_val, addErr(errTooLarge(emsg,ty,v),errs))
	 | _ => (empty_val, addErr(errTooMany emsg,errs)))
    in
      val getIntErr = getErrWithOverflow 0 (%"number")
	(fn v => let val l = explode v
		 in 
		   case l
		     of c::_ => 
		       if Char.isDigit c orelse c = #"-" orelse c = #"~" then
			 (case Int.scan StringCvt.DEC List.getItem l
			    of SOME (n, nil) => SOME n
			  | _ => NONE)
		       else NONE
		   | nil => NONE
		 end handle Fail s => NONE)
      val getNatErr = getErrWithOverflow 0 (%"positive number")
	(fn v => let val l = explode v
		 in 
		   case l
		     of c::_ => 
		       if Char.isDigit c then
			 (case Int.scan StringCvt.DEC List.getItem l
			    of SOME (n, nil) => SOME n
			  | _ => NONE)
		       else NONE
		   | nil => NONE
		 end)
	  
      val getRealErr = getErrWithOverflow 0.0 (%"real")
	(fn v => let val l = explode v
		 in
		   case l
		     of c::_ => 
		       if Char.isDigit c orelse c = #"-" orelse c = #"~" then
			 (case Real.scan List.getItem l
			    of SOME (n, nil) => SOME n
			  | _ => NONE)
		       else NONE
		   | nil => NONE
		 end)

      val getStringErr = getErrWithOverflow "" (%"string") (fn v => if size v = 0 then NONE else SOME v)

      fun getStringLenErr l = getErrWithOverflow "" 
	(%% [(Int.toString l)] "string or it is too long - max. %0 characters")
	(fn v => if size v = 0 orelse size v > l then NONE else SOME v)
    end

    fun getIntRangeErr a b (args as (fv:string,emsg:string,errs:errs)) =
      let
	val (i,errs') = getIntErr args
      in
	if List.length errs = List.length errs' then
	  if a <= i andalso i <= b 
	    then (i,errs)
	  else (0,addErr(genErrMsg(emsg,`^(%"The integer") <i>^(Int.toString i)</i> (%"is not within the valid range")
				   [^(Int.toString a),...,^(Int.toString b)].`),errs))
	else
	  (0,errs')
      end
    
    fun getErr (empty_val:'a) (conv_val:string->'a) (ty:string) (add_fn:string->quot) (chk_fn:string->bool) =
      fn (fv:string,emsg:string,errs:errs) =>
      case Ns.Conn.formvarAll fv of
	[]  => (empty_val,addErr(genErrMsg(emsg,add_fn ((%"You must provide a")^" <b>"^ty^"</b>.")),errs))
      | [""]  => (empty_val,addErr(genErrMsg(emsg,add_fn ((%"You must provide a")^" <b>"^ty^"</b>.")),errs))
      | [v] => 
	  if chk_fn v then
	    (conv_val v,errs)
	  else
	    (empty_val, addErr(genErrMsg(emsg,add_fn ((%"You must provide an valid")^" <b>"^ty^"</b> - <i>" ^ 
						      v ^ "</i> "^(%"is not one"))),
			       errs))
      | _ => (empty_val, addErr(errTooMany emsg,errs))

    local
      val getErr' = getErr "" trim
      fun msgEmail s = 
	(case ScsLogin.user_lang of
	   ScsLang.en => `^s
	     <blockquote>A few examples of valid emails:
	     <ul>
	     <li>login@it-c.dk
	     <li>user@supernet.com
	     <li>FirstLastname@very.big.company.com\n
	     </ul></blockquote>`
	| ScsLang.da => `^s
	     <blockquote>Her er nogle eksempler p� emails:
	     <ul>
	     <li>login@it-c.dk
	     <li>user@supernet.com
	     <li>FirstLastname@very.big.company.com
	     </ul></blockquote>`)
      fun msgName s = 
	(case ScsLogin.user_lang of
	   ScsLang.en => `^s
	     <blockquote>
	     A name may contain the letters from the alphabet including: <b>'</b>, <b>\</b>,<b>-</b>,<b>�</b>,
	     <b>�</b>,<b>�</b>,<b>�</b>,<b>�</b>,<b>�</b>,<b>�</b>,<b>�</b>,<b>�</b>,<b>�</b> and space.
	     </blockquote>`
	 | ScsLang.da => `^s
	     <blockquote>
	     Et navn m� indeholde bogstaver fra alfabetet samt disse tegn: <b>'</b>, <b>\</b>,<b>-</b>,<b>�</b>,
	     <b>�</b>,<b>�</b>,<b>�</b>,<b>�</b>,<b>�</b>,<b>�</b>,<b>�</b>,<b>�</b>,<b>�</b> og mellemrum.
	     </blockquote>`)
      fun msgAddr s = 
	(case ScsLogin.user_lang of
	   ScsLang.en => `^s
	     <blockquote>
	     An address may contain digits, letters from the alphabet including:
	     <b>'</b>, <b>\\ </b>, <b>-</b>, <b>.</b>, <b>:</b> og <b>;</b> og <b>,</b>,
	     <b>�</b>,<b>�</b>,<b>�</b>,<b>�</b>,<b>�</b>,<b>�</b>,<b>�</b>,<b>�</b>
	     </blockquote>`
	 | ScsLang.da => `^s
	     <blockquote>
	     En adresse m� indeholde tal, bogstaver fra alfabetet samt disse tegn: 
	     <b>'</b>, <b>\\ </b>, <b>-</b>, <b>.</b>, <b>:</b> og <b>;</b> og <b>,</b>,
	     <b>�</b>,<b>�</b>,<b>�</b>,<b>�</b>,<b>�</b>,<b>�</b>,<b>�</b>,<b>�</b>
	     </blockquote>`)
      fun msgLogin s = 
	(case ScsLogin.user_lang of
	   ScsLang.en => `^s
	     <blockquote>
	     A login may contain lowercase letters from the alphabet and digits - the first
	     character must not be a digit. Special characters 
	     like <b>�</b>,<b>�</b>,<b>�</b>,<b>;</b>,<b>^^</b>,<b>%</b> are not alowed. 
	     A login must be no more than 10 characters and at least three characters.
	     </blockquote>`
	 | ScsLang.da => `^s
	     <blockquote>
	     Et login m� indeholde bogstaver fra alfabetet og tal - det f�rste tegn m� 
	     ikke v�re et tal. Specialtegn s�som <b>�</b>,<b>�</b>,<b>�</b>,<b>;</b>,
	     <b>^^</b>,<b>%</b> er ikke tilladt.
	     Derudover skal et login v�re p� mindst tre tegn og h�jst 10 tegn.
	     </blockquote>`)
      fun msgPhone s = 
	(case ScsLogin.user_lang of
	   ScsLang.en => `^s
	     <blockquote>
	     A telephone numer may contain numbers and letters from the alphabet 
	     including <b>-</b>, <b>,</b> and <b>.</b>.
	     </blockquote>`
	 | ScsLang.da => `^s
	     <blockquote>
	     Et telefonnummer m� indeholde tal og bogstaver fra alfabetet
	     samt <b>-</b>, <b>,</b> and <b>.</b>.
	     </blockquote>`)
      fun msgHTML s = 	
	(case ScsLogin.user_lang of
	   ScsLang.en => `^s
	     <blockquote>
	     You may use the following HTML tags in your text: Not implemented yet.
	     </blokcquote>`
	 | ScsLang.da => `^s
	     <blockquote>
	     Det er tilladt at anvende f�lgende HTML tags i din tekst: Desv�rre ikke implementeret.
	     </blokcquote>`)
      fun msgURL s = 
	(case ScsLogin.user_lang of
	   ScsLang.en => `^s
	     <blockquote>
	     <a href="/url_desc.sml">URL (Uniform Resource Locator)</a> - 
	     we only support the <code>http://</code> type (e.g., <code>http://www.it.edu</code>).
	     </blockquote>`
	 | ScsLang.da => `^s
	     <blockquote>
	     <a href="/url_desc.sml">URL (Uniform Resource Locator)</a> - 
	     vi supporterer kun <code>http://</code> type (f.eks. <code>http://www.it-c.dk</code>).
	     </blockquote>`)
      fun msgCpr s = 
	(case ScsLogin.user_lang of
	   ScsLang.en => `^s
	     <blockquote>
	     If you hold a Danish CPR-number, then the format is:
	     <code>DDMMYYYY-TTTT</code>, where <code>TTTT</code> are four numbers, for instance
	     <code>291270-1234</code>. <p>
	  
	     We also perform a <a
	     href="http://www.cpr.dk/modulus11_beregn.htm">modulus 11
	     check (text is in Danish)</a>.<p>

	     If you do not hold a Danish CPR-nummer, then write day,
	     month and year of you birthday in the order given above
	     (e.g., <code>DDMMYY</code>). Thereafter write the two first
	     letters in your (first) firstname and the first letter in
	     your (last) surname. In the last field write 2 if you are a
	     female and 1 if your are a male. <p>

	     A male, with no Danish CPR-number named Claes Anders Fredrik
	     Moren, born August 31, 1975 writes: <b>310875-CLM1</b>.
	     
	     </blockquote>`
	 | ScsLang.da => `^s
	     <blockquote>
	     Hvis du har et dansk CPR-nummer, s� er formatet:
	     DDMMYYYY-TTTT, hvor TTTT er fire tal, eksempelvis
	     291270-1234. <p>

	     Derudover udf�res 
	     <a href="http://www.cpr.dk/modulus11_beregn.htm">modulus 11 check</a>.<p>

	     Hvis du ikke har et dansk CPR-nummer, skrives dato,
	     m�ned og �r for din f�dselsdag i den angivne
	     r�kkef�lge i de seks felter f�r stregen. I de
	     f�rste 3 felter efter stregen skrives de to f�rste
	     bogstaver i dit (f�rste) fornavn efterfulgt af det
	     f�rste bogstav i dit (sidste) efternavn. I den
	     sidste rubrik angives dit k�n med 1 for mand og 2
	     for kvinde.  <p> 

	     En mand, uden dansk CPR-nummer,
	     ved navn Claes Anders Fredrik Moren, f�dt den
	     31. august 1975, skal skrive: <b>310875-CLM1</b>.
	     </blockquote>`)
      fun msgEnum enums s =
	(case ScsLogin.user_lang of
	   ScsLang.en => `^s
	     You must choose among the following enumerations:
	     <blockquote>
	     ^(String.concatWith "," enums)
	     </blockquote>`
	| ScsLang.da => `^s
	     Du skal indtaste en af de f�lgende v�rdier:
	     <blockquote>
	     ^(String.concatWith "," enums)
	     </blockquote>`)
      fun msgDateIso s = 
	(case ScsLogin.user_lang of
	   ScsLang.en => `^s
	     <blockquote>
	     You must type a <b>date</b> in the ISO format <code>YYYY-MM-DD</code> (e.g., 2001-10-25).
	     </blockquote>`
	| ScsLang.da => `^s
	     Du skal indtaste en <b>dato</b> i ISO formatet, dvs. <code>YYYY-MM-DD</code> (f.eks. 2001-10-25).
	     </blockquote>`)
      fun msgDate s = 
	(case ScsLogin.user_lang of
	   ScsLang.en => `^s
	     <blockquote>
	     You must type a <b>date</b> in either the Danish format <code>DD/MM-YYYY</code> (e.g., 25/01-2001) or 
	     the ISO format <code>YYYY-MM-DD</code> (e.g., 2001-01-25).
	     </blockquote>`
	| ScsLang.da => `^s
	     Du skal indtaste en <b>dato</b> enten i formatet <code>DD/MM-YYYY</code> (f.eks. 25/01-2001) eller
	     i formatet <code>YYYY-MM-DD</code> (f.eks. 2001-01-25).
	     </blockquote>`)
      fun msgTableName s = 
	(case ScsLogin.user_lang of
	   ScsLang.en => `^s
	     <blockquote>
	     You have not specified a valid <b>table name</b>
	     </blockquote>`
	| ScsLang.da => `^s
	     Du har ikke specificeret et korrekt <b>tabelnavn</b>.
	     </blockquote>`)
      fun msgRegExp s = 
	(case ScsLogin.user_lang of
	   ScsLang.en => `^s
	     <blockquote>
	     You must type a <b>regular expression</b> defined as follows.<p>
	     <pre>
 Grammar for regular expressions (RegExp):

    re ::= re1 "|" re2         re1 or re2
        |  re1 re2             re1 followed by re2
        |  re "*"              re repeated zero or more times
        |  re "+"              re repeated one or more times
        |  re "?"              re zero or one time
        |  "(" re ")"          re
        |  c                   specific character
        |  "\" c               escaped character; c is one of |,*,+,?,(,),[,],$,.,\,t,n,v,f,r
        |  "[" class "]"       character class
        |  "[^^" class "]"      negated character class
        |  $                   empty string
        |  .                   any character

    class ::=  c               specific character
           |   "\" c           escaped character; c is one of [,],-,\,t,n,v,f,r
           |   c1 "-" c2       ascii character range
           |                   empty class 
           |   class class     composition
            
 Whitespace is significant.  Special characters can be escaped by \  
</pre>
	     </blockquote>`
	| ScsLang.da => `^s
	     <blockquote>
	     Du skal indtaste et <b>regul�rt udtryk</b> defineret s�ledes.<p>
	     <pre>
 Grammatik for regul�re udtryk (RegExp):

    re ::= re1 "|" re2         re1 eller re2
        |  re1 re2             re1 efterfulgt af re2
        |  re "*"              re gentaget nul eller flere gange
        |  re "+"              re gentaget en eller flere gange
        |  re "?"              re nul eller en gang
        |  "(" re ")"          re
        |  c                   angivet tegn c
        |  "\" c               escaped karakter; c er en af f�lgende: |,*,+,?,(,),[,],$,.,\,t,n,v,f,r
        |  "[" class "]"       tengklasse
        |  "[^^" class "]"      negeret tegnklasse
        |  $                   tom tegnstreng
        |  .                   ethvert tegn

    class ::=  c               angivet tegn
           |   "\" c           escaped tegn, c er en af f�lgende: [,],-,\,t,n,v,f,r
           |   c1 "-" c2       ascii tegn interval
           |                   tom klasse
           |   class class     sammens�tning
            
 Mellemrum har betydning. Tegn escapes ved \  
</pre>
	     </blockquote>`)
      fun msgLang s = msgEnum (ScsLang.all_as_text ScsLogin.user_lang) s

      fun convCpr cpr =
	case String.explode (trim cpr) of
	  d1 :: d2 :: m1 :: m2 :: y1 :: y2 :: (#"-") :: t1 :: t2 :: t3 :: t4 :: [] =>
	    String.implode[d1,d2,m1,m2,y1,y2,t1,t2,t3,t4]
	| d1 :: d2 :: m1 :: m2 :: y1 :: y2 :: t1 :: t2 :: t3 :: t4 :: [] =>
	    String.implode[d1,d2,m1,m2,y1,y2,t1,t2,t3,t4]
	| _ => ScsError.panic `ScsFormVar.convCpr failned on ^cpr`
	  
      fun chkCpr cpr =
	let
	  fun mk_yyyymmdd (d1,d2,m1,m2,y1,y2) =
	    let
	      val yy = Option.valOf(Int.fromString(String.implode [y1,y2]))
	      val mm = Option.valOf(Int.fromString(String.implode [m1,m2]))
	      val dd = Option.valOf(Int.fromString(String.implode [d1,d2]))
	    in
	      if yy < 10 then
		(2000+yy,mm,dd)
	      else
		(1900+yy,mm,dd)
	    end
	  fun chk_modulus11 (c1,c2,c3,c4,c5,c6,c7,c8,c9,c10) =
	    let
	      val sum1 = c1*4 + c2*3 + c3*2 + c4*7 + c5*6 + c6*5 + c7*4 + c8*3 + c9*2 + c10*1
	    in
	      Int.mod(sum1,11) = 0
	    end
	  fun cpr_ok (d1,d2,m1,m2,y1,y2,t1,t2,t3,t4) =
	    let
	      fun c2d ch = Option.valOf(Int.fromString(String.implode [ch]))
	      val (yyyy, mm, dd) = mk_yyyymmdd (d1,d2,m1,m2,y1,y2) 
	      val cpr = String.implode [d1,d2,m1,m2,y1,y2,#"-",t1,t2,t3,t4]
	    in
	      if Char.isDigit t1 andalso Char.isDigit t2 andalso Char.isDigit t3 andalso Char.isDigit t4 then
		let
		  (* DK CPR no *)
		  val (c1,c2,c3,c4,c5,c6,c7,c8,c9,c10) =
		    (c2d d1,c2d d2,c2d m1,c2d m2,c2d y1,c2d y2,c2d t1,c2d t2,c2d t3,c2d t4)
		  val tttt = Option.valOf(Int.fromString(String.implode [t1,t2,t3,t4]))
		in
		  if ScsDate.dateOk (dd,mm,yyyy) andalso chk_modulus11(c1,c2,c3,c4,c5,c6,c7,c8,c9,c10) then 
		    true
		  else
		    false
		end
	      else
		(* NON DK CPR no *)
		if Char.isAlpha t1 andalso Char.isAlpha t2 andalso Char.isAlpha t3 andalso
		  (t4 = (#"1") orelse t4 = (#"2")) andalso
		  ScsDate.dateOk (dd,mm,yyyy) then
		  true
		else
		  false
	    end
	in
	  case String.explode (trim cpr) of
	    d1 :: d2 :: m1 :: m2 :: y1 :: y2 :: (#"-") :: t1 :: t2 :: t3 :: t4 :: [] =>
	      cpr_ok(d1,d2,m1,m2,y1,y2,t1,t2,t3,t4)
	  | d1 :: d2 :: m1 :: m2 :: y1 :: y2 :: t1 :: t2 :: t3 :: t4 :: [] =>
	      cpr_ok(d1,d2,m1,m2,y1,y2,t1,t2,t3,t4)
	  | _ => false
	end
      handle _ => false
      fun chkEnum enums v =
	case List.find (fn enum => v = enum) enums
	  of NONE => false
	| SOME _ => true
      fun dateOk (d,m,y) = ScsDate.dateOk(Option.valOf (Int.fromString d),
					  Option.valOf (Int.fromString m),Option.valOf (Int.fromString y))
      fun genDate (d,m,y) = ScsDate.genDate(Option.valOf (Int.fromString d),
					    Option.valOf (Int.fromString m),Option.valOf (Int.fromString y))
      fun chkDateIso v =
	(case regExpExtract "([0-9][0-9][0-9][0-9])-([0-9][0-9]?)-([0-9][0-9]?)" v of
	   SOME [yyyy,mm,dd] => dateOk(dd,mm,yyyy)
	 | _ => (case regExpExtract "([0-9][0-9][0-9][0-9])([0-9][0-9]?)([0-9][0-9]?)" v of
		   SOME [yyyy,mm,dd] => dateOk(dd,mm,yyyy)
		 | _ => false))
	   handle _ => false      
      fun chkDate v =
	(case regExpExtract "([0-9][0-9]?)/([0-9][0-9]?)-([0-9][0-9][0-9][0-9])" v of
	   SOME [dd,mm,yyyy] => dateOk(dd,mm,yyyy)
	 | _ => (case regExpExtract "([0-9][0-9][0-9][0-9])-([0-9][0-9]?)-([0-9][0-9]?)" v of
		   SOME [yyyy,mm,dd] => dateOk(dd,mm,yyyy)
		 | _ => false))
	   handle _ => false   
      fun convDate v =
	(case regExpExtract "([0-9][0-9]?)/([0-9][0-9]?)-([0-9][0-9][0-9][0-9])" v of
	   SOME [dd,mm,yyyy] => genDate(dd,mm,yyyy)
	 | _ => (case regExpExtract "([0-9][0-9][0-9][0-9])-([0-9][0-9]?)-([0-9][0-9]?)" v of
		   SOME [yyyy,mm,dd] => genDate(dd,mm,yyyy)
		 | _ => ScsError.panic `ScsFormVar.convDate failed on ^v`))
	   handle _ => ScsError.panic `ScsFormVar.convDate failed on ^v`
      fun chkRegExp v = (RegExp.fromString v; true) handle _ => false
      fun chkLang v = (ScsLang.fromString v; true) handle _ => false
    in
      val getEmailErr = getErr' (%"email") msgEmail
	(fn email => regExpMatch "[^@\t ]+@[^@.\t ]+(\\.[^@.\n ]+)+" (trim email)) 
      val getNameErr = getErr' (%"name") msgName (regExpMatch "[a-zA-ZA���a������� '\\-]+")
      val getAddrErr = getErr' (%"address") msgAddr (regExpMatch "[a-zA-Z0-9�������� '\\-.:;,]+")
      val getLoginErr = getErr' (%"login") msgLogin 
	(fn login =>
	 regExpMatch "[a-z][a-z0-9\\-]+" login andalso 
	 String.size login >= 3 andalso String.size login <= 10)
      val getPhoneErr = getErr' (%"phone number") msgPhone (regExpMatch "[a-zA-Z0-9������ '\\-.:;,]+")
      (* getHtml : not implemented yet *)
      val getHtmlErr = getErr' (%"HTML text") msgHTML (fn html => html <> "")
      val getUrlErr =  getErr' (%"URL") msgURL (regExpMatch "http://[0-9a-zA-Z/\\-\\\\._~]+(:[0-9]+)?")
      val getCprErr = getErr "" convCpr (%"cpr number") msgCpr chkCpr
      val getEnumErr = fn enums => getErr' (%"enumeration") (msgEnum enums) (chkEnum enums)
      val getYesNoErr = let val enums = [%"Yes",%"No"] in getErr' (%"Yes/No") (msgEnum enums) (chkEnum ["t","f"]) end
      val getDateIso = getErr' (%"date") msgDateIso chkDateIso
      val getDateErr = getErr (ScsDate.genDate(1,1,1)) convDate (%"date") msgDate chkDate
      val getTableName = getErr' (%"table name") msgTableName (regExpMatch "[a-zA-Z_]+")
      val getLangErr = getErr ScsLang.en ScsLang.fromString (%"language") msgLang chkLang
      val getRegExpErr = getErr (RegExp.fromString "$") RegExp.fromString (%"regular expression") msgRegExp chkRegExp
    end

    fun getStrings fv = List.map trim (Ns.Conn.formvarAll fv)

    fun getRoleIdErr (fv,errs) = getIntErr(fv,%"Role id",errs)

  end
