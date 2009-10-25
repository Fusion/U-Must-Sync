class LocalModel
  
  attr_reader :now
	
  def initialize
    # Retrieve uid map
		@sdb = SQLite3::Database.new("sync.sqlite3")
		@sdb.results_as_hash  = true
		@sdb.type_translation = true
		@uidmapt2l = Hash.new
		@uidmapl2t = Hash.new
		# Retrieve all uid mappings
		@sdb.execute("select * from uidmap") do |row|
		  @uidmapl2t[row['localuid'].to_s] = row['tduid'].to_s
		  @uidmapt2l[row['tduid'].to_s] = row['localuid'].to_s
		end
		# Retrieve last sync timestamp
		@sdb.execute("select datetime(lastsync, 'unixepoch', '+31 years') AS ls from info") do |row|
		  @lastsync = row['ls'].to_datetime
	  end
	  
	  # And write new timestamp
	  @now = Time.new.to_sqlite3
	  # For testing, a solid old value for lastsync: 260852376.079337
    @sdb.execute("update info set lastsync=?", @now)
    
    # Now the local tasks database
		@db = SQLite3::Database.new("library.sqlite3")
		@db.results_as_hash  = true
		@db.type_translation = true
	  # Retrieve highest group primary key
		@db.execute("select MAX(Z_PK) as m from ZGROUP") do |row|
		  @topgroupid = Integer(row['m'])
	  end
	  # And highest task primary key
		@db.execute("select MAX(Z_PK) as m from ZTASK") do |row|
		  @toptaskid = Integer(row['m'])
	  end
  end
  
  def find(id)
    id = id.to_s
    return @tasks_list[@uidmapt2l[id]] if @uidmapt2l[id]
    false
  end
  
  def older?(dt)
    @lastsync <= dt
  end
  
  def uid
    # WHOA THERE! This is terrible. Note: < 9223372036854775807
     rand(9000000000000000000)
  end
  
  def housekeeping
    @db.execute("update Z_PRIMARYKEY set Z_MAX=? WHERE Z_NAME='Group'", @topgroupid)
    @db.execute("update Z_PRIMARYKEY set Z_MAX=? WHERE Z_NAME='Task'", @toptaskid)
  end
  
  def folders!
    @folders_list = Hash.new
    @db.execute("select * from ZGROUP where ZTYPE='list'") do |row|
      @folders_list[row['ZTITLE']] = SFolder.new(
        row['Z_PK'],
        row['ZTITLE'],
        "0",
        "0"        
      )
    end
    
    @folders_list
  end
  
  def createfolder(name, ts = @now)
    # @todo Should I also:  update Z_PRIMARYKEY set Z_MAC=17 where Z_ENT=1;
    @topgroupid += 1
    @db.execute("insert into ZGROUP(ZPARENTGROUP, Z1_PARENTGROUP, Z_OPT, ZUIDNUM, Z_ENT, ZSPECIAL, Z_PK, ZDISPLAYORDER, ZMODIFIEDDATE, ZCREATEDDATE, ZTITLE, ZTYPE) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
      3,  # Projects
      2,  # Not sure what this means
      3,  # Again...not sure
      uid,
      3,  # Z_ENT: 2 = folder, 3 = list
      0,
      @topgroupid,
      0.0,
      ts,
      ts,
      name,
      'list'
      )
  end
  
  def contexts!
    @contexts_list = Hash.new
    @db.execute("select * from ZGROUP where ZTYPE='tag' and ZTITLE like '@%'") do |row|
      @contexts_list[row['ZTITLE']] = SContext.new(
        row['Z_PK'],
        row['ZTITLE']
      )
    end
    
    @contexts_list
  end
  
  def createcontext(name, ts = @now)
    @topgroupid += 1
    @db.execute("insert into ZGROUP(ZPARENTGROUP, Z1_PARENTGROUP, Z_OPT, ZUIDNUM, Z_ENT, ZSPECIAL, Z_PK, ZDISPLAYORDER, ZMODIFIEDDATE, ZCREATEDDATE, ZTITLE, ZTYPE) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
      6,
      2, # Not sure what this means
      3, # Again...not sure
      uid,
      5,
      0,
      @topgroupid,
      2000.0,
      ts,
      ts,
      name,
      'tag'
      )    
  end
  
  def tasks
    still_alive = {}
    @tasks_list = Hash.new
		@db.execute("select datetime(ZMODIFIEDDATE, 'unixepoch', '+31 years') as zmd, datetime(ZSTARTDATE, 'unixepoch', '+31 years') as zst, datetime(ZCOMPLETEDDATE, 'unixepoch', '+31 years') as zcd, * from ZTASK") do |row|
		  
		  still_alive[row['Z_PK'].to_s] = true if row['Z_PK']
		  
      @tasks_list[row['Z_PK'].to_s] = STask.new(
        @uidmapl2t[row['Z_PK']] ? @uidmapl2t[row['Z_PK']] : nil,
        row['ZTITLE'],
        false,
        row['ZPRIORITY'],
        @uidmapl2t[row['ZPARENTLIST']] ? @uidmapl2t[row['ZPARENTLIST']] : nil,
        nil, # @todo context
        nil, # @todo folder
        nil, # tag
        row['ZNOTES'],
        row['ZSTARTDATE'] ? row['zst'].to_datetime : nil,
        row['ZCOMPLETEDDATE'] ? row['zcd'].to_datetime : nil,
        row['ZACTUALTIME'] ? row['ZACTUALTIME'] : nil,
        nil,
        row['zmd'].to_datetime
      )
  	end
		# Sanity check: delete from uidmap if local task doesn't exist any more
		# because it was deleted in THL
		to_prune = []
		@uidmapl2t.each do |lid, tid|
		  next if still_alive[lid.to_s]
		  # The local task doesn't exist anymore!
		  @uidmapt2l.delete(tid.to_s)
		  @uidmapl2t.delete(lid.to_s)
		  to_prune << tid.to_s
	  end
		@sdb.execute("delete from uidmap where tduid in (?)", to_prune.join(",")) if !to_prune.empty?
	  
		@tasks_list    
  end
  
  #
  # DID YA KNOW?
  # If it's a top-level task, THL stores its folder's Z_PK in zparentlist -- nil otherwise
  # If it's a sub-task, THL stores its parent task's Z_PK in zparenttask -- nil otherwise
  def createtask(task)
    @toptaskid += 1
    full_title = task.title
    folder = @folders_list[task.folder.name]
    abort "Unknown local folder #{task.folder.name}" if !folder
    context = @contexts_list[task.context.name]
    context = @contexts_list['@' + task.context.name] if !context
    abort "Unknown local context #{task.context.name}" if !context
    full_title += ' ' + context.name    

    # V1.0: Assume -- wrongly -- that all tasks are top-level tasks! Therefore, zparenttask == nil every time
    
    @db.execute("insert into ZTASK(ZPARENTTASK, Z_PK, Z_OPT, ZPRIORITY, ZRECURRING, ZUIDNUM, ZPARENTLIST, Z_ENT, ZCOMPLETEDDATE, ZDISPLAYORDER, ZARCHIVEDDATE, ZMODIFIEDDATE, ZCREATEDDATE, ZESTIMATEDTIME, ZACTUALTIME, ZDUEDATE, ZCANCELEDDATE, ZSTARTDATE, ZTITLE, ZNOTES, ZCALENDARSTOREUID, ZATTRIBUTEDNOTES, ZRECURRENCERULE) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
      nil,            # ZPARENTTASK (task, not folder)
      @toptaskid,     # Z_PK
      0,              # Z_OPT
      task.priority,  # ZPRIORITY
      0,              # ZRECURRING
      uid,            # ZUIDNUM
      folder.id,      # ZPARENTLIST (folder, not task)
      7,              # Z_ENT -- Why 7?
      nil,            # ZCOMPLETEDDATE
      1000.0,         # ZDISPLAYORDER,
      nil,            # ZARCHIVEDDATE
      @now,           # ZMODIFIEDDATE
      @now,           # ZCREATEDDATE
      0.0,            # ZESTIMATEDTIME
      0.0,            # ZACTUALTIME
      nil,            # ZDUEDATE
      nil,            # ZCANCELDDATE
      nil,            # ZSTARTDATE
      full_title,     # ZTITLE
      task.note,      # ZNOTE
      nil,            # ZCALENDARSTOREUID
      nil,            # ZATTRIBUTESNOTES
      nil)
    
    # This is where tags and contexts are indexed  
    @db.execute("insert into Z_5TASKS(Z_5TAGS, Z_7TASKS1) VALUES(?, ?)", context.id, @toptaskid)
    
    @sdb.execute("insert into uidmap(tduid, localuid) values(?, ?)", task.id, @toptaskid)
  end  
end