module Byteback
	# Represent a directory full of backups where "current"  is a subvolume
	# which is snapshotted to frozen backup directories called e.g. 
	# "yyyy-mm-ddThh:mm+zzzz".
	#
	class BackupDirectory
		attr_reader :dir

		def initialize(dir)
			@dir = Dir.new(dir)
			current
		end

		# Return total amount of free space in backup directory (bytes)
		#
		def free
			df = DiskFree.new(@dir.path)
			df.total - df.used
		end

		# Return an array of Times representing the current list of 
		# snapshots.
		#
		def snapshot_times
			@dir.entries.map do |entry|
				begin
					Time.parse(entry)
				rescue ArgumentError => error
					nil
				end
			end.
			compact.
			sort
		end

		# What order to remove snapshots in to regain disk space?
		#
		# Order backups by their closeness to defined backup times, which are
		# listed in a set order (i.e. today's backup is more important than yesterday's).
		#
		BACKUP_IMPORTANCE = [0, 1, 2, 3, 7, 14, 21, 28, 56, 112]
		def snapshot_times_by_importance
			now = Time.now
			snapshot_times_unsorted = snapshot_times
			snapshot_times_sorted = []
			while !snapshot_times_unsorted.empty?
				BACKUP_IMPORTANCE.each do |days|
					target_time = now + (days*86400)
					closest = snapshot_times_unsorted.inject(nil) do |best, time|
						if best.nil? || (time-target_time).abs < (best-target_time).abs
							time
						else
							best
						end
					end
					break unless closest
					snapshot_times_sorted << snapshot_times_unsorted.delete(closest)
				end
			end
			snapshot_times_sorted
		end

		# Returns the size of the given snapshot (runs du, may be slow)
		#
		# Would much prefer to take advantage of this feature:
		#   http://dustymabe.com/2013/09/22/btrfs-how-big-are-my-snapshots/
		# but it's not currently in Debian/wheezy.
		#
		def snapshot_size(time=snapshot_times.last)
			`du -s -b #{snapshot_path(time)}`.to_i
		end

		def average_snapshot_size(number=10)
			snapshot_times.sort[0..number].inject(0) { |total, time| snapshot_size(time) } / number
		end

		# Create a new snapshot of 'current'
		#
		def new_snapshot!
			system_no_error("btrfs subvolume snapshot -r #{current.path} #{snapshot_path}")
		end

		def delete_snapshot!(time)
			system_no_error("btrfs subvolume delete #{snapshot_path(time)}")
		end

		def current
			Dir.new("#{dir.path}/current")
		end

		def snapshot_path(time=Time.now)
			"#{dir.path}/#{time.strftime("%Y-%m-%dT%H:%M%z")}"
		end

		protected

		def system_no_error(*args)
	      args[-1] += " > /dev/null" unless @verbose
			raise RuntimeError.new("Command failed: "+args.join(" ")) unless
			  system(*args)
		end
	end
end
