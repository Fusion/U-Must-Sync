require 'rubygems'
require 'sqlite3'
require 'toodledo'
require 'yaml'
require 'date'

require 'toodledo_patch'

require 'synclog'
require 'synctdmodel'
require 'synclocalmodel'
require 'syncpriority'

# Let's add a method to time that will provide datetime conversion (Because sqlite3 Timestamp => Time object)
class Time
  def to_datetime
    DateTime.new(year, month, day, hour, min, sec + Rational(usec, 1000000), Rational(utc_offset, 86400))
  end
  
  def to_sqlite3
    Time.mktime(year - 31, month, day, hour, min, sec, usec).to_f
  end
end

class String
  def to_datetime
    DateTime.parse(self)
  end
end

class SContext
	attr_reader :id, :name
	def initialize(id, name)
		@id = id
		@name = name
	end
	
	def server_id
	  @id
  end
end

class SFolder
	attr_reader :id, :name, :is_private, :archived
	def initialize(id, name, is_private, archived)
		@id = id
		@name = name
		@is_private = is_private
		@archived = archived
	end

	def server_id
	  @id
  end
end

class STask
	attr_reader :id, :title, :star, :priority, :parent, :context, :tag, :note, :startdate, :completed, :timer, :added, :modified
	attr_accessor :folder
	def initialize(id, title, star, priority, parent, context, folder, tag, note, startdate, completed, timer, added, modified)
		@id = id
		@title = title
		@star = star
		@priority = priority
		@parent = parent
		@context = context
		@folder = folder
		@tag = tag
		@note = note
		@startdate = startdate
		@completed = completed
		@timer = timer
		@added = added
		@modified = modified
	end
	
	def server_id
	  @id
  end
end

class SData
  @@file_name = 'sync.data'

  def initialize
    if File.exists?(@@file_name)
      load
    else
      @data = {:lastauth => nil, :key => nil}
    end
  end
  
  def lastauth=(la)
    @data[:lastauth] = la
    store
  end
  
  def lastauth
    @data[:lastauth]
  end

  def key=(k)
    @data[:key] = k
    store
  end
  
  def key
    @data[:key]
  end  
  
  def load
    File.open(@@file_name) do |f|
      @data = Marshal.load(f)
    end
  end
  
  def store
    File.open(@@file_name, 'w') do |f|
      Marshal.dump(@data, f)
    end
  end
  
  private :load, :store
  
end