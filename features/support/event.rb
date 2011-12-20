
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

event_start
