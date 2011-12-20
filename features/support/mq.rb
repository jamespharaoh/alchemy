
require "amqp"

def mq_start
	return if $mq_started
	$stderr.puts "mq_start"

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
	$stderr.puts "mq_stop"

	event_do do |cb|
		$mq_channel.close do
			$mq_connection.close do
				cb.call nil
			end
		end
	end

	$mq_started = false
end

mq_start
