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

-export ([ start/0 ]).

start () ->

	% process args
	Args = init:get_plain_arguments (),
	[ ServerName ] = Args,

	% start main process
	{ ok, MainPid } = alc_main:start_link (ServerName),

	% and wait for it to finish
	loop (MainPid).

loop (MainPid) ->
	receive

		{ 'EXIT', MainPid, Reason } ->
			stop (Reason);

		Any ->
			io:format ("ERROR alc_boot received ~p\n", [ Any ]),
			loop (MainPid)
	end.

stop (normal) ->
	halt (0);

stop (Reason) ->
	io:format ("Terminating for reason ~p\n", Reason),
	halt (1).
