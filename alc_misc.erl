-module (alc_misc).

-export ([ gen_random/0, gen_random/1 ]).
-export ([ decode/1 ]).

gen_random () -> gen_random (10).

gen_random (Length) when Length == 0 -> [];
gen_random (Length) -> [ $a + random:uniform (26) - 1 | gen_random (Length - 1) ].

decode (Json) ->
	try
		mochijson2:decode (Json)
	catch
		_:_ -> throw (decode_error)
	end.
