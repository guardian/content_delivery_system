#!/usr/bin/env ruby

$: << "./lib"
require 'CDS/HLSUtils'

it = HLSIterator.new(ARGV[0],File.dirname(ARGV[0]))

it.each do |filename,uri|
    puts "Got #{filename} destined for #{uri}"
    unless(File.exists?(filename))
        raise IOError,"Expected file #{filename} does not exist!"
    end
end

if(ARGV[1])
    puts "Attempting to rebase to #{ARGV[1]}..."
    it.rebase("HLS/",ARGV[1])

    it.each do |filename,uri|
        puts "Got #{filename} destined for #{uri}"
        unless(File.exists?(filename))
            raise IOError,"Expected file #{filename} does not exist!"
        end
    end
end
