%
% Filename: alc_mq.erl
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

-module (alc_mq).
-behaviour (gen_server).

-include_lib ("amqp_client/include/amqp_client.hrl").

-export ([
	ack/2,
	client_channel/1,
	close/1,
	get_connection/1,
	open/2,
	send/3,
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
	connection }).

-record (client, {
	channel,
	receive_queue,
	tag }).

-type this () :: pid ().

-type channel () :: any ().
-type connection () :: any ().

-opaque client () :: #client {}.

% ==================== public

% ---------- ack

-spec ack (client (), any ()) -> ok.

ack (Client, Tag) ->

	amqp_channel:cast (
		Client#client.channel,
		#'basic.ack' { delivery_tag = Tag }),

	ok.

% ---------- client_channel

-spec client_channel (client ()) -> channel ().

client_channel (Client) ->

	#client { channel = Channel } = Client,

	Channel.

% ---------- close

-spec close (client ()) -> ok.

close (Client) ->

	#client {
		channel = Channel,
		tag = Tag
	} = Client,

	% cancel subscription
	amqp_channel:call (
		Channel,
		#'basic.cancel'{ consumer_tag = Tag }),

	% close mq channel
	amqp_channel:close (Channel),

	% return
	ok.

% ---------- get_connection

-spec get_connection (this ()) -> connection ().

get_connection (Pid) ->

	gen_server:call (
		Pid,
		{ get_connection }).

% ---------- open

-spec open (this (), string ()) -> { ok, client () }.

open (Pid, ReceiveQueueStr) ->

	ReceiveQueue = list_to_binary (ReceiveQueueStr),

	% get connection
	Connection = get_connection (Pid),

	% open mq channel
	{ ok, Channel } =
		amqp_connection:open_channel (
			Connection),

	% create receive queue
	#'queue.declare_ok' {} =
		amqp_channel:call (
			Channel,
			#'queue.declare' {
				queue = ReceiveQueue,
				exclusive = true,
				auto_delete = true }),

	% subscribe to messages
	#'basic.consume_ok' { consumer_tag = Tag } =
		amqp_channel:subscribe (
			Channel,
			#'basic.consume' { queue = ReceiveQueue },
			self ()),

	% wait for confirmation
	receive
		#'basic.consume_ok' {} ->
			ok
	end,

	% setup client
	Client = #client {
		channel = Channel,
		tag = Tag,
		receive_queue = ReceiveQueue },

	% return
	{ ok, Client }.

% ---------- send

-spec send (client (), binary (), any ()) -> ok.

send (Client, SendQueue, Data) ->

	Payload = list_to_binary (mochijson2:encode (Data)),

	ok = amqp_channel:cast (
		client_channel (Client),
		#'basic.publish' { exchange = <<"">>, routing_key = SendQueue },
		#amqp_msg { payload = Payload }),

	ok.

% ---------- start_link

-spec start_link (string ()) -> { ok, pid () }.

start_link (ServerName) ->

	gen_server:start_link (
		{ local, list_to_atom (ServerName ++ "_mq") },
		?MODULE,
		[],
		[]).

% ---------- stop

-spec stop (this ()) -> ok.

stop (Pid) ->

	ok = gen_server:call (
		Pid,
		terminate),

	ok.

% ==================== private

% ---------- init

init ([]) ->

	% mq connect
	{ ok, MqConnection } =
		amqp_connection:start (
			#amqp_params_network {}),

	% setup state
	State = #state {
		connection = MqConnection },

	% and return
	{ ok, State }.

% ---------- handle_call get_connection

handle_call ({ get_connection }, _From, State) ->

	#state {
		connection = Connection
	} = State,

	{ reply, Connection, State };

% ---------- handle_call terminate

handle_call (terminate, _From, State) ->

    { stop, normal, ok, State };

% ---------- handle_call

handle_call (Request, From, State) ->

	io:format ("alc_mq:handle_call (~p, ~p, ~p)\n",
		[ Request, From, State ]),

	{ reply, error, State }.

% ---------- handle_cast

handle_cast (Request, State) ->

	io:format ("alc_mq:handle_cast (~p, ~p)\n",
		[ Request, State ]),

	{ noreply, State }.

% ---------- handle_info shutdown

handle_info ({ shutdown }, State) ->

	{ stop, normal, State };

% ---------- handle_info

handle_info (Info, State) ->

	io:format ("alc_mq:handle_info (~p, ~p)\n",
		[ Info, State ]),

	{ noreply, State }.

% ---------- terminate

terminate (_Reason, State) ->

	#state {
		connection = Connection
	} = State,

	% close mq connection
	amqp_connection:close (Connection),

	ok.

% ---------- code_change

code_change (_OldVsn, State, _Extra) ->

	{ ok, State }.
