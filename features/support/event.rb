#
# Filename: features/support/event.rb
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

require "eventmachine"
require "fiber"

def event_start
	return if $event_started
	$stderr.puts "event_start"
	$event_fiber = Fiber.new do
		EM.run do
			Fiber.yield
		end
	end
	$event_fiber.resume
	$event_started = true
end

def event_stop
	return unless $event_started
	$stderr.puts "event_stop"
	EM.stop
	$event_fiber.resume
	$event_started = false
	at_exit { event_stop }
end

def event_do &block
	throw "Error" unless $event_started
	throw "Error" if Fiber.current == $event_fiber
	EM.next_tick do
		block.call lambda { |ret| Fiber.yield ret }
	end
	$event_fiber.resume
end

Before do
	event_start
end
