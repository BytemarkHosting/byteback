
require 'byteback/restore_file'

module Byteback

  class Restore

    def self.find(byteback_root, revision, paths)
      x = Byteback::Restore.new(byteback_root)
      x.revision = revision
      x.find(paths)
      return x
    end

    #
    # This takes a string or array of strings as an argument, and QP encodes
    # each argument.  This is for safe parsing of spaces etc at the remote end.
    #
    # Returns an array of encoded strings.
    #
    def self.encode_args(args)
      [args].flatten.collect{|s| [s].pack("M").gsub(" ","=20").gsub("=\n","")}
    end

    #
    # This takes a string or array of strings, each of which is quoted
    # printable, and unpacks it.
    #
    # Returns an array of decoded strings.
    #
    def self.decode_args(args)
      [args].flatten.collect{|s| (s + "=\n").unpack("M")}.flatten
    end

    def initialize(byteback_root)
      # 
      # We use expand_path here to make sure we have a full path, with no
      # trailing slash.
      #
      @byteback_root = File.expand_path(byteback_root)
      @now     = Time.now
      @revision = "*"
      @results = []
    end

    def revision=(r)
      if r =~ /^[a-z0-9:\+\*\-]+$/i
        @revision = r
      else
        puts "*** Warning: Bad revision #{r.inspect}"
      end
    end

    def results
      @results
    end

    def find(paths, full = false)
      results = []
      #
      # Make sure we've an array, and that we get rid of any ".." nonsense.
      #
      paths = [paths].flatten.collect{|p| File.expand_path(p, "/")}
      seen  = []

      @results = paths.collect do |path|
        Dir.glob(File.expand_path(File.join(@byteback_root, @revision, path))).collect do |f|
          restore_file = Byteback::RestoreFile.new(f, @byteback_root, @now)
        end
      end.flatten.sort{|a,b| [a.path, a.snapshot_time] <=> [b.path, b.snapshot_time]}

      #
      # If we want an unpruned list, return it now.
      #
      return @results if full

      pruned_results = []

      @results.each do |r|
        pruned_results << r unless pruned_results.include?(r)
      end

      @results = pruned_results
    end

    def list
      heading = %w(snapshot modestring size uid gid mtime path)
      listings = [heading]
      @results.sort.each do |r|
        listing = heading.collect{|m| r.__send__(m.to_sym).to_s }
        if r.symlink?
          listing[-1] << " -> "+r.readlink
        end
        listings << listing
      end

      field_sizes = [0]*heading.length

      listings.each do |fields|
        fields.each_with_index do |field, i|
          field_sizes[i] = (field_sizes[i] > field.length) ? field_sizes[i] : field.length
        end
      end

      fmt = field_sizes.collect{|i| "%-#{i}.#{i}s"}.join(" ")

      bar = "-"*field_sizes.inject(field_sizes.length){|m,s| m+=s}

      output = []
      listings.each do |fields|
        output << sprintf(fmt, *fields)
        if bar
          output << bar
          bar = nil
        end
      end

      return output.join("\n")
    end

  end
end
