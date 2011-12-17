%
% Filename: alc_boot.erl
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

-module (alc_boot).

-include_lib ("amqp_client/include/amqp_client.hrl").

-export ([ start/0 ]).

-record (state, { mq, main }).

start () ->

	% process args
	Args = init:get_plain_arguments (),
	[ Mode, ServerName ] = Args,

	% start mq process
	{ ok, Mq } =
		alc_mq:start_link (ServerName),

	% start main process
	{ ok, Main } = case Mode of

		"hyper" ->
			alc_hyper:start_link (Mq, ServerName);

		"simple" ->
			alc_main:start_link (Mq, ServerName)

	end,

	% notify parent
	notify_parent (Mq, ServerName),

	% setup state
	State = #state {
		mq = Mq,
		main = Main },

	% go to main loop
	loop (State).

notify_parent (Mq, ServerName) ->

	% open channel
	{ ok, Channel } =
		amqp_connection:open_channel (
			alc_mq:get_connection (Mq)),

	% construct payload
	Payload = list_to_binary (
		mochijson2:encode (ready)),

	% cast message
	amqp_channel:cast (
		Channel,
		#'basic.publish' {
			exchange = <<"">>,
			routing_key = list_to_binary ("alchemy-notify-" ++ ServerName) },
		#amqp_msg{ payload = Payload }),

	% close channel
	amqp_channel:close (Channel),

	% return
	ok.

loop (State) ->

	% extract state
	#state {
		main = Main
	} = State,

	receive

		{ 'EXIT', Main, Reason } ->
			stop (Reason, State);

		Any ->
			io:format ("ERROR alc_boot received ~p\n", [ Any ]),
			loop (State)

	end.

stop (normal, State) ->

	% extract state
	#state {
		mq = Mq
	} = State,

	% shut down mq
	alc_mq:stop (Mq),

	halt (0);

stop (Reason, _State) ->

	io:format ("Terminating for reason ~p\n", [ Reason ]),

	halt (1).

