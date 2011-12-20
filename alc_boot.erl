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

-export ([
	start/0 ]).

-record (state, {
	mq,
	main }).

start () ->

	% process args
	ServerName = server_name (),
	Mode = mode (),
	PidFile = pid_file (),

	% write pid file
	write_pid (PidFile),

	% start mq process
	{ ok, Mq } =
		alc_mq:start_link (ServerName),

	% start main process
	{ ok, Main } = case Mode of

		hyper ->
			alc_hyper:start_link (Mq, ServerName);

		simple ->
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
			routing_key = list_to_binary ("alchemy-parent-" ++ ServerName) },
		#amqp_msg{ payload = Payload }),

	% close channel
	amqp_channel:close (Channel),

	% return
	ok.

server_name () ->

	case init:get_argument ('alc-server-name') of

		{ ok, [ [ Value ] ] } ->
			Value;

		error ->
			io:format ("Must specify -alc-mode\n"),
			halt (1)
	end.

mode () ->

	case init:get_argument ('alc-mode') of

		{ ok, [ [ ModeString ] ] } ->

			Mode = list_to_atom (ModeString),
			case lists:member (Mode, [ hyper, simple ]) of

				true ->
					list_to_atom (ModeString);

				false ->
					io:format ("Invalid mode: ~s\n", [ ModeString ]),
					halt (1)

			end;

		error ->
			io:format ("Must specify -alc-mode\n"),
			halt (1)
	end.

write_pid (Filename) ->

	case Filename of

		X when is_list (X) ->

			% open file
			{ ok, File } =
				file:open (Filename, [ write ]),

			% write pid
			io:format (File, "~s\n", [ os:getpid () ]),

			% close file
			ok = file:close (File),

			ok;

		undefined ->

			ok
	end.

pid_file () ->

	case init:get_argument ('alc-pid-file') of

		{ ok, [ [ Filename ] ] } ->
			Filename;

		error ->
			undefined

	end.

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

