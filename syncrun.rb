#!/usr/bin/env ruby
#
require 'syncconfig'
require 'syncmain'

TDOnline.new(SData.new) { |tdmodel| TDMain.new(tdmodel, LocalModel.new).run } if @@config[:mode] == "online"
TDMock.new { |tdmodel| TDMain.new(tdmodel, LocalModel.new).run } if @@config[:mode] == "mock"
