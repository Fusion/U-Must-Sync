#!/usr/bin/env ruby
#
require 'syncmain'

module InitMockEnvironment
  def init
    @tdmodel = TDMock.new
    @localmodel = LocalModel.new
    @tdmain = TDMain.new(@tdmodel, @localmodel)
  end
end

describe "A mock Toodledo model" do
  before(:all) do
    @tdmodel = TDMock.new
  end
  
  it "should have exactly two folders" do
    @tdmodel.folders.should have_exactly(2).items
  end
  
  it "should have exactly two contexts" do
    @tdmodel.contexts.should have_exactly(2).items
  end

  it "should have exactly two tasks" do
    @tdmodel.tasks.should have_exactly(2).items
  end

  it "should have exactly three folders after adding a new one" do
    @tdmodel.createfolder("Another Folder")
    @tdmodel.folders.should have_exactly(3).items
  end
  
  it "should have exactly three contexts after adding a new one" do
    @tdmodel.createcontext("@awesomecontext")
    @tdmodel.contexts.should have_exactly(3).items
  end

  it "should have exactly two folders after deleting one" do
    @tdmodel.deletefolder("Folder Two")
    @tdmodel.folders.should have_exactly(2).items
  end
  
  it "should have exactly two contexts after deleting one" do
    @tdmodel.deletecontext("@office")
    @tdmodel.contexts.should have_exactly(2).items
  end
  
  after(:all) do
    @tdmodel = nil
  end
end
