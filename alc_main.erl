%
% Filename: alc_main.erl
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

-module (alc_main).
-behaviour (gen_server).

-include_lib ("amqp_client/include/amqp_client.hrl").

-export ([ start_link/1 ]).
-export ([ init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3 ]).

-record (state, { mq_connection, server_pid, console_pid }).

% ==================== public

start_link (ServerName) ->
	GenServerName = { local, list_to_atom (ServerName ++ "_main") },
	gen_server:start_link (GenServerName, ?MODULE, [ ServerName ], []).

% ==================== private

% ---------- init

init ([ ServerName ]) ->

	io:format ("Alchemy (development version)\n"),
	io:format ("Server name: ~s\n", [ ServerName ]),

	% mq connect
	{ ok, MqConnection } = amqp_connection:start (#amqp_params_network {}),

	% start console
	{ ok, ConsolePid } = alc_console:start_link (ServerName, MqConnection),

	% start server
	QueueName = list_to_binary ("alchemy-server-" ++ ServerName),
	io:format ("Queue name: ~s\n", [ QueueName ]),
	ServerPid = alc_server:start (ConsolePid, MqConnection, QueueName),

	% setup state
	State = #state {
		mq_connection = MqConnection,
		server_pid = ServerPid,
		console_pid = ConsolePid },

	% console output
	io:format ("Ready\n"),

	% and return
	{ ok, State }.

% ---------- handle_call

handle_call (Request, From, State) ->
	io:format ("alc_main:handle_call (~p, ~p, ~p)\n", [ Request, From, State ]),
	{ reply, error, State }.

% ---------- handle_cast

handle_cast (Request, State) ->
	io:format ("alc_main:handle_cast (~p, ~p)\n", [ Request, State ]),
	{ noreply, State }.

% ---------- handle_info shutdown

handle_info ({ shutdown }, State) ->
	{ stop, normal, State };

% ---------- handle_info

handle_info (Info, State) ->
	io:format ("alc_main:handle_info (~p, ~p)\n", [ Info, State ]),
	{ noreply, State }.

% ---------- terminate

terminate (_Reason, State) ->
	#state {
		console_pid = ConsolePid,
		mq_connection = MqConnection
	} = State,

	% console output
	io:format ("Shutting down\n"),

	% stop console
	alc_console:stop (ConsolePid),

	% mq disconnect
	amqp_connection:close (MqConnection),

	% console output
	io:format ("Shutdown complete\n"),

	ok.

% ---------- code_change

code_change (_OldVsn, State, _Extra) ->
	{ ok, State }.

