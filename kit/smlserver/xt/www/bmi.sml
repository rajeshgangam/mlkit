functor bmi () : SCRIPTLET =
    struct
	open Scripts infix & % attr

	val response = 
	    Page.page "Body Mass Index Form" 
	    (bmi2.form 
	     (p($"Enter your height (in cm) " &
		(inputText attr (A.size 5)) (bmi2.h, NONE) &
		br() &
		$"Enter your weight (in kg) " &
		(inputText attr (A.size 5)) (bmi2.w, NONE) &
		br() &
		inputSubmit "Compute Index")))
    end