%
% Filename: alc_server.erl
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

-module (alc_server).
-behaviour (gen_server).

-include_lib ("amqp_client/include/amqp_client.hrl").

-export ([
	start_link/3,
	stop/1 ]).

-export ([
	init/1,
	handle_call/3,
	handle_cast/2,
	handle_info/2,
	terminate/2,
	code_change/3 ]).

-record (state, {
	mq_client,
	console_pid }).

% ==================== public

% ---------- start_link

start_link (Mq, ServerName, ConsolePid) ->

	gen_server:start_link (
		{ local, list_to_atom (ServerName ++ "_server") },
		?MODULE,
		[ Mq, ServerName, ConsolePid ],
		[]).

% ---------- stop

stop (Pid) ->

	gen_server:call (
		Pid,
		stop).

% ==================== gen_server

% ---------- init

init ([ Mq, ServerName, ConsolePid ]) ->

	% open mq client
	{ ok, MqClient } = alc_mq:open (
		Mq,
		"alchemy-server-" ++ ServerName),

	% setup state
	State = #state {
		mq_client = MqClient,
		console_pid = ConsolePid },

	% and return
	{ ok, State }.

% ---------- handle_call stop

handle_call (stop, _From, State) ->

	{ stop, normal, ok, State };

% ---------- handle_call

handle_call (Request, From, State) ->

	io:format ("alc_server:handle_call (~p, ~p, ~p)\n",
		[ Request, From, State ]),

	{ reply, error, State }.

% ---------- handle_cast

handle_cast (Request, State) ->

	io:format ("alc_server:handle_cast (~p, ~p)\n",
		[ Request, State ]),

	{ noreply, State }.

% ---------- handle_info basic.deliver

handle_info (
	{	#'basic.deliver' { delivery_tag = Tag },
		Message },
	State) ->

	#amqp_msg { payload = Payload } = Message,

	#state { mq_client = MqClient } = State,

	try
		Data = alc_misc:decode (Payload),
		handle (State, Data)
	catch
		throw:decode_error ->
			io:format ("MSG: error decoding ~p\n", [ Payload ])
	end,

	alc_mq:ack (MqClient, Tag),

	{ noreply, State };

% ---------- handle_info

handle_info (Info, State) ->

	io:format ("alc_server:handle_info (~p, ~p)\n",
		[ Info, State ]),

	{ noreply, State }.

% ---------- terminate

terminate (_Reason, State) ->

	#state {
		mq_client = MqClient
	} = State,

	alc_mq:close (MqClient),

	ok.

% ---------- code_change

code_change (_OldVsn, State, _Extra) ->
	{ ok, State }.

% ---------- handle

handle (State, Data) ->

	[ RequestTypeBin | Args ] = Data,

	RequestType = list_to_atom (binary_to_list (RequestTypeBin)),

	try
		handle (RequestType, State, Args)
	catch
		error:function_clause ->
			io:format ("MSG: ignoring invalid function call ~s ~p\n",
				[ RequestType, Args ])
	end.

handle (console, State, [ ConnId, Who ]) ->

	#state { console_pid = ConsolePid } = State,

	alc_console:connect (ConsolePid, ConnId, Who).

