signature SCS_PRINT =
  sig
    datatype doc_type = LaTeX
    val docTypeToString      : doc_type -> string
    val docTypeFromString    : string -> doc_type
    val allDocTypes          : doc_type list
    val ppAllDocTypes        : unit -> string list

    val allPrinters   : string list

    (* Widgets *)
    val choosePrinter : string -> quot * quot
    val printForm     : string -> string -> string -> string -> doc_type -> quot -> quot

    (* Actual Printing *)
    val printDoc      : string -> string -> string -> string -> doc_type -> string -> string -> Ns.status
  end

structure ScsPrint :> SCS_PRINT =
  struct
    datatype doc_type = LaTeX
    fun docTypeToString LaTeX = "LaTeX"
    fun docTypeFromString doc_type =
      case doc_type of
	"LaTeX" => LaTeX
      | _ => ScsError.panic `ScsPrint.docTypeFromString.doc_type ^doc_type not supported.`
    val allDocTypes = [LaTeX]
    fun ppAllDocTypes() = List.map docTypeToString allDocTypes 

    val allPrinters = ["p152","p177","p177d","p177t","p233","p233d","p233t"]
    (* Generate file which can be printed and previewed. *)
    (* Files are stored in the scs_print_dir directory.  *)
    local
      fun tmpnam (c: int) : string =
	if c > 10 then ScsError.panic `ScsPrint.tmpnam: Can't create temporary file`
	else
	  let val is = Random.rangelist (97,122) (8, Random.newgen())
	    val f = implode (map Char.chr is)
	  in if FileSys.access(f,[]) then tmpnam(c+1)
	     else f
	  end
      val basedir = Ns.Info.pageRoot()^"/"
      val scs_print_dir = "scs_print/"
      fun texfile f = basedir ^ scs_print_dir ^ f ^ ".tex"
      fun psfile f = basedir ^ scs_print_dir ^ f ^ ".ps"
      fun pdffile f = basedir ^ scs_print_dir ^ f ^ ".pdf"
      fun dvifile f = basedir ^ scs_print_dir ^ f ^ ".dvi"
      fun pdfurl f = "/" ^ scs_print_dir ^ f ^ ".pdf"
      fun save_source source filename =
	let
	  val texstream = TextIO.openOut filename
	in
	  TextIO.output (texstream,source);
	  TextIO.closeOut texstream
	end
    in
      fun genTarget doc_type source =
	case doc_type of
	  LaTeX =>
	    let
	      val tmpfile = tmpnam 10
	      val _ = save_source (Quot.toString source) (texfile tmpfile)
	      val cmd = Quot.toString `cd ^scs_print_dir; latex ^(texfile tmpfile); dvips -o ^(psfile tmpfile) ^(dvifile tmpfile); ps2pdf ^(psfile tmpfile) ^(pdffile tmpfile)`
	    in
	      if Process.system cmd = Process.success
		then pdfurl tmpfile
	      else
		ScsError.panic `ScsPrint.genTarget: Can't execute system command: ^cmd`
	    end
      fun printDoc category note on_what_table on_what_id doc_type source printer =
	case doc_type of
	  LaTeX =>
	    let
	      val print_id = Int.toString (Db.seqNextval "scs_print_id_seq")
	      val tmpfile = tmpnam 10 ^ "-" ^ print_id
	      val _ = save_source source (texfile tmpfile)
	      val target_f = (ScsError.valOf (Ns.Info.configGetValueExact 
					      {sectionName="ns/server/"^Ns.Conn.server()^"/SCS",key="scs_print"}))
		                     ^ "/" ^ tmpfile ^ ".pdf"
	      val cmd = Quot.toString `cd ^scs_print_dir; latex ^(texfile tmpfile); dvips -o ^(psfile tmpfile) ^(dvifile tmpfile); lpr -P^printer ^(psfile tmpfile); ps2pdf ^(psfile tmpfile) ^(pdffile tmpfile); mv ^(pdffile tmpfile) ^(target_f)`
	      fun ins_log db =
		let
		  val clob_id = DbClob.insert_fn (Quot.fromString source) db
		in
		  Db.dmlDb (db, `insert into scs_print_log (print_id,user_id,category,clob_id,print_cmd,
							    target_file,doc_type,note,deleted_p,
							    on_what_table, on_what_id, time_stamp)
			    values (^(Db.valueList [print_id,Int.toString ScsLogin.user_id,
						    category,clob_id,cmd,tmpfile ^ ".pdf",
						    docTypeToString doc_type,note,"f",
						    on_what_table,on_what_id]),
				    ^(Db.sysdateExp))`)
		end
	    in
	      if Process.system cmd = Process.success
		then (ScsDb.panicDmlTrans ins_log;
		      ScsPage.returnPg "Document Printed" `The document is now sent to printer ^printer.<p>

The document has been filed, however, if there were any problems
printing the document then please <a
href="toggle_deleted.sml?print_id=^(Ns.encodeUrl
print_id)&target_url=^(Ns.encodeUrl ("show_doc.sml?print_id="^print_id))">de-file</a> the
document. You will be returned to the print-screen again.`)
	      else ScsError.panic `ScsPrint.genTarget: Can't execute system command: ^cmd`
	    end

      (* Sould find printers for the user logged in *)
      fun choosePrinter n = (`Choose printer`, ScsWidget.select (List.map (fn p => (p,p)) allPrinters) n)

      fun printForm category note on_what_table on_what_id doc_type source =
	ScsWidget.formBox "/scs/print/scs-print.sml" 
	[("submit", "Print"),("submit","Update Source")] 
	(`You may change the source below and then either print the 
	 changed document or update the preview link.<p>` ^^ 
	 `<a href="^(genTarget doc_type source)">preview</a><br>` ^^
	 (Html.inhidden "doc_type" (docTypeToString doc_type)) ^^
	 (Html.inhidden "category" category) ^^
	 (Html.inhidden "on_what_table" on_what_table) ^^
	 (Html.inhidden "on_what_id" on_what_id) ^^
	 (Html.inhidden "note" note) ^^
	 (ScsWidget.largeTA "source" source) ^^ `<p>` ^^
	 (ScsWidget.oneLine (choosePrinter "printer")))
      end
  end