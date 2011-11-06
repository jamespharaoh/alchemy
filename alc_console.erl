%
% Filename: alc_console.erl
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

-module (alc_console).
-behaviour (gen_server).

-include_lib ("amqp_client/include/amqp_client.hrl").

-record (state, {
	server_name,
	main_pid,
	mq_connection,
	clients }).

-export ([ start_link/2 ]).
-export ([ connect/3, stop/1 ]).
-export ([ init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3 ]).

% ==================== public

start_link (ServerName, MqConnection) ->
	GenServerName = { local, list_to_atom (ServerName ++ "_console") },
	gen_server:start_link (GenServerName, ?MODULE, [ ServerName, MqConnection ], []).

connect (ConsolePid, ConnId, Who) ->
	gen_server:call (ConsolePid, { connect, ConnId, Who }).

stop (ConsolePid) ->
	gen_server:call (ConsolePid, stop).

% ==================== private

% ---------- init

init ([ ServerName, MqConnection ]) ->

	% setup state
	State = #state {
		server_name = ServerName,
		main_pid = list_to_atom (ServerName ++ "_main"),
		mq_connection = MqConnection,
		clients = [] },

	% and return
	{ ok, State }.

% ---------- handle_call connect

handle_call ({ connect, ConnId, Who }, _From, State) ->
	#state {
		server_name = ServerName,
		mq_connection = MqConnection
	} = State,
	{ ok, ClientPid } = alc_console_client:start_link (ServerName, MqConnection, ConnId, Who),
	{ reply, ClientPid, State };

% ---------- handle_call stop

handle_call (stop, _From, State) ->
	{ stop, normal, ok, State };

% ---------- handle_call

handle_call (Request, From, State) ->
	io:format ("alc_console:handle_call (~p, ~p, ~p)\n", [ Request, From, State ]),
	{ reply, error, State }.

% ---------- handle_cast

handle_cast (Request, State) ->
	io:format ("alc_console:handle_cast (~p, ~p)\n", [ Request, State ]),
	{ noreply, State }.

% ---------- handle_info

handle_info (Info, State) ->
	io:format ("alc_console:handle_info (~p, ~p)\n", [ Info, State ]),
	{ noreply, State }.

% ---------- terminate

terminate (_Reason, _State) ->
	ok.

% ---------- code_change

code_change (_OldVsn, State, _Extra) ->
	{ ok, State }.

