
def server_start
	return if $server_started

	event_start
	mq_start

	# generate server name
	$server_token = (0...10).to_a.map { (?a..?z).to_a.sample }.join

	# listen for startup notification
	queue = event_do do |cb|
		$mq_channel.queue \
			"alchemy-parent-cucumber-#{$server_token}", \
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
		-sname cucumber-#{$server_token}
		--
		-alc-server-name cucumber-#{$server_token}
		-alc-mode hyper
		-alc-pid-file /tmp/alchemy-cucumber-#{$server_token}.pid
	]
	cmd = args.join " "
	puts cmd
	system "#{cmd} &"

	# wait for startup notification
	event_do do |cb|
		$mq_parent_cb = cb
	end

	$server_started = true
	at_exit { server_end }
end

def server_end
	return unless $server_started
	$stderr.puts "TODO: END SERVER PLEASE"
	$server_started = false
end

server_start
