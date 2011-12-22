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

% ==================== gen_server

% ---------- init

init ([ ServerName ]) ->

	% open database
	Options = [
		{ file, ".data/" ++ ServerName ++ "/data" } ],
	{ ok, data } =
		dets:open_file (data, Options),

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

handle_call ('begin', _From, State1) ->

	{ ok, State2, TransactionToken } =
		do_begin (State1),

	{ reply, { ok, TransactionToken }, State2 };

% ---------- handle_call commit

handle_call ({ commit, TransactionToken }, _From, State) ->

	{ ok, NewState } =
		do_commit (State, TransactionToken),

	{ reply, ok, NewState };

% ---------- handle_call fetch

handle_call ({ fetch, TransactionToken, Keys }, _From, State) ->

	{ ok, Rows } =
		do_fetch (State, TransactionToken, Keys),

	{ reply, { ok, Rows }, State };

% ---------- handle_call rollback

handle_call ({ rollback, TransactionToken }, _From, State1) ->

	{ ok, State2 } =
		do_rollback (State1, TransactionToken),

	{ reply, ok, State2 };

% ---------- handle_call update

handle_call ({ update, TransactionToken, Updates }, _From, State1) ->

	case do_update (State1, TransactionToken, Updates) of

		{ ok, State2, Revs } ->

			{ reply, { ok, Revs }, State2 };

		error ->

			{ reply, error, State1 }

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

% ==================== internals

% ---------- do_apply_updates

do_apply_updates (Iter1) ->

	case gb_trees:next (Iter1) of

		{ Key, { Rev, Val }, Iter2 } ->

			% insert the row
			dets:insert (data, { Key, Rev, Val }),

			% tail recurse
			do_apply_updates (Iter2);

		none ->

			% return
			ok

		end.

% ---------- do_begin

do_begin (State1) ->

	TransactionToken =
		list_to_binary (alc_misc:gen_random ()),

	Transaction = #transaction {
		token = TransactionToken,
		updates = gb_trees:empty () },

	State2 = State1#state {
		transactions = gb_trees:enter (
			TransactionToken,
			Transaction,
			State1#state.transactions) },

	{ ok, State2, TransactionToken }.

% ---------- do_commit

do_commit (State1, TransactionToken) ->

	Transaction = do_get_transaction (State1, TransactionToken),

	ok = do_apply_updates (
		gb_trees:iterator (Transaction#transaction.updates)),

	State2 = State1#state {
		transactions = gb_trees:delete (
			TransactionToken,
			State1#state.transactions) },

	{ ok, State2 }.

% ---------- do_get_transaction

do_get_transaction (State, TransactionToken) ->

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

			% return
			Transaction;

		% transaction doesn't exist
		false ->

			% throw error
			throw ({ reply, transaction_token_invalid, State })

		end.

% ---------- do_fetch

do_fetch (State, TransactionToken, Keys) ->

	% get transaction
	Transaction = do_get_transaction (State, TransactionToken),
	Updates = Transaction#transaction.updates,

	% lookup rows
	Rows = lists:map (
		fun (Key) -> do_fetch_one (Updates, Key) end,
		Keys),

	% and return
	{ ok, Rows }.

% ---------- do_fetch_one

do_fetch_one (Updates, Key) ->

	% lookup row in transaction
	case gb_trees:lookup (Key, Updates) of

		% if found
		{ value, { Rev, Val } } ->

			% return it
			{ Rev, Val };

		% if not found
		none ->

			% lookup in dets
			case dets:lookup (data, Key) of

				% if found
				[ { Key, Rev, Val } ] ->

					% return it
					{ Rev, Val };

				% if not found
				[] ->

					% return null
					null

				end
		end.

% ---------- do_rollback

do_rollback (State1, TransactionToken) ->

	% find transaction
	_Transaction = do_get_transaction (State1, TransactionToken),

	% update state
	State2 = State1#state {
		transactions = gb_trees:delete (
			TransactionToken,
			State1#state.transactions) },

	% return
	{ ok, State2 }.

% ---------- do_update

do_update (State1, TransactionToken, Updates) ->

	% find transaction
	Transaction1 = do_get_transaction (State1, TransactionToken),
	TransactionUpdates = Transaction1#transaction.updates,

	% check for errors
	Errors = lists:flatten (
		lists:map (
			fun ({ Key, Rev, _Value }) ->
				do_update_check (TransactionUpdates, Key, Rev)
				end,
			Updates)),

	case Errors of

		% no errors
		[] ->

			% iterate updates
			{ Updates2, RevsX } = lists:foldl (
				fun ({ Key, _Rev, Value }, { Tree1, Revs }) ->

					% generate revision
					NewRev = list_to_binary (alc_misc:gen_random ()),

					% update updates tree
					Tree2 = gb_trees:enter (Key, { NewRev, Value }, Tree1),

					{ Tree2, [ NewRev | Revs ] }
					end,
				{ TransactionUpdates, [] },
				Updates),

			Revs = lists:reverse (RevsX),

			% update transaction
			Transaction2 = Transaction1#transaction {
				updates = Updates2 },

			% update state
			State2 = State1#state {
				transactions = gb_trees:enter (
					TransactionToken,
					Transaction2,
					State1#state.transactions) },

			% return ok
			{ ok, State2, Revs };

		% update errors
		_ ->

			% return error
			error

		end.

% ---------- do_update_check

do_update_check (Updates, Key, Rev) ->

	% check for conflict with current transaction
	case do_update_check_transaction (Updates, Key, Rev) of

		% got error, return it
		[ Error ] -> [ Error ];

		% no error, check for conflict in database
		[] -> case do_update_check_committed (Key, Rev) of

			% got error, return it
			[ Error ] -> [ Error ];

			% no error, return ok
			[] -> []

			end
		end.

do_update_check_transaction (Updates, Key, Rev) ->

	% check for key in transaction
	case gb_trees:lookup (Key, Updates) of

		% found
		{ value, { OldRev, _OldVal } } ->

			% check if the revision matches
			if

				% if so return ok
				Rev == OldRev -> [];

				% otherwise return an error
				true -> [ revision_mismatch ]

			end;

		% not found, return ok
		none -> []

		end.

do_update_check_committed (Key, Rev) ->

	% lookup key in database
	case dets:lookup (data, Key) of

		% found
		[ { Key, OldRev, _OldVal } ] ->

			% check if the revision matches
			if

				% if so return ok
				Rev == OldRev -> [];

				% otherwise return an error
				true -> [ revision_mismatch ]

			end;

		% not found, return ok
		[] -> []

		end.
