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
	gen_server:start_link (?MODULE, [ ServerName, MqConnection, ConnId, Who ], []).

% ==================== private

% ---------- init

init ([ ServerName, MqConnection, ConnId, Who ]) ->
	MainPid = list_to_atom (ServerName ++ "_main"),
	ConsolePid = list_to_atom (ServerName ++ "_console"),

	% open channel
	{ ok, MqChannel } = amqp_connection:open_channel (MqConnection),

	% create receive queue
	random:seed (now ()), % TODO this is horrible
	ReceiveQueue = list_to_binary ("alchemy-server-" ++ ConnId),
	#'queue.declare_ok' {} = amqp_channel:call (MqChannel, #'queue.declare' { queue = ReceiveQueue }),

	% subscribe to messages
	Sub = #'basic.consume' { queue = ReceiveQueue },
	#'basic.consume_ok' { consumer_tag = _Tag } = amqp_channel:subscribe (MqChannel, Sub, self ()),

	% send response
	SendQueue = list_to_binary ("alchemy-client-" ++ ConnId),
	Data = [ <<"console-ok">>, ReceiveQueue ],
	Payload = list_to_binary (mochijson2:encode (Data)),
	Publish = #'basic.publish' { exchange = <<"">>, routing_key = SendQueue },
	amqp_channel:cast (MqChannel, Publish, #amqp_msg{payload = Payload}),

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
	try
		Data = alc_misc:decode (Payload),
		handle_message (State, Data)
	catch
		throw:decode_error ->
			io:format ("MSG: error decoding ~p\n", [ Payload ])
	end,
	amqp_channel:cast (MqChannel, #'basic.ack' { delivery_tag = Tag }),
	{ noreply, State }.

% ---------- terminate

terminate (_Reason, _State) ->
io:format ("alc_console_client terminate\n"),
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
			io:format ("MSG: ignoring invalid function call ~s ~p\n", [ RequestType, Args ])
	end.

% ---------- handle_message run_command

handle_message (run_command, State, [ Command ]) ->
	io:format ("Got command: ~s\n", [ Command ]),
	case Command of
		<<"shutdown">> -> command_exit (State);
		<<_/binary>> -> command_invalid (State, Command)

	end.

% ---------- command_invalid

command_invalid (_State, Command) ->
	io:format ("Invalid command: ~s\n", [ Command ]).

% ---------- command_exit

command_exit (State) ->
	#state { main_pid = MainPid } = State,
	MainPid ! { shutdown }.

