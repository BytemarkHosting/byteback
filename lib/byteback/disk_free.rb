
module Byteback
	# Icky way to find out free disc space on our mount
	#
	class DiskFree
		def initialize(mount)
			@mount = mount
		end

		def total
			all[2]
		end

		def used
			all[3]
		end

		def available
			all[4]
		end

		def fraction_used
			disk_device, disk_fs, disk_total, disk_used, disk_available, *rest = all
			disk_used.to_f / disk_available
		end

		protected

		def all
			disk_device, disk_fs, disk_total, disk_used, disk_available, *rest = 
				df.
				split("\n")[1].
				split(/\s+/).
				map { |i| /^[0-9]+$/.match(i) ? i.to_i : i }
		end

		def df
			`/bin/df -T -P -B1 #{@mount}`
		end
	end
end
