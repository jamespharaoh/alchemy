
require "pp"

DIR = File.dirname __FILE__
Dir.chdir DIR

task :default => [ :compile ]

task :compile do

	unless Dir.exist? ".build"
		cmd = "mkdir .build"
		system cmd or exit 1
	end

	Dir.glob("erlang/*.erl").each do |source|
		name = File.basename source, ".erl"
		target = ".build/#{name}.beam"
		next if FileUtils.uptodate? target, [ source ]
		cmd = "erlc -o .build #{source}"
		puts cmd
		system cmd or exit 1
	end

end
