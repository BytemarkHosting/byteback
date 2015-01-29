require 'logger'
require 'syslog'

module Byteback
	# Translates Ruby's Logger calls to similar calls to Syslog 
	# (implemented in Ruby 2.0 as Syslog::Logger).
	# 
	# We need to neuter % signs which are taken as format strings.
	#
	class SyslogProxy
		class << self
			def debug(m); log_nopc(Syslog::LOG_DEBUG, m); end
			def info(m); log_nopc(Syslog::LOG_INFO, m); end
			def warn(m); log_nopc(Syslog::LOG_WARNING, m); end
			def error(m); log_nopc(Syslog::LOG_ERR, m); end
      #
      # syslog(3) says:
      #
      # LOG_EMERG means "system is unusable"
      # LOG_ERR   means "error conditions"
      #
      # Errors might be fatal to Byteback, but they're unlikely to make the
      # whole server unusable.  So lets dial this down to ERR from EMERG.
      #
			def fatal(m); log_nopc(Syslog::LOG_ERR, m); end

			def log_nopc(level, m)
				Syslog.log(level, m.gsub("%","%%"))
			end
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
