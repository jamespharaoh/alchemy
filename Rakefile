
require "pp"

DIR = File.dirname __FILE__
Dir.chdir DIR

task :default => [ :compile ]

task :compile do

	do_mkdir ".build"

	Dir.glob("erlang/*.erl").each do |source|
		name = File.basename source, ".erl"
		target = ".build/#{name}.beam"
		next if FileUtils.uptodate? target, [ source ]
		cmd = "erlc +debug_info -o .build #{source}"
		puts cmd
		system cmd or exit 1
	end

end

task :dialyze do

	apps = %W[
		asn1
		compiler
		crypto
		debugger
		edoc
		erts
		gs
		hipe
		inets
		kernel
		mnesia
		os_mon
		otp_mibs
		public_key
		runtime_tools
		sasl
		snmp
		stdlib
		ssl
		syntax_tools
		tools
		webtool
		wx
		xmerl
	]

	do_dialyze_build_plt "erlang", apps

	apps = %W[
		amqp_client
		rabbit_common
	]

	do_dialyze_add_to_plt "libraries", "erlang", apps

	do_dialyze "libraries", ".build"
end

def do_mkdir name
	return if Dir.exist? name
	cmd = "mkdir #{name}"
	system cmd or exit 1
end

def do_dialyze_build_plt dest, apps
	dest = ".dialyzer/#{dest}.plt"
	return if File.exist? dest
	do_mkdir ".dialyzer"
	args = %W[
		--build_plt
		--output_plt #{dest}
		--apps #{apps.join " "}
	]
	cmd = "dialyzer #{args.join " "}"
	puts cmd
	system cmd or exit 1
end

def do_dialyze_add_to_plt dest, src, apps
	dest = ".dialyzer/#{dest}.plt"
	src = ".dialyzer/#{src}.plt"
	return if FileUtils.uptodate? dest, [ src ]
	do_mkdir ".dialyzer"
	args = %W[
		--add_to_plt
		--output_plt #{dest}
		--plts #{src}
		--apps #{apps.join " "}
	]
	cmd = "dialyzer #{args.join " "}"
	puts cmd
	system cmd or exit 1
end

def do_dialyze plt, name
	plt = ".dialyzer/#{plt}.plt"
	args = %W[
		--plt #{plt}
		--no_check_plt
		#{name}
	]
	cmd = "dialyzer #{args.join " "}"
	puts cmd
	system cmd or exit 1
end
