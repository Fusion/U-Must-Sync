class PriorityConverter
  def self.t2l(p)
    p < 0 ? 0 : p
  end
  
  def self.l2t(p)
    p > 3 ? 3 : p
  end
end