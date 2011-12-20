#
# Filename: features/support/server.rb
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

Before do
	@server_names = []
	@server_responses = []
end

def server_name_default
	"alpha"
end

def server_start server_name
	return if @server_names.include? server_name
	hyper_start
	response = hyper_call "start", server_name
	@server_names << server_name
end

def server_call server_name, name, *args

	server_name = server_name_default \
		if server_name == :default

	# make sure server is running
	server_start server_name

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
			:routing_key => "alchemy-server-#{server_name}"
		cb.call nil
	end

	# read response
	@server_responses << event_do do |cb|
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

end

def server_response
	return @server_responses.shift
end
