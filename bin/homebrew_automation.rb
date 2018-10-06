#!/usr/bin/env ruby

require 'thor'

require_relative '../lib/homebrew_automation.rb'

class MyCliApp < Thor

  desc 'put-sdist', 'update the URL and sha256 checksum of the source tarball'
  option :url, :required => true
  option :sha256, :required => true
  def put_sdist
    before = HomebrewAutomation::Formula.parse_string($stdin.read)
    after = before.put_sdist options[:url], options[:sha256]
    $stdout.write after
  end

  desc 'put-bottle', 'insert or update a bottle reference for a given OS'
  option :os, :required => true
  option :sha256, :required => true
  def put_bottle
    before = HomebrewAutomation::Formula.parse_string($stdin.read)
    after = before.put_bottle(options[:os], options[:sha256])
    $stdout.write after
  end

end

MyCliApp.start(ARGV)


