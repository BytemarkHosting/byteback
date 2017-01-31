
require 'byteback/restore_file'

module Byteback
  class Restore
    def self.find(byteback_root, snapshot, paths)
      x = Byteback::Restore.new(byteback_root)
      x.snapshot = snapshot
      x.find(paths)
      x
    end

    #
    # This takes a string or array of strings as an argument, and QP encodes
    # each argument.  This is for safe parsing of spaces etc at the remote end.
    #
    # Returns an array of encoded strings.
    #
    def self.encode_args(args)
      [args].flatten.collect { |s| [s].pack('M').gsub(' ', '=20').gsub("=\n", '') }
    end

    #
    # This takes a string or array of strings, each of which is quoted
    # printable, and unpacks it.
    #
    # Returns an array of decoded strings.
    #
    def self.decode_args(args)
      [args].flatten.collect { |s| (s + "=\n").unpack('M') }.flatten
    end

    def initialize(byteback_root)
      #
      # We use expand_path here to make sure we have a full path, with no
      # trailing slash.
      #
      @byteback_root = File.expand_path(byteback_root)
      @now = Time.now
      @snapshot = '*'
      @results = []
    end

    def snapshot=(r)
      if r =~ /^[a-z0-9:\+\*\-]+$/i
        @snapshot = r
      else
        puts "*** Warning: Bad snapshot #{r.inspect}"
      end
    end

    attr_reader :results

    def find(paths, opts = {})
      results = []
      #
      # Make sure we've an array, and that we get rid of any ".." nonsense.
      #
      paths = [paths].flatten.collect { |p| File.expand_path(p, '/') }
      seen  = []

      @results = paths.collect do |path|
        Dir.glob(File.expand_path(File.join(@byteback_root, @snapshot, path))).collect do |f|
          Byteback::RestoreFile.new(f, @byteback_root, @now)
        end
      end.flatten

      #
      # If we want an unpruned list, return it now.
      #
      if opts == true || (opts.is_a?(Hash) && opts[:verbose])
        @results = @results.sort { |a, b| [a.path, a.snapshot_time] <=> [b.path, b.snapshot_time] }
        return @results
      end

      @results = @results.sort { |a, b| [a.path, b.snapshot_time] <=> [b.path, a.snapshot_time] }
      pruned_results = []

      @results.each do |r|
        if opts.is_a?(Hash) && opts[:all]
          pruned_results << r unless pruned_results.include?(r)
        else
          pruned_results << r unless pruned_results.any? { |pr| pr.path == r.path }
        end
      end

      @results = pruned_results
    end

    def list
      heading = %w(snapshot modestring size uid gid mtime path)
      listings = [heading]
      @results.sort.each do |r|
        listing = heading.collect { |m| r.__send__(m.to_sym).to_s }
        listing[-1] << ' -> ' + r.readlink if r.symlink?
        listings << listing
      end

      field_sizes = [0] * heading.length

      listings.each do |fields|
        fields.each_with_index do |field, i|
          field_sizes[i] = (field_sizes[i] > field.length) ? field_sizes[i] : field.length
        end
      end

      fmt = field_sizes.collect { |i| "%-#{i}.#{i}s" }.join(' ')

      bar = '-' * field_sizes.inject(field_sizes.length) { |m, s| m += s }

      output = []
      listings.each do |fields|
        output << sprintf(fmt, *fields)
        if bar
          output << bar
          bar = nil
        end
      end

      output.join("\n")
    end
  end
end
