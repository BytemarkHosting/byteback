require 'tempfile'

module Byteback
  module Util
    @@lockfile = '/var/lock/byteback/byteback.lock'

    def remove_lockfile!
      File.unlink(@@lockfile)
    rescue Errno::ENOENT
    end

    def claim_lockfile!
      # Check the lockfile first
      if File.directory?(File.dirname(@@lockfile))
        if File.exist? @@lockfile
          # check the lockfile is sane
          exist_pid = File.read(@@lockfile).to_i
          if exist_pid > 1 && exist_pid < (File.read('/proc/sys/kernel/pid_max').to_i)
            begin
              Process.getpgid(exist_pid)
              # if no exception, process is running, abort
              fatal("Process is running (#{exist_pid} from #{@@lockfile})")
            rescue Errno::ESRCH
              # no process running with that pid, pidfile is stale
              remove_lockfile!
            end
          else
            # lockfile isn't sane, remove it and continue
            remove_lockfile!
          end
        end
      else
        Dir.mkdir(File.dirname(@@lockfile))
        # lockfile didn't exist so just carry on
      end

      # Own the pidfile ourselves
      File.open(@@lockfile, 'w') do |lockfile|
        lockfile.puts Process.pid
      end
    end

    def lock_out_other_processes(name)
      @@lockfile = "/var/lock/byteback/#{name}.lock"
      claim_lockfile!
      at_exit { remove_lockfile! }
    end

    def log_system(*args)
      debug('system: ' + args.map { |a| / /.match(a) ? "\"#{a}\"" : a }.join(' '))
      rd, wr = IO.pipe
      pid = fork
      if pid.nil? # child
        rd.close
        STDOUT.reopen(wr)
        STDERR.reopen(wr)
        # any cleanup actually necessary here?
        exec(*args)
      end
      wr.close
      rd.each_line { |line| debug(line.chomp) }
      pid2, status = Process.waitpid2(pid, 0)
      status.exitstatus
    end
  end
end
