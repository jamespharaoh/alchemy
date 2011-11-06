%
% Filename: alc_console_client.erl
%
% This is part of the Alchemy configuration database. For more
% information, visit our home on the web at
%
%     https://github.com/jamespharaoh/alchemy
%
% Copyright 2011 James Pharaoh
%
% Licensed under the Apache License, Version 2.0 (the "License");
% you may not use this file except in compliance with the License.
% You may obtain a copy of the License at
%
%     http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS,
% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
% See the License for the specific language governing permissions and
% limitations under the License.
%

-module (alc_console_client).
-behaviour (gen_server).

-include_lib ("amqp_client/include/amqp_client.hrl").

-record (state, {
	server_name,
	main_pid,
	console_pid,
	mq_connection,
	mq_channel,
	conn_id,
	receive_queue,
	send_queue,
	who }).

-export ([ start_link/4 ]).
-export ([ init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3 ]).

% ==================== public

start_link (ServerName, MqConnection, ConnId, Who) ->
	GenServerName = { local, list_to_atom (ServerName ++ "_console_" ++ binary_to_list (ConnId)) },
	gen_server:start_link (GenServerName, ?MODULE, [ ServerName, MqConnection, ConnId, Who ], []).

% ==================== private

% ---------- init

init ([ ServerName, MqConnection, ConnId, Who ]) ->

	MainPid = list_to_atom (ServerName ++ "_main"),
	ConsolePid = list_to_atom (ServerName ++ "_console"),

	ReceiveQueue = list_to_binary ("alchemy-server-" ++ ConnId),
	SendQueue = list_to_binary ("alchemy-client-" ++ ConnId),

	% open channel
	{ ok, MqChannel } = amqp_connection:open_channel (MqConnection),

	% create receive queue
	random:seed (now ()), % TODO this is horrible
	#'queue.declare_ok' {} = amqp_channel:call (MqChannel, #'queue.declare' { queue = ReceiveQueue }),

	% subscribe to messages
	Sub = #'basic.consume' { queue = ReceiveQueue },
	#'basic.consume_ok' { consumer_tag = _Tag } = amqp_channel:subscribe (MqChannel, Sub, self ()),

	% output a message
	io:format ("Connection from ~s (~s)\n", [ Who, ConnId ]),

	% setup state
	State = #state {
		main_pid = MainPid,
		console_pid = ConsolePid,
		mq_connection = MqConnection,
		mq_channel = MqChannel,
		conn_id = ConnId,
		receive_queue = ReceiveQueue,
		send_queue = SendQueue,
		who = Who },

	% send response
	mq_send (State, [ <<"console-ok">> ]),

	% and return
	{ ok, State }.

% ---------- handle_call

handle_call (Request, From, State) ->
	io:format ("alc_console_client:handle_call (~p, ~p, ~p)\n", [ Request, From, State ]),
	{ reply, error, State }.

% ---------- handle_cast

handle_cast (Request, State) ->
	io:format ("alc_console_client:handle_cast (~p, ~p)\n", [ Request, State ]),
	{ noreply, State }.

% ---------- handle_info basic.consume_ok

handle_info (#'basic.consume_ok' {}, State) ->
	{ noreply, State };

% ---------- handle_info basic.cancel_ok

handle_info (#'basic.cancel_ok' {}, State) ->
	{ noreply, State };

% ---------- handle_info basic.deliver

handle_info ({ #'basic.deliver' { delivery_tag = Tag }, Message }, State) ->
	#state { mq_channel = MqChannel } = State,
	#amqp_msg { payload = Payload } = Message,
	Ret = try
		Data = alc_misc:decode (Payload),
		handle_message (State, Data)
	catch
		throw:decode_error ->
			io:format ("MSG: error decoding ~p\n", [ Payload ])
	end,
	amqp_channel:cast (MqChannel, #'basic.ack' { delivery_tag = Tag }),
	Ret.

% ---------- terminate

terminate (_Reason, State) ->
	#state { who = Who, conn_id = ConnId } = State,

	% output a message
	io:format ("Disconnected ~s (~s)\n", [ Who, ConnId ]),

	% and return
	ok.

% ---------- code_change

code_change (_OldVsn, State, _Extra) ->
	{ ok, State }.

% ---------- handle_message

handle_message (State, Data) ->
	[ RequestTypeBin | Args ] = Data,
	RequestType = list_to_atom (binary_to_list (RequestTypeBin)),
	try
		handle_message (RequestType, State, Args)
	catch
		error:function_clause ->
			io:format ("MSG: ignoring invalid function call ~s ~p\n", [ RequestType, Args ]),
			{ noreply, State }
	end.

% ---------- handle_message run_command

handle_message (run_command, State, [ Command ]) ->
	io:format ("Got command: ~s\n", [ Command ]),
	case Command of
		<<"exit">> -> command_exit (State);
		<<"help">> -> command_help (State);
		<<"shutdown">> -> command_shutdown (State);
		<<_/binary>> -> command_invalid (State, Command)
	end.

% ---------- command_invalid

command_invalid (State, Command) ->

	% show console message
	io:format ("Invalid command: ~s\n", [ Command ]),

	% confirm command
	mq_send (State, [ <<"command-ok">> ]),

	% send error message
	mq_send (State, [ <<"message">>, <<"Command error. Type 'help' for assistance.\n">> ]),

	% end command
	mq_send (State, [ <<"command-complete">> ]),

	% and return
	{ noreply, State }.

% ---------- command_exit

command_exit (State) ->

	% confirm command
	mq_send (State, [ <<"command-ok">> ]),

	% close connection
	mq_send (State, [ <<"terminate">> ]),

	% and end this process
	{ stop, normal, State }.

% ---------- command_help

command_help (State) ->

	% send command ok
	mq_send (State, [ <<"command-ok">> ]),

	Help = <<
		"\n",
		"Available commands:\n",
		"  exit        End this console session\n",
		"  help        Display this message\n",
		"  shutdown    Shut down the server process\n",
		"\n">>,

	% send help message
	mq_send (State, [ <<"message">>, Help ]),

	% send command complete
	mq_send (State, [ <<"command-complete">> ]),

	% and return
	{ noreply, State }.

% ---------- command_shutdown

command_shutdown (State) ->
	#state { main_pid = MainPid } = State,

	% confirm command received and processed
	mq_send (State, [ <<"command-ok">> ]),

	% send shutdown request to main process
	MainPid ! { shutdown },

	% and return
	{ noreply, State }.

% ---------- send

mq_send (State, Data) ->
	#state {
		mq_channel = MqChannel,
		send_queue = SendQueue
	} = State,
	Payload = list_to_binary (mochijson2:encode (Data)),
	Publish = #'basic.publish' { exchange = <<"">>, routing_key = SendQueue },
	amqp_channel:cast (MqChannel, Publish, #amqp_msg{ payload = Payload }).

