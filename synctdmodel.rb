class TDModel

  def server_info
    @server_info = @session.get_server_info
    @time_offset = @server_info[:unixtime] - Time.now.to_i
  end

  def offset
    @time_offset
  end
  
  def folders
    @session.get_folders
  end
  
  # Currently no support for private folders
  def createfolder(name)
    @session.add_folder(name, 0)
  end
  
  def deletefolder(name)
  end
  
  def contexts
    @session.get_contexts
  end

  def createcontext(name)
    @session.add_context(name)
  end
  
  def deletecontext(name)
  end
  
	def tasks
		@session.get_tasks
	end
	
	def createtask(task)
	  name = task.title
	  params = {
	    :folder => task.folder ? task.folder.name : nil,
	    :context => task.context ? task.context.name : nil,
	    :priority => PriorityConverter::l2t(task.priority)
	  }
	  @session.add_task(name, params)
  end

  def deletetask(name)
  end
  
end

#
# Toodledo's rate limiting:
# <= 120 requests in 60 minutes
# auth token is valid for up to 4 hours
#
class TDOnline < TDModel
	def initialize(sdata)
	  @sdata = sdata
	  tdconfig = { "connection" => @@config[:connection] }
		Toodledo.set_config(tdconfig)
		# To be on the safe side, let's decide that we shall ask for a new token every THREE hours
		if (sdata.key && sdata.lastauth && (elapsed_seconds = (Time.now - sdata.lastauth).to_i) < 10800)
      SLog::log "Re-using current auth token; time left until new token request: #{10800 - elapsed_seconds} seconds"
  		Toodledo.resume(sdata.key) do |@session|
  		  server_info
  			yield self if block_given?
  		end
    else
      SLog::log "Requesting new auth token, valid for three hours"
      sdata.lastauth = Time.now
  		Toodledo.begin do |@session|
  		  sdata.key = @session.key
  		  server_info  		  
  			yield self if block_given?
  		end
	  end
	end
end

# @deprecated by the use of SData which allows me to automate begin v.s. resume states
class TDResume < TDModel
	def initialize
		Toodledo.set_config(@@config)
		Toodledo.resume("c79e6cb24a866c1fb24ba767665a377e") do |@session|
			yield self if block_given?
		end
	end
end

class TDMock < TDModel
	def initialize
	  
    @folders_list =
      [
        SFolder.new(
          "2159838100",
          "Folder Two",
          "0",
          "0"),
        SFolder.new(
          "2159838620",
          "Folder One",
          "0",
          "0")
      ]

    @contexts_list =
      [
        SContext.new(
          "2159782720",
          "home"),
        SContext.new(
          "2159782340",
          "@office"),
      ]

	  @tasks_list =
  		[
  			STask.new(
  				"40721465",
  				"Add some items to your todo list",
  				false,
  				"1",
  				nil,
  				SContext.new("546307", "home"),
  				SFolder.new("2901605", "Folder One", "0", "0"),
  				nil,
  				nil,
  				nil,
  				nil,
  				nil,
  				nil,
  				DateTime.new(y=2009, m=10, d=19, h=18, min=1, s=1)),
  			STask.new(
  				"40721467",
  				"Visit your Account Settings section and configure your account.",
  				false,
  				"2",
  				nil,
  				SContext.new("546309", "@office"),
  				SFolder.new("2901609", "Folder Two", "0", "0"),
  				nil,
  				nil,
  				nil,
  				nil,
  				nil,
  				nil,
  				DateTime.new(y=2009, m=10, d=19, h=18, min=1, s=5))
  		]

		yield self if block_given?
	end

  def uid
     rand(9999999)
  end
  private :uid
  
  def folders
    @folders_list
  end

  def createfolder(name)
    @folders_list <<
      SFolder.new(
        uid,
        name,
        "0",
        "0"
      )
  end
  
  def deletefolder(name)
    @folders_list.delete_if { |folder| name == folder.name }
  end
  
  def contexts
    @contexts_list
  end

  def createcontext(name)
    @contexts_list <<
      SContext.new(
        uid,
        name
      )
  end
  
  def deletecontext(name)
    @contexts_list.delete_if { |context| name == context.name }
  end
  
	def tasks
	  @tasks_list
	end
	
	def createtask(task)
	  p "Creating task:"
	  p task
  end	
end