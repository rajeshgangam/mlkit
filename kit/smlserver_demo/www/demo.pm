import ../lib/lib.pm
in
  local
       ../lib/NsCacheV2.sml
       ../demo_lib/Page.sml
       ../demo_lib/FormVar.sml
       ../demo_lib/Auth.sml
       ../demo_lib/RatingUtil.sml
  in 
    [
     demo/guest.sml
     demo/guest_add.sml
     demo/exchange.sml
     demo/regexp.sml
     demo/cache.sml
     demo/cache_add.sml
     demo/cache_lookup.sml
     demo/cache_v2.sml
     demo/cache_add_v2.sml
     demo/cache_lookup_v2.sml
     demo/cache_fib_v2.sml
     demo/cache_add_list_v2.sml
     demo/cache_lookup_list_v2.sml
     demo/cookie.sml
     demo/cookie_set.sml
     demo/cookie_delete.sml
     demo/db_test.sml
     demo/db_clob_test.sml (* Testing Oracle Clobs 2002-09-17, nh *)
     demo/index.sml
     demo/rating/index.sml
     demo/rating/add.sml
     demo/rating/add0.sml
     demo/rating/wine.sml
     demo/employee/index.sml
     demo/employee/update.sml
     demo/employee/search.sml
     demo/time_of_day.sml
     demo/guess.sml
     demo/counter.sml
     demo/temp.sml
     demo/recipe.sml
     demo/hello.msp
     demo/calendar.msp
     demo/test.msp
     demo/server.sml
     demo/mail_form.sml
     demo/mail.sml
     demo/mul.msp
     demo/currency_cache.sml
     demo/formvar.sml
     demo/formvar_chk.sml
     demo/return_file.sml
     demo/auth_form.sml
     demo/auth_logout.sml
     demo/auth.sml
     demo/auth_new_form.sml
     demo/auth_new.sml
     demo/auth_send_form.sml
     demo/auth_send.sml
     demo/link/index.sml
     demo/link/add_form.sml
     demo/link/add.sml
     demo/link/delete.sml
     ]
  end
end