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
	'begin'/1,
	commit/2,
	fetch/3,
	rollback/2,
	update/3 ]).

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
	token,
	updates }).

% ==================== public lifecycle

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

% ==================== public general

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

% ---------- fetch

fetch (StorePid, TransactionToken, Keys) ->

	gen_server:call (
		StorePid,
		{ fetch, TransactionToken, Keys }).

% ---------- rollback

rollback (StorePid, TransactionToken) ->

	gen_server:call (
		StorePid,
		{ rollback, TransactionToken }).

% ---------- update

update (StorePid, TransactionToken, Updates) ->

	gen_server:call (
		StorePid,
		{ update, TransactionToken, Updates }).

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

	Transaction = #transaction {
		token = Token,
		updates = gb_trees:empty () },

	NewState = State#state {
		transactions = gb_trees:enter (
			Token,
			Transaction,
			State#state.transactions) },

	{ reply, { ok, Token }, NewState };

% ---------- handle_call commit

handle_call ({ commit, TransactionToken }, _From, State) ->

	case gb_trees:is_defined (
			TransactionToken,
			State#state.transactions) of

		true ->

			NewState = State#state {
				transactions = gb_trees:delete (
					TransactionToken,
					State#state.transactions) },

			{ reply, ok, NewState };

		false ->

			{ reply, token_invalid, State }

		end;

% ---------- handle_call fetch

handle_call ({ fetch, TransactionToken, Keys }, _From, State) ->

	case gb_trees:is_defined (
			TransactionToken,
			State#state.transactions) of

		true ->

			Transaction = gb_trees:get (
				TransactionToken,
				State#state.transactions),

			Rows = lists:map (
				fun (Key) ->
					case gb_trees:lookup (
							Key,
							Transaction#transaction.updates) of
						{ value, Value } -> Value;
						none -> null
						end
					end,
				Keys),

			{ reply, { ok, Rows }, State };

		false ->

			{ reply, token_invalid, State }

		end;

% ---------- handle_call rollback

handle_call ({ rollback, TransactionToken }, _From, State) ->

	case gb_trees:is_defined (
			TransactionToken,
			State#state.transactions) of

		true ->

			NewState = State#state {
				transactions =
					gb_trees:delete (
						TransactionToken,
						State#state.transactions) },

			{ reply, ok, NewState };

		false ->

			{ reply, token_invalid, State }

		end;

% ---------- handle_call update

handle_call ({ update, TransactionToken, Updates }, _From, State) ->

	% make sure transaction exists
	case gb_trees:is_defined (
			TransactionToken,
			State#state.transactions) of

		% transaction does exist
		true ->

			% find transaction
			Transaction = gb_trees:get (
				TransactionToken,
				State#state.transactions),

			% check for errors
			Errors = lists:flatten (
				lists:map (
					fun ({ Key, _Rev, _Value }) ->
						case gb_trees:is_defined (
								Key,
								Transaction#transaction.updates) of
							true -> [ true ];
							false -> []
							end
						end,
					Updates)),

			case Errors of

				% no errors
				[] ->

					% update transaction
					NewTransaction = Transaction#transaction {
						updates = lists:foldl (
							fun ({ Key, _Rev, Value }, Tree) ->
								gb_trees:enter (
									Key,
									Value,
									Tree)
								end,
							Transaction#transaction.updates,
							Updates) },

					% update state
					NewState = State#state {
						transactions = gb_trees:enter (
							TransactionToken,
							NewTransaction,
							State#state.transactions) },

					% return ok
					{ reply, ok, NewState };

				% update errors
				_ ->

					% return error
					{ reply, error, State }

				end;

		% transaction doesn't exist
		false ->

			% return error
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
