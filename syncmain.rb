require 'synclib'

#
# These are the cases we are trying to address:
#
# CS#1. New task created locally >> must create remotely *
# CS#2. New task created remotely >> must create locally *
# CS#3. Local task modified
# CS#3.1. Local task modified, no action remotely >> must modify remotely
# CS#3.2. Local task modified, deleted remotely >> must notify, re-create remotely *
# CS#3.3. Local task modified, modified remotely >> must notify, TBD
# CS#4. Remote task modified *
# CS#4.1. Remote task modified, no action locally >> must tmodify locally * 
# CS#4.2. Remote task modified, deleted locally >> must notify, re-create locally *
# CS#4.3. Remote task modified,  modified locally >> must notify, TBD *
# CS#5. Local task deleted, no action remotely >> must delete remotely *
# CS#6. Remote task deleted, no action locally >> must delete locally *
#
# NOTE: folders and tags are to be indexed by name, not by uid

# DB SCHEMA: Timestamps confuse me.
# Here is how to get a human-readable representaion of a timestamp:
# select datetime(ZMODIFIEDDATE,'unixepoch','+31 years') from ZGROUP;

# Folders are actually stored in THL as lists!

class TDMain
  
  def initialize(tdmodel, localmodel)
    @tdmodel = tdmodel
    @localmodel = localmodel
  end
  
  def alert(str)
    p "#####################################################################################"
    p str
    p "#####################################################################################"
  end
  
	def run
	  
	  ##
	  
	  SLog::log "\n## New Sync Session: #{DateTime.now.to_s}"
	  
	  # RETRIEVE FOLDERS #
	  
		# Retrieve folders from Toodledo
		folders_info = @tdmodel.folders
		td_folders = Hash.new
		folders_info.each do |folder_info|      
	    td_folders[folder_info.name] = SFolder.new(
	    folder_info.server_id,
	    folder_info.name,
	    folder_info.is_private,
	    folder_info.archived)
	  end
	  
		# Retrieve local folders
		local_folders = @localmodel.folders!
	  
	  # RETRIEVE CONTEXTS #
	  
		# Retrieve contexts from Toodledo
		contexts_info = @tdmodel.contexts
		td_contexts = Hash.new
		contexts_info.each do |context_info|
	    # Oh how careless
	    real_name = context_info.name
	    if(64 != real_name[0])
	      real_name = '@' + real_name
      end
	    td_contexts[real_name] = SContext.new(
	    context_info.server_id,
      real_name
	    )
	  end
	  
		# Retrieve local contexts
		local_contexts = @localmodel.contexts!
	  
	  # RETRIEVE TASKS #
	  
		# Retrieve tasks from Toodledo
		tasks_info = @tdmodel.tasks
		td_tasks = {}
		tasks_info.each do |task_info|
			td_tasks[task_info.server_id] = STask.new(
				task_info.server_id,
				task_info.title,
				task_info.star,
				task_info.priority,
				task_info.parent,
				task_info.context,
				task_info.folder,
				task_info.tag,
				task_info.note,
				task_info.startdate,
				task_info.completed,
				task_info.timer,
				task_info.added,
				task_info.modified)
		end
		
		# Retrieve local tasks
		local_tasks = @localmodel.tasks

    ##
    # We have everybody. Let's get cranking!
    ##

    # FOLDERS #
    # We currently do not have a way to check for remote folder modification date...arg!
    
    # Iterate through remote folders list
    td_folders.each do |name, remotefolder|
      next if local_folders[name]
      SLog::log "F >> L:+ #{remotefolder.id}:#{name}"
      @localmodel.createfolder(name)
    end
    @localmodel.housekeeping

    # Iterate through local folders list
    local_folders.each do |name, localfolder|
      next if td_folders[name]
      SLog::log "F >> R:+ #{localfolder.id}:#{name}"
      @tdmodel.createfolder(name)
    end
    
    # CONTEXTS #
    
    # Iterate through remote contexts list
    td_contexts.each do |name, remotecontext|
      next if local_contexts[name]
      SLog::log "C >> L:+ #{remotecontext.id}:#{name}"
      @localmodel.createcontext(name)
    end
    @localmodel.housekeeping

    # Iterate through local contexts list
    local_contexts.each do |name, localcontext|
      next if td_contexts[name]
      SLog::log "C >> R:+ #{localcontext.id}:#{name}"
      @tdmodel.createcontext(name)
    end

    # Before we get on with the heavy lifting, retrieve what folders and contexts info now we have in our database
		local_folders = @localmodel.folders!
		local_contexts = @localmodel.contexts!  
    
    # TASKS #
    
    # 1. Iterate through remote tasks.
    td_tasks.each do |id, remotetask|
      localtask = @localmodel.find(id)
      if localtask ### BOTH LOCAL AND REMOTE TASK EXIST
        if @localmodel.older?(remotetask.modified) ### REMOTE TASK WAS MODIFIED
          if @localmodel.older?(localtask.modified) ### REMOTE TASK WAS MODIFIED, LOCAL TASK WAS MODIFIED: CS#3.3 == CS#4.3
            # CS#4.3
            SLog::log "T R:~,L:~ >> L:! #{id}:#{remotetask.title}"
            alert "Task ['#{remotetask.title}'] was modified both locally and remotely. Please modify it again on either side then try syncing again."
          else
            # CS#4.1
            SLog::log "T R:~,L:= >> L:~ #{id}:#{remotetask.title}"
          end
        else ### REMOTE TASK UNCHANGED...WILL CHECK LOCAL TASK BELOW
        end
      else ### ONLY REMOTE TASK EXISTS
        if @localmodel.older?(remotetask.modified) ### REMOTE TASK WAS CREATED/MODIFIED, NO LOCAL TASK: CS#2, CS#4.2
          SLog::log "T R:+,L:= >> L:+ #{id}:#{remotetask.title}"
          @localmodel.createtask(remotetask)
        else ### REMOTE TASK UNCHANGED, NO LOCAL TASK: CS#5
          SLog::log "T R:=,L:- >> L:- #{id}:#{remotetask.title}"
        end
      end
    end    
    # 2. Iterate though local tasks
    local_tasks.each do |id, localtask|
      if localtask.id ### THIS TASK IS LOCAL AND EXISTS/USED TO EXIST REMOTELY
        if td_tasks[localtask.id] ### THIS TASK EXISTS LOCALLY AND REMOTELY
          if @localmodel.older?(localtask.modified)
            # Modified locally
            # CS#3.1
          end
        else
          # Doesn't exist remotely anymore
          if @localmodel.older?(localtask.modified)
            # Conclusion: Deleted remotely.
            # CS#6
            SLog::log "T R:- >> L:- #{id}:#{remotetask.title}" # WAIT ISN'T IT THE OTHER WAY AROUND HERE?
          else
            # This task died remotely and was modified locally: CONFLICT
            # CS#3.2
            SLog::log "T R:-,L:~ >> L:!,R:+ #{id}:#{remotetask.title}" 
          end
        end
      else
        if @localmodel.older?(localtask.modified)
          # This task was created locally after our previous sync
          # CS#1
          
        end
      end
    end
    @localmodel.housekeeping
    
    SLog::log "##"
	end
end