module Byteback

	# Represents a particular timestamped backup directory
	class Snapshot
		class << self
			# What order to remove snapshots in to regain disk space?
			#
			# Order backups by their closeness to defined backup times, which are
			# listed in a set order (i.e. today's backup is more important than yesterday's).
			#
			BACKUP_IMPORTANCE = [1, 2, 7, 14, 21, 28, 56, 112]

			def sort_by_importance(snapshots_unsorted, now=Time.now)
                return snapshots_unsorted if ( snapshots_unsorted.size < 1 )

        # 
        # Keep the last 7 days backups
        #
        snapshots_sorted   = []
        snapshots_unsorted = snapshots_unsorted.sort_by(&:time).reverse
        
        #
        # Group snapshots by host
        #
        snapshots_by_host = Hash.new{|h,k| h[k] = []}

        snapshots_unsorted.each do |snapshot|
          snapshots_by_host[snapshot.host] << snapshot
        end

        #
        # We want the snapshot nearest to the middle of the day each day.
        #
        today_midday = Time.mktime(*([0,0,12]+now.utc.to_a.last(7)))

        #
        # We want today, and the previous seven days
        #
        targets = [today_midday]
        targets += 6.times.map{ today_midday -= 86400 }

        #
        # Now the previous four Sundays (we should bump on a week if today is a Sunday!)
        #
        today_midday -= (today_midday.wday == 0 ? 7 : today_midday.wday )*86400
        targets << today_midday
        targets += 3.times.map{ today_midday -= 7*86400 }

        #
        # Our 28 day periods are anchored on Time.at(0).  However this was a
        # Thursday, so we have to add 3 days to get it to Sunday.
        #
        targets << (today_midday -= ((today_midday.to_i / 86400.0).floor % 28 - 3)*86400)  

        #
        # Continue removing 28 day periods until we get beyond the oldest backup time.
        #
        targets << (today_midday -= 28*86400) while today_midday > snapshots_unsorted.last.time

        #
        # This has records the last nearest snapshot for each host
        #
        last_nearest = {}

        #
        # For each target, and for each host, find the nearest snapshot
        #
        targets.each do |target|
          snapshots_by_host.each do |host, snapshots|
            next if snapshots.empty?

            nearest = snapshots.sort{|a,b| (a.time - target).abs <=> (b.time - target).abs }.first

            #
            # Don't process any more if the last snapshot for this for this
            # host was more recent, i.e. we've reached the oldest, and are
            # bouncing back again.
            #
            if last_nearest[host].nil? or last_nearest[host].time > nearest.time
              last_nearest[host] = nearest
              snapshots_by_host[host]  -= [nearest]
              snapshots_sorted         << nearest
            end

          end

        end

        #
        # Remove any snapshots we've already sorted and add in the remaining snapshots
        #
        snapshots_unsorted -= snapshots_sorted
        snapshots_sorted   += snapshots_unsorted

			  snapshots_sorted 
			end
		end

		attr_reader :backup_directory, :path

		def initialize(backup_directory, snapshot_path)
			@backup_directory = backup_directory
			@path = snapshot_path
			@time = Time.parse(File.basename(path)) # throws ArgumentError if it can't parse
			nil
		end

		def time
      @time
		end

    def host
      File.basename(File.dirname(path))
    end

		def <=>(b)
			time <=> b.time
		end

		def create!(from)
			system_no_error("/sbin/btrfs subvolume snapshot #{from} #{path}")
		end

		def delete!
			system_no_error("/sbin/btrfs subvolume delete #{path}")
		end

		# Returns the size of the given snapshot (runs du, may be slow)
		#
		# Would much prefer to take advantage of this feature:
		#   http://dustymabe.com/2013/09/22/btrfs-how-big-are-my-snapshots/
		# but it's not currently in Debian/wheezy.
		#
		def du
			`du -s -b #{path}`.to_i
		end

		protected

		def system_no_error(*args)
	      args[-1] += " > /dev/null" unless @verbose
			raise RuntimeError.new("Command failed: "+args.join(" ")) unless
			  system(*args)
		end
	end

	# Represent a directory full of backups where "current"  is a subvolume
	# which is snapshotted to frozen backup directories called e.g. 
	# "yyyy-mm-ddThh:mm+zzzz".
	#
	class BackupDirectory
		class << self
			# Return all backup directories
			#
			def all
				Dir.new(ENV['HOME']).entries.map do |entry|
					next if entry[0] == '.'
					name = File.expand_path(ENV['HOME'] + "/" + entry)
					File.directory?(name + "/current") ? BackupDirectory.new(name) : nil
				end.
				compact
			end

			# Returns every snapshot in every backup directory
			#
			def all_snapshots
				all.map { |dir| dir.snapshots }.flatten
			end
		end

		attr_reader :dir

		def initialize(dir)
			@dir = Dir.new(dir)
			raise Errno::ENOENT unless File.directory?(dir)
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
		def snapshots
			@dir.entries.map do |entry|
				next if entry[0] == '.' || entry == 'current'
				snapshot_path = File.expand_path(@dir.path + "/" + entry)
				next unless File.directory?(snapshot_path)
				begin
					Snapshot.new(self, snapshot_path)
				rescue ArgumentError => ae
					# directory name must represent a parseable Time
					nil
				end
			end.
			compact
		end

		# Create a new snapshot of 'current'
		#
		def new_snapshot!(time = Time.now)
			snapshot_path = time.strftime(dir.path + "/%Y-%m-%dT%H:%M%z")
			Snapshot.new(self, snapshot_path).create!(current.path)
		end

		def current
			Dir.new("#{dir.path}/current")
		end
	end
end
