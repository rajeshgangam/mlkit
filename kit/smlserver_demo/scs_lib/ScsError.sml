(* Error handling, i.e. sending emails to systemadministrator when
errors happens. Should be extended with database and only a few emails
sent *)

signature SCS_ERROR =
  sig
    val raiseError : quot -> 'a
    val logError   : quot -> unit
    val emailError : quot -> unit
    val panic      : quot -> 'a
    val panic'	   : quot -> quot -> 'a
    val valOf      : 'a option -> 'a

    (* [valOfMsg msg v_opt] returns the msg to the user and no error
        is logged if v_opt is NONE; otherwise returns the value v
        where SOME v = v_opt *)
    val valOfMsg   : quot -> 'a option -> 'a

    (* [wrapPanic f a] applies f a and returns the result. If an
        exception is raised then the web-service fails with a system
        error page. *)
    val wrapPanic : ('a -> 'b) -> 'a -> 'b

    (* [wrapPanic' msg f a] applies f a and returns the result. If an
        exception is raised then the web-service fails with a system
        error page including the message msg. *)
    val wrapPanic' : quot -> ('a -> 'b) -> 'a -> 'b

    (* [wrapOpt f a] applies f a and returns SOME (result). If an
        exception is raised then NONE is returned. No error is logged
        or mailed. This is not a panic error. *)
    val wrapOpt   : ('a -> 'b) -> 'a -> 'b option

    (* [wrapMsg msg f a] similar to wrapPanic except that msg is
       shown to the user and no error is logged or emailed. This is 
       not a panic error.*)
    val wrapMsg   : quot -> ('a -> 'b) -> 'a -> 'b

    (* [log msg] writes msg to the serverlog *)
    val log : string -> unit
  end

structure ScsError :> SCS_ERROR =
  struct 
    fun panic' a b = raise Fail "not implemented"
    fun logError emsg = Ns.log (Ns.Error, Quot.toString emsg)

    fun raiseError emsg = ( logError emsg; raise (Fail (Quot.toString emsg)) )

    fun emailError emsg = Ns.Mail.send {
      to=ScsConfig.scs_site_adm_email(),
      from=ScsConfig.scs_site_adm_email(),
      subject="ScsPanic",body=Quot.toString emsg
    }

    fun panic' msg emsg = 
      let
	val emsg = `script: ^(Ns.Conn.location())^(Ns.Conn.url()).
	  ` ^^ emsg
	val title = case ScsLogin.user_lang() of
	    ScsLang.en => "System Error"
	  | ScsLang.da => "Systemfejl"
      in
	(logError emsg;
	 emailError emsg;
	 ScsPage.returnPg title msg;
	 Ns.exit())
      end

    fun panic emsg = 
      let
        val msg = 
	  case ScsLogin.user_lang() of
	    ScsLang.en => `
		 It seems that the system can't complete your request.<p>
		 This is probably our fault. The system administrator has been
		 notified.<p>
		 Please try again later.`
	 | ScsLang.da => `
	     Vi kan desv�rre ikke fuldf�re din foresp�rgsel.<p>
	     Dette er sandsynligvis vores fejl. Vores systemadministrator 
	     er blevet informeret om problemt.<p>
	     Du m� meget gerne pr�ve igen senere.`
      in
        panic' msg emsg
      end


    fun valOf NONE     = panic `valOf(NONE)`
      | valOf (SOME v) = v

    fun valOfMsg msg NONE     = ( ScsPage.returnPg "" msg ; Ns.exit() )
      | valOfMsg msg (SOME v) = v

    fun wrapPanic' msg f a = f a 
      handle 
          Fail s => panic' msg (`Fail raised: ^s`)
	| X      => panic' msg `wrapPanic: some error happended: ^(General.exnMessage X)`

    fun wrapPanic f a = f a 
      handle 
          Fail s => panic (`Fail raised: ^s`)
	| X      => panic `wrapPanic: some error happended: ^(General.exnMessage X)`

    fun wrapOpt f a = SOME(f a)
      handle _ => NONE

    fun wrapMsg msg f a = f a
      handle _ => ( ScsPage.returnPg "" msg ; Ns.exit() )

    fun log msg = Ns.log (Ns.Notice, msg)

  end
