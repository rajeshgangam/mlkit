(* $id$ *)

structure ScsSecurity (*:> SCS_SECURITY*) =
  struct
    fun randomChar () = 
      String.sub 
	( "123456789ABCDEFGHIJKLMNPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz./",
	  Random.range (0,61) (Random.newgen ()))

    (* [xssFilter text] returns a string which is more secure to present to 
	a user. The function should be used to present insecure data to the 
	user.

        leaves the tags
	  <b>, </b>, <br>, </br>, <em>, </em>, <i>, </i>, <li>, </li>, 
	  <ol>, </ol>, <p>, </p>, <tt>, </tt>, <ul>, </ul>

        else converts 
          <	|->	&lt;
	  >	|->	&gt;
          ( 	|->	&#40;
          ) 	|->	&#41;
	  #	|->	&#35;
	  &	|->	&#38;

       Info on XSS (http://www.cgisecurity.com/articles/xss-faq.shtml):
         Converting < and > to &lt; and &gt; is also suggested when it comes 
         to script output. Filtering < and > alone will not solve all cross 
	 site 
         scripting attacks and it is suggested you also attempt to filter out 
         ( and ) by translating them to &#40; and &#41;, 
         and also # and & by translating them to &#35 (#) and &#38 (&). 
     *)
    fun xssFilter (text:string) =
      let
	val ltList = (#"&")::(#"l")::(#"t")::(#";")::[]
        fun parseTag (text,stack:(char list)) = 
          let
            val replaceLT = (rev(ltList @ ((tl o rev) stack))) 
	  in 
            case (Substring.getc text) of
	      SOME(c,rest) => ( case (Char.toLower c) of
		  #"b"  => ( case (Substring.getc rest) of
  	              SOME(c1,rest1) => ( case (Char.toLower c1) of
		          #">"  => ( rest1, c1::c::stack )
		        | #"r"  => ( case (Substring.getc rest1) of
			      SOME(c2,rest2) => ( case c2 of
			        #">"  => ( rest2, c2::c1::c::stack )
			        | other => ( rest2, other::c1::c::replaceLT )
			      )
			      | NONE => ( rest1, c1::c::replaceLT )
                          )
		        | other => ( rest1, other::c::replaceLT )
                      )
 		    | NONE => ( rest, c::replaceLT )
                  )
		| #"e"  => ( case (Substring.getc rest) of
  	              SOME(c1,rest1) => ( case (Char.toLower c1) of
		        #"m"  => ( case (Substring.getc rest1) of
			  SOME(c2,rest2) => ( case c2 of
			    #">"  => ( rest2, c2::c1::c::stack )
			  | other => ( rest2, other::c1::c::replaceLT )
			  )
			| NONE => ( rest1, c1::c::replaceLT )
                        )
		      | other => ( rest1, other::c::replaceLT )
                      )
 		    | NONE => ( rest, c::replaceLT )
                  )
		| #"i"  => ( case (Substring.getc rest) of
  	              SOME(c1,rest1) => ( case c1 of
		        #">"  => ( rest1, c1::c::stack )
		      | other => ( rest1, other::c::replaceLT )
                      )
 		    | NONE => ( rest, c::replaceLT )
		  )
		| #"l"  => ( case (Substring.getc rest) of
  	              SOME(c1,rest1) => ( case (Char.toLower c1) of
		        #"i"  => ( case (Substring.getc rest1) of
			  SOME(c2,rest2) => ( case c2 of
			    #">"  => ( rest2, c2::c1::c::stack )
			  | other => ( rest2, other::c1::c::replaceLT )
			  )
			| NONE => ( rest1, c1::c::replaceLT )
                        )
		      | other => ( rest1, other::c::replaceLT )
                      )
 		    | NONE => ( rest, c::replaceLT )
                  )
		| #"o"  => ( case (Substring.getc rest) of
  	              SOME(c1,rest1) => ( case (Char.toLower c1) of
		        #"l"  => ( case (Substring.getc rest1) of
			  SOME(c2,rest2) => ( case c2 of
			    #">"  => ( rest2, c2::c1::c::stack )
			  | other => ( rest2, other::c1::c::replaceLT )
			  )
			| NONE => ( rest1, c1::c::replaceLT )
                        )
		      | other => ( rest1, other::c::replaceLT )
                      )
 		    | NONE => ( rest, c::replaceLT )
                  )
		| #"p"  => ( case (Substring.getc rest) of
  	              SOME(c1,rest1) => ( case c1 of
		        #">"  => ( rest1, c1::c::stack )
		      | other => ( rest1, other::c::replaceLT )
                      )
 		    | NONE => ( rest, c::replaceLT )
		  )
		| #"t"  =>  ( case (Substring.getc rest) of
  	              SOME(c1,rest1) => ( case (Char.toLower c1) of
		        #"t"  => ( case (Substring.getc rest1) of
			  SOME(c2,rest2) => ( case c2 of
			    #">"  => ( rest2, c2::c1::c::stack )
			  | other => ( rest2, other::c1::c::replaceLT )
			  )
			| NONE => ( rest1, c1::c::replaceLT )
                        )
		      | other => ( rest1, other::c::replaceLT )
                      )
 		    | NONE => ( rest, c::replaceLT )
                  )
		| #"u"  =>  ( case (Substring.getc rest) of
  	              SOME(c1,rest1) => ( case (Char.toLower c1) of
		        #"l"  => ( case (Substring.getc rest1) of
			  SOME(c2,rest2) => ( case c2 of
			    #">"  => ( rest2, c2::c1::c::stack )
			  | other => ( rest2, other::c1::c::replaceLT )
			  )
			| NONE => ( rest1, c1::c::replaceLT )
                        )
		      | other => ( rest1, other::c::replaceLT )
                      )
 		    | NONE => ( rest, c::replaceLT )
                  )
                | other => ( rest, c::replaceLT )
              )
              | NONE => ( text, replaceLT )
          end

        fun parseHTML (substr) (acc:(char list)) = case (Substring.getc substr) of
            SOME(c,rest) => (case c of
		#"<" => ( case (Substring.first rest) of
                    SOME c1 => 
		      let 
                        val (rest1, stack) = 
			  if c1 = #"/" then 
                            let val (c1,rest1)= (valOf o Substring.getc) rest 
			    in  parseTag (rest1,[c1,c]) end
			else 
			  parseTag (rest,[c])
                      in 			
			parseHTML rest1 (stack@acc)
		      end

                  | NONE => parseHTML rest ( (rev ltList) @ acc )
                )
 	      | #">"  => parseHTML rest ( (#";")::(#"t")::(#"g")::(#"&")::acc )
	      | #"("  => parseHTML 
		           rest ( (#";")::(#"0")::(#"4")::(#"#")::(#"&")::acc )
	      | #")"  => parseHTML 
			   rest ( (#";")::(#"1")::(#"4")::(#"#")::(#"&")::acc )
	      | #"#"  => parseHTML 
			   rest ( (#";")::(#"5")::(#"3")::(#"#")::(#"&")::acc )
	      | #"&"  => parseHTML 
			   rest ( (#";")::(#"8")::(#"3")::(#"#")::(#"&")::acc )
	      | other => parseHTML rest ( other::acc )
            )
	  | NONE => implode (rev acc) 
      in
        parseHTML (Substring.all text) []
      end



  end
