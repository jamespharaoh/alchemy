-module (alc_boot).

-export ([ start/0 ]).

start () ->

	% process args
	Args = init:get_plain_arguments (),
	[ ServerName ] = Args,

	% start main process
	{ ok, MainPid } = alc_main:start_link (ServerName),

	% and wait for it to finish
	loop (MainPid).

loop (MainPid) ->
	receive

		{ 'EXIT', MainPid, Reason } ->
			stop (Reason);

		Any ->
			io:format ("ERROR alc_boot received ~p\n", [ Any ]),
			loop (MainPid)
	end.

stop (normal) ->
	halt (0);

stop (Reason) ->
	io:format ("Terminating for reason ~p\n", Reason),
	halt (1).
