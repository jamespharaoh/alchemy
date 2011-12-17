%
% Filename: alc_store.erl
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

-module (alc_store).
-behaviour (gen_server).

-include_lib ("amqp_client/include/amqp_client.hrl").

-export ([
	start_link/1,
	stop/1 ]).

-export ([
	init/1,
	handle_call/3,
	handle_cast/2,
	handle_info/2,
	terminate/2,
	code_change/3 ]).

-record (state, {
	server_name,
	tables }).

% ==================== public

% ---------- start_link

start_link (ServerName) ->

	gen_server:start_link (
		{ local, list_to_atom (ServerName ++ "_store") },
		?MODULE,
		[ ServerName ],
		[]).

% ---------- stop

stop (StorePid) ->

	gen_server:call (
		StorePid,
		stop).

% ---------- store

%store (StorePid, Type, Value) ->
%
%	gen_server:call (
%		StorePid,
%		{ store, Type, Value }).

% ==================== private

% ---------- init

init ([ ServerName ]) ->

	% setup state
	State = #state {
		server_name = ServerName,
		tables = gb_sets:new () },

	% and return
	{ ok, State }.

% ---------- handle_call stop

handle_call (stop, _From, State) ->

	{ stop, normal, ok, State };

% ---------- handle_call

handle_call (Request, From, State) ->
	io:format ("alc_store:handle_call (~p, ~p, ~p)\n", [ Request, From, State ]),
	{ reply, error, State }.

% ---------- handle_cast

handle_cast (Request, State) ->
	io:format ("alc_store:handle_cast (~p, ~p)\n", [ Request, State ]),
	{ noreply, State }.

% ---------- handle_info

handle_info (Info, State) ->
	io:format ("alc_store:handle_info (~p, ~p)\n", [ Info, State ]),
	{ noreply, State }.

% ---------- terminate

terminate (_Reason, _State) ->
	ok.

% ---------- code_change

code_change (_OldVsn, State, _Extra) ->
	{ ok, State }.

