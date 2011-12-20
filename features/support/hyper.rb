#
# Filename: features/support/hyper.rb
#
# This is part of the Alchemy configuration database. For more
# information, visit our home on the web at
#
#     https://github.com/jamespharaoh/alchemy
#
# Copyright 2011 James Pharaoh
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

After do
	return unless $hyper_started
	hyper_reset
end

def hyper_start
	return if $hyper_started

	event_start
	mq_start

	log "hyper_start"

	# generate server name
	$hyper_token = gen_token

	# listen for startup notification
	queue = event_do do |cb|
		$mq_channel.queue \
			"alchemy-parent-cucumber-#{$hyper_token}", \
			:auto_delete => true, \
			:exclusive => true \
		do |queue|
			confirm_cb = lambda { |arg| cb.call queue }
			queue.subscribe :confirm => confirm_cb do |headers, payload|
				queue.delete do
					$mq_parent_cb.call nil
				end
			end
		end
	end

	# start server
	args = %W[
		erl
		-noshell
		-bool start_clean
		-s alc_boot
		-sname cucumber-#{$hyper_token}
		--
		-alc-server-name cucumber-#{$hyper_token}
		-alc-mode hyper
		-alc-pid-file /tmp/alchemy-cucumber-#{$hyper_token}.pid
	]
	cmd = ENV["LOG"] ?
		"#{args.join " "} &"
		: "#{args.join " "} >/dev/null &"
	system cmd

	# wait for startup notification
	event_do do |cb|
		$mq_parent_cb = cb
	end

	$hyper_started = true
	at_exit { hyper_stop }
end

def hyper_stop
	return unless $hyper_started

	log "hyper_stop"

	# send terminate to server
	event_do do |cb|
		data = [ "shutdown" ]
		$mq_exchange.publish JSON.dump(data), \
			:routing_key => "alchemy-hyper-cucumber-#{$hyper_token}"
		cb.call nil
	end

	$hyper_started = false
end

def hyper_call name, *args

	# set up response queue
	client_token = gen_token
	client_queue = event_do do |cb|
		$mq_channel.queue \
			"alchemy-client-#{client_token}", \
			:auto_delete => true, \
			:exclusive => true \
		do |queue|
			cb.call queue
		end
	end

	# send request to server
	request_token = gen_token
	event_do do |cb|
		data = [ name, client_token, request_token ] + args
		$mq_exchange.publish JSON.dump(data), \
			:routing_key => "alchemy-hyper-cucumber-#{$hyper_token}"
		cb.call nil
	end

	# read response
	resp_name, *resp_args = event_do do |cb|
		client_queue.subscribe do |headers, payload|
			name, token, *args = JSON.parse payload
			if token == request_token
				cb.call [ name, *args ]
			else
				raise "Error"
			end
		end
	end

	# delete queue
	event_do do |cb|
		client_queue.delete do
			cb.call nil
		end
	end

	# and return
	return [ resp_name, *resp_args ]
end

def hyper_reset
	name, *args = hyper_call "reset"
	case [ name, args.size ]

	when [ "reset-ok", 0 ]
		return

	else
		raise "Error"

	end
end
