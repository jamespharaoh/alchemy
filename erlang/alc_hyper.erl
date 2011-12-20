%
% Filename: alc_hyper.erl
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

-module (alc_hyper).
-behaviour (gen_server).

-include_lib ("amqp_client/include/amqp_client.hrl").

-export ([
	start_link/2 ]).

-export ([
	init/1,
	handle_call/3,
	handle_cast/2,
	handle_info/2,
	terminate/2,
	code_change/3 ]).

-record (state, {
	mq,
	mq_client,
	servers }).

% ==================== public

% --------- start_link

start_link (Mq, ServerName) ->

	gen_server:start_link (
		{ local, list_to_atom (ServerName ++ "_hyper") },
		?MODULE,
		[ ServerName, Mq ],
		[]).

% ==================== private

% ---------- init

init ([ ServerName, Mq ]) ->

	io:format ("Alchemy hypervisor (development version)\n"),
	io:format ("Hypervisor name: ~s\n", [ ServerName ]),

	% open mq client
	{ ok, MqClient } =
		alc_mq:open (Mq, "alchemy-hyper-" ++ ServerName),

	% setup state
	State = #state {
		mq = Mq,
		mq_client = MqClient,
		servers = [] },

	% console output
	io:format ("Hypervisor ready\n"),

	% and return
	{ ok, State }.

% ---------- handle_call

handle_call (Request, From, State) ->

	io:format ("alc_main:handle_call (~p, ~p, ~p)\n",
		[ Request, From, State ]),

	{ reply, error, State }.

% ---------- handle_cast

handle_cast (Request, State) ->

	io:format ("alc_main:handle_cast (~p, ~p)\n",
		[ Request, State ]),

	{ noreply, State }.

% ---------- handle_info basic.deliver

handle_info ({ #'basic.deliver' { delivery_tag = Tag }, Message }, State) ->

	#amqp_msg { payload = Payload } = Message,

	Result = try
		Data = alc_misc:decode (Payload),
		deliver (Data, State)
	catch
		throw:decode_error ->
			io:format ("alc_main:handle_info: error decoding ~p\n", [ Payload ])
	end,

	alc_mq:ack (State#state.mq_client, Tag),

	Result;

% ---------- handle_info shutdown

handle_info ({ shutdown }, State) ->

	{ stop, normal, State };

% ---------- handle_info

handle_info (Info, State) ->

	io:format ("alc_main:handle_info (~p, ~p)\n",
		[ Info, State ]),

	{ noreply, State }.

% ---------- terminate

terminate (_Reason, State) ->

	#state {
		mq_client = MqClient
	} = State,

	% console output
	io:format ("Hypservisor stopping\n"),

	% close mq client
	alc_mq:close (MqClient),

	% console output
	io:format ("Hypservisor stopped\n"),

	ok.

% ---------- code_change

code_change (_OldVsn, State, _Extra) ->

	{ ok, State }.

% ==================== deliver

% ---------- deliver reset

deliver ([ <<"reset">>, ClientToken, RequestToken ], State) ->

	io:format ("Hypervisor reset\n", []),

	% stop servers
	lists:foreach (
		fun (Pid) -> alc_main:stop (Pid) end,
		State#state.servers),

	% send response
	alc_mq:send (
		State#state.mq_client,
		<<"alchemy-client-", ClientToken/binary>>,
		[ <<"reset-ok">>, RequestToken ]),

	% update state
	NewState = State#state {
		servers = [] },

	{ noreply, NewState };

% ---------- deliver shutdown

deliver ([ <<"shutdown">> ], State) ->

	{ stop, normal, State };

% ---------- deliver start

deliver ([ <<"start">>, ClientToken, RequestToken, ServerName ], State) ->

	io:format ("Hypervisor starting ~s\n", [ ServerName ]),

	% start server
	{ ok, Main } = alc_main:start_link (
		State#state.mq,
		binary_to_list (ServerName)),

	% send response
	alc_mq:send (
		State#state.mq_client,
		<<"alchemy-client-", ClientToken/binary>>,
		[ <<"start-ok">>, RequestToken ]),

	% update state
	NewState = State#state {
		servers = [ Main | State#state.servers ] },

	{ noreply, NewState };

% ---------- deliver

deliver (Message, State) ->

	io:format ("alc_hyper:deliver (~p, ~p)\n",
		[ Message, State ]),

	{ noreply, State }.
