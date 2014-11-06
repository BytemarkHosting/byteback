require 'logger'
require 'syslog'

module Byteback
	# Translates Ruby's Logger calls to similar calls to Syslog 
	# (implemented in Ruby 2.0 as Syslog::Logger)
	#
	class SyslogProxy
		class << self
			def debug(*a); Syslog.log(Syslog::LOG_DEBUG, *a); end
			def info(*a); Syslog.log(Syslog::LOG_INFO, *a); end
			def warn(*a); Syslog.log(Syslog::LOG_WARNING, *a); end
			def error(*a); Syslog.log(Syslog::LOG_ERR, *a); end
			def fatal(*a); Syslog.log(Syslog::LOG_EMERG, *a); end
		end
	end

	# Log proxy class that we can include in our scripts for some simple
	# logging defaults.
	#
	module Log
		@@me = File.expand_path($0).split("/").last

		@@logger = if STDIN.tty? && !ENV['BYTEBACK_TO_SYSLOG']
			logger = Logger.new(STDERR)
			logger.level = Logger::DEBUG
			logger.formatter = proc { |severity, datetime, progname, msg|
				if severity == "FATAL" || severity == "ERROR"
					"*** #{msg}\n"
				else
					"#{msg}\n"
				end
			}
			logger
		else
			Syslog.open(@@me)
			SyslogProxy
		end

		def debug(*a); @@logger.__send__(:debug, *a); end
		def info(*a); @@logger.__send__(:info, *a); end
		def warn(*a); @@logger.__send__(:warn, *a); end
		def fatal(*a); @@logger.__send__(:fatal, *a); exit 1; end
		def error(*a); @@logger.__send__(:error, *a); end
	end
end
