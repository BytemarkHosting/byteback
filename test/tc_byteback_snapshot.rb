$: << File.dirname(__FILE__)+"/../lib"

require 'test/unit'
require 'byteback/backup_directory'
require 'time'
# require 'mocha/test_unit'

class SnapshotTest < Test::Unit::TestCase

  def setup

  end

  def teardown

  end

  #
  # This class is supposed to work out which bits get pruned first
  #
  def test_sort_by_importance

    start = Time.now
      
    15.times do |limit|
      limit += 1
      biggest_offset = nil 
      backups = []
      offsets = []
      now   = Time.at(start.to_i) + rand(7)*86400
      day   = 0

      #
      # Do this test until we reach a maximum age
      #
      while true do

        backups << Byteback::Snapshot.new("/tmp", File.join("/tmp/",now.iso8601))

        while backups.length > limit do
          sorted_backups = Byteback::Snapshot.sort_by_importance(backups, now)
          backups.delete(sorted_backups.last)
        end

        offsets = backups.collect{|x| ((now - x.time)/86400.0).round }
 
        #
        # Each backup should have backups for the last 7 days, then the first four Sundays, and then the next mod 28 day after that
        #
        mod_28 = ((now.to_i / 86400.0).floor % 28 - 3)

        targets = ((0..6).to_a + 
          [7,14,21,28].to_a.collect{|i| i + now.wday} +
          [2*28 + mod_28]).select{|t| t < day}.first(limit).reverse

        assert_equal(targets - offsets, [], "Failed after day #{day} (#{now.wday}) for a limit of #{limit} backups")

        if biggest_offset.nil? or offsets.max > biggest_offset
          biggest_offset = offsets.max
        else
          puts "Oldest backup with space for #{limit} backups is #{offsets.max} days: #{offsets.join(", ")}" if $VERBOSE
          break
        end

        # Move on a day
        day += 1
        now += 86400
      end
    end
  end

  #
  # This run the same test as above, execpt with 3 hosts all competing for space
  #
  def test_sort_by_importance_with_multiple_hosts
    start = Time.now
      
    40.times do |limit|
      limit += 6
      biggest_offset = nil 
      backups = []
      offsets = []
      now   = Time.at(start.to_i) + rand(7)*86400
      day   = 0

      #
      # Do this test until we reach a maximum age
      #
      while true do

        %w(host1 host2 host3).each do |host|
           backups << Byteback::Snapshot.new("/tmp/#{host}", File.join("/tmp/#{host}/",(now+rand(3600)).iso8601 ))
        end

        while backups.length > limit do
          sorted_backups = Byteback::Snapshot.sort_by_importance(backups, now)
          backups.delete(sorted_backups.last)
        end

        offsets = backups.collect{|x| ((now - x.time)/86400.0).round }

        #
        # TODO test me!
        #
 
        if biggest_offset.nil? or offsets.max > biggest_offset
          biggest_offset = offsets.max
        else
          puts "Oldest backup with space for #{limit} backups and 3 hosts is #{offsets.max} days: #{offsets.join(", ")}" if $VERBOSE
          break
        end

        # Move on a day
        day += 1
        now += 86400
      end
    end
  end

  #
  # This test is the same as the previous two, except with random failures added in.
  #
  def test_sort_by_importance_with_random_failures

    start = Time.now
      
    15.times do 
      limit = 15
      backups = []
      offsets = []
      now   = Time.at(start.to_i) + rand(7)*86400
      day   = 0

      #
      # Run this test over 120 days
      #
      120.times do

        # Fail on 3 days out of four
        if rand(7) < 3 
          backups << Byteback::Snapshot.new("/tmp", File.join("/tmp/",now.iso8601))
        end

        while backups.length > limit do
          sorted_backups = Byteback::Snapshot.sort_by_importance(backups, now)
          backups.delete(sorted_backups.last)
        end

        offsets = backups.collect{|x| ((now - x.time)/86400.0).round }

        # TODO test! 

        # Move on a day
        day += 1
        now += 86400
      end
      puts "Oldest backup with space for #{limit} backups is #{offsets.max} days: #{offsets.join(", ")}" if $VERBOSE

    end
  end
end

