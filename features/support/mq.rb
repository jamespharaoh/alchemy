
require "eventmachine"
require "fiber"

# start event machine
Before do
	$event_fiber = Fiber.new do
		EM.run do
			Fiber.yield
		end
	end
	$event_fiber.resume
end

# stop event machine
After do
	EM.stop
	$event_fiber.resume
end

