-module (alc_server).

-export ([ start/3 ]).

-include_lib ("amqp_client/include/amqp_client.hrl").

-record (state, { main_pid, console_pid, connection, channel }).

start (ConsolePid, Connection, ReceiveQueue) ->
	MainPid = self (),

	spawn_link (fun () ->

		% open channel
		{ ok, Channel } = amqp_connection:open_channel (Connection),

		% create receive queue
		#'queue.declare_ok' {} = amqp_channel:call (Channel, #'queue.declare' { queue = ReceiveQueue }),

		% subscribe to messages
		Sub = #'basic.consume' { queue = ReceiveQueue },
		#'basic.consume_ok' { consumer_tag = _Tag } = amqp_channel:subscribe (Channel, Sub, self ()),

		% setup state
		State = #state{
			main_pid = MainPid,
			console_pid = ConsolePid,
			connection = Connection,
			channel = Channel
		},

		% main loop
		main_loop (State),

		% mq delete queue
		Delete = #'queue.delete' { queue = ReceiveQueue },
		#'queue.delete_ok' {} = amqp_channel:call (Channel, Delete),

		% close channel
		amqp_channel:close (Channel),

		% and return
		ok
	end).

main_loop (State) ->
	#state { channel = Channel } = State,
	receive

		% subscription started
		#'basic.consume_ok' {} ->
			main_loop (State);

		% subscription cancelled
		#'basic.cancel_ok' {} ->
			ok;

		% message received
		{ #'basic.deliver' { delivery_tag = Tag }, Message } ->
			#amqp_msg { payload = Payload } = Message,
			try
				Data = alc_misc:decode (Payload),
				handle (State, Data)
			catch
				throw:decode_error ->
					io:format ("MSG: error decoding ~p\n", [ Payload ])
			end,
			amqp_channel:cast (Channel, #'basic.ack' { delivery_tag = Tag }),
			main_loop (State);

		% error
		Any ->
			io:format ("alc_server: unknown event: ~p\n", [ Any ])

	end.

handle (State, Data) ->
	[ RequestTypeBin | Args ] = Data,
	RequestType = list_to_atom (binary_to_list (RequestTypeBin)),
	try
		handle (RequestType, State, Args)
	catch
		error:function_clause ->
			io:format ("MSG: ignoring invalid function call ~s ~p\n", [ RequestType, Args ])
	end.

handle (console, State, [ ConnId, Who ]) ->
	#state { console_pid = ConsolePid } = State,
	alc_console:connect (ConsolePid, ConnId, Who).
