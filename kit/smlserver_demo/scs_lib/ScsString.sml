signature SCS_STRING =
  sig
    val translate : (char -> string) -> string -> string
    val lower     : string -> string
    val upper     : string -> string

    (* [canonical s] returns a canonical representation of s, that is,
       all words are separated by only one space; new lines etc. has
       been removed *)
    val canonical : string -> string

    (* [shorten text len] returns the string text shortended to
       maximum lenght len. *)
    val shorten : string -> int -> string

    (* [maybe str1 str2] returns str2 if str1 is non
       empty. If empty, then the empty string is returned. *)
    val maybe     : string -> string -> string

    (* [valOf strOpt] if strOpt is SOME str then returns str otherwise
       the empty string *)
    val valOf     : string option -> string
  end

structure ScsString =
  struct
    fun translate f s  = concat (map f (explode s))
    fun lower s = CharVector.fromList (List.map Char.toLower (explode s))
    fun upper s = CharVector.fromList (List.map Char.toUpper (explode s))

    fun canonical s = String.concatWith " " (String.tokens Char.isSpace s)

    fun shorten text length = 
      String.substring( text, 0, Int.min(length, String.size text) ) ^ "..."

    fun maybe str1 str2 = if str1 = "" then "" else str2

    fun valOf (SOME s) = s
      | valOf NONE = ""
  end