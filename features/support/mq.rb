#
# Filename: features/support/mq.rb
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

require "amqp"

def mq_start
	return if $mq_started
	log "mq_start"

	event_start

	event_do do |cb|
		AMQP.connect do |mq_connection|
			$mq_connection = mq_connection
			AMQP::Channel.new $mq_connection do |mq_channel|
				$mq_channel = mq_channel
				$mq_exchange = $mq_channel.default_exchange
				cb.call nil
			end
		end
	end

	$mq_started = true
	at_exit { mq_stop }
end

def mq_stop
	return unless $mq_started
	log "mq_stop"

	event_do do |cb|
		$mq_channel.close do
			$mq_connection.close do
				cb.call nil
			end
		end
	end

	$mq_started = false
end
