module Byteback

	# Represents a particular timestamped backup directory
	class Snapshot
		class << self
			# What order to remove snapshots in to regain disk space?
			#
			# Order backups by their closeness to defined backup times, which are
			# listed in a set order (i.e. today's backup is more important than yesterday's).
			#
			BACKUP_IMPORTANCE = [0, 1, 2, 7, 14, 21, 28, 56, 112]

			def sort_by_importance(snapshots_unsorted, now=Time.now)
				snapshots_sorted = []

				# FIXME: takes about a minute to sort 900 items,
				# seems like that ought to be quicker than O(n^2)
				#
				while !snapshots_unsorted.empty?
					BACKUP_IMPORTANCE.each do |days|
						target_time = now - (days*86400)
						closest = snapshots_unsorted.inject(nil) do |best, snapshot|
							if best.nil? || (snapshot.time-target_time).abs < (best.time-target_time).abs
								snapshot
							else
								best
							end
						end
						break unless closest
						snapshots_sorted << snapshots_unsorted.delete(closest)
					end
				end

				snapshots_sorted
			end
		end

		attr_reader :backup_directory, :path

		def initialize(backup_directory, snapshot_path)
			@backup_directory = backup_directory
			@path = snapshot_path
			time # throws ArgumentError if it can't parse
			nil
		end

		def time
			Time.parse(path)
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
