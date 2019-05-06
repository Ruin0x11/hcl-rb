ENV["TEST"] = 'true'
$VERBOSE=nil
require 'rubygems'
require 'minitest/autorun'
$:.unshift File.expand_path("../../lib")
require "minitest/reporters"
require "hcl"

Minitest::Reporters.use!
