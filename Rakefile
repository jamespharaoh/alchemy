
require "pp"

DIR = File.dirname __FILE__
Dir.chdir DIR

task :default => [ :compile ]

task :compile do

	FileUtils.mkdir_p "build"

	Dir.glob("erlang/*.erl").each do |source|
		name = File.basename source, ".erl"
		target = ".build/#{name}.beam"
		next if FileUtils.uptodate? target, [ source ]
		cmd = "erlc -o .build #{source}"
		puts cmd
		system cmd or exit 1
	end

end
