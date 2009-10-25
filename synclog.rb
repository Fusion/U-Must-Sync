class SLog
  
  def self.log(str)
    File.open('sync.log', 'a') do |f|
      f.write(str + "\n")
    end
    p str if @@config[:verbose]
  end

end