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
	'begin'/1,
	commit/2,
	rollback/2,
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
	tables,
	transactions }).

-record (transaction, {
	token }).

% ==================== public

% ---------- begin

'begin' (StorePid) ->

	gen_server:call (
		StorePid,
		'begin').	

% ---------- commit

commit (StorePid, TransactionToken) ->

	gen_server:call (
		StorePid,
		{ commit, TransactionToken }).	

% ---------- start_link

start_link (ServerName) ->

	gen_server:start_link (
		{ local, list_to_atom (ServerName ++ "_store") },
		?MODULE,
		[ ServerName ],
		[]).

% ---------- rollback

rollback (StorePid, TransactionToken) ->

	gen_server:call (
		StorePid,
		{ rollback, TransactionToken }).	

% ---------- stop

stop (StorePid) ->

	gen_server:call (
		StorePid,
		stop).

% ==================== private

% ---------- init

init ([ ServerName ]) ->

	% setup state
	State = #state {
		server_name = ServerName,
		tables = gb_sets:new (),
		transactions = gb_trees:empty () },

	% and return
	{ ok, State }.

% ---------- handle_call stop

handle_call (stop, _From, State) ->

	{ stop, normal, ok, State };

% ---------- handle_call begin

handle_call ('begin', _From, State) ->

	Token = list_to_binary (alc_misc:gen_random ()),

	io:format ("BEGIN ~s\n",
		[ Token ]),

	Transaction = #transaction {
		token = Token },

	NewState = State#state {
		transactions =
			gb_trees:enter (
				Token,
				Transaction,
				State#state.transactions) },

io:format ("STATE: ~p\n", [ NewState ]),

	{ reply, { ok, Token }, NewState };

% ---------- handle_call commit

handle_call ({ commit, TransactionToken }, _From, State) ->

	io:format ("COMMIT ~s\n",
		[ TransactionToken ]),

	case gb_trees:is_defined (
			TransactionToken,
			State#state.transactions) of

		true ->

			NewState = State#state {
				transactions =
					gb_trees:delete (
						TransactionToken,
						State#state.transactions) },

io:format ("STATE: ~p\n", [ NewState ]),

			{ reply, ok, NewState };

		false ->

			{ reply, token_invalid, State }

	end;

% ---------- handle_call rollback

handle_call ({ rollback, TransactionToken }, _From, State) ->

	io:format ("ROLLBACK ~s\n",
		[ TransactionToken ]),

	case gb_trees:is_defined (
			TransactionToken,
			State#state.transactions) of

		true ->

			NewState = State#state {
				transactions =
					gb_trees:delete (
						TransactionToken,
						State#state.transactions) },

io:format ("STATE: ~p\n", [ NewState ]),

			{ reply, ok, NewState };

		false ->

			{ reply, token_invalid, State }

	end;

% ---------- handle_call

handle_call (Request, From, State) ->

	io:format ("alc_store:handle_call (~p, ~p, ~p)\n",
		[ Request, From, State ]),

	{ reply, error, State }.

% ---------- handle_cast

handle_cast (Request, State) ->

	io:format ("alc_store:handle_cast (~p, ~p)\n",
		[ Request, State ]),

	{ noreply, State }.

% ---------- handle_info

handle_info (Info, State) ->

	io:format ("alc_store:handle_info (~p, ~p)\n",
		[ Info, State ]),

	{ noreply, State }.

% ---------- terminate

terminate (_Reason, _State) ->

	ok.

% ---------- code_change

code_change (_OldVsn, State, _Extra) ->

	{ ok, State }.

