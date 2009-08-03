#!/usr/bin/env ruby
require 'rubygems'
require 'bloomfilter'
  
# m = 100000, k = 4, seed = 1
bf = BloomFilter.new(1000000, 4, 1)
 
File.open('genes_on_chromosome_one.txt').each { |line| bf.insert(line.strip) }
File.open('snps.txt').each do |line|
	if bf.include?(line.split('\t').last.strip)
	snps_on_chromosome_one << line
end

File.open('snps_on_chromosome_one.txt', 'w') { |file| file.write(snps_on_chromosome_one.join) }

bf.stats
