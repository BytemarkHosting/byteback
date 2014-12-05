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
				snapshots_sorted = []
				scores = Array.new{|h,k| h[k] = []}
				times  = snapshots_unsorted.map(&:time)

				BACKUP_IMPORTANCE.each_with_index do |days, backup_idx|
						target_time = now.to_i - (days*86400)
						weight = days.to_f - (backup_idx == 0 ? 0 : BACKUP_IMPORTANCE[backup_idx-1])
						scores << times.map{|t| (t.to_i - target_time).abs/weight }
				end

				#
				# Find the index of the lowest score from the list of BACKUP_IMPORTANCE
				#
				nearest_target = scores.transpose.map{|s| s.find_index(s.min)}

				BACKUP_IMPORTANCE.each_index do |backup_idx|
					#
					# Find the indicies of the snapshots that match the current BACKUP_IMPORTANCE index, and sort them according to their score.
					best_snapshot_idxs = nearest_target.each_index.
						select{|i| nearest_target[i] == backup_idx}.
						sort{|a,b| scores[backup_idx][a] <=> scores[backup_idx][b]}

					#
					# Append them to the array.
					#
					snapshots_sorted += snapshots_unsorted.values_at(*best_snapshot_idxs)
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
			Time.parse(File.basename(path))
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
