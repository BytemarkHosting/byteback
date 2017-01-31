require 'sys/filesystem'

module Byteback
  class DiskFreeReading < Struct.new(:fsstat, :time)
    def initialize(fsstat, time = Time.now)
      self.fsstat = fsstat
      self.time = time
    end

    # helper method to return %age of disc space free
    #
    def percent_free
      fsstat.blocks_available * 100 / fsstat.blocks
    end
  end

  # A simple round-robin list  to store a short history of a given mount
  # point's disk space history.
  #
  class DiskFreeHistory
    attr_reader :mountpoint, :history_file

    MINIMUM_INTERVAL = 5 * 60 # don't take readings more than 5 mins apart
    MAXIMUM_AGE = 7 * 24 * 60 * 60 # delete readings after a week

    # Initialize a new list storing the disc space history for the given
    # mount point.
    #
    def initialize(mountpoint, history_file = nil)
      history_file = "#{mountpoint}/.disk_free_history" unless
        history_file
      @history_file = history_file
      @mountpoint = mountpoint
      load!
    end

    # Take a new reading
    #
    def new_reading!
      reading = DiskFreeReading.new(Sys::Filesystem.stat(@mountpoint))

      # Don't record a new reading if it's exactly the same as last time,
      # and less than the minimum interval.
      #
      return nil if @list.last &&
                    @list.last.fsstat.blocks_available == reading.fsstat.blocks_available &&
                    Time.now - @list.last.time < MINIMUM_INTERVAL

      @list << reading

      save!
    end

    def list
      load! unless @list
      @list
    end

    def gradient(last_n_seconds, &value_from_reading)
      value_from_reading ||= proc { |r| r.fsstat.blocks_available }
      earliest = Time.now - last_n_seconds

      total = 0
      readings = 0
      later_reading = nil

      list.reverse.each do |reading|
        if later_reading
          difference =
            yield reading -
            yield later_reading
          total += difference
        end
        readings += 1
        break if reading.time < earliest
        later_reading = reading
      end

      return 0 if readings == 0

      total / readings
    end

    protected

    def load!
      File.open(@history_file) do |fh|
        @list = Marshal.restore(fh.read(1_000_000))
      end
    rescue Errno::ENOENT, TypeError => err
      @list = []
      new_reading!
    end

    def save!
      list.shift while Time.now - list.first.time > MAXIMUM_AGE

      tmp = "#{@history_file}.#{$PROCESS_ID}.#{rand(9_999_999_999)}"
      begin
        File.open(tmp, 'w') do |fh|
          fh.write(Marshal.dump(list))
          File.rename(tmp, @history_file)
        end
      ensure
        File.unlink(tmp) if File.exist?(tmp)
      end
    end
  end
end
