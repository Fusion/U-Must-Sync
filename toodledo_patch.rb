module Toodledo

#
# Monkey-patching the Toodledo API
#

  class Session
    attr_reader :key
    # Reconnect with previous key so that we do not run afoul of rate limiter
    def reconnect(key, base_url = DEFAULT_API_URL, proxy = nil)
      logger.debug("reconnect(#{base_url}, #{proxy.inspect})") if logger
      @base_url = base_url
      @proxy = proxy
      @key = key
      @start_time = Time.now
    end    
  end
  
  def self.resume(key, logger = nil)
    config = Toodledo.get_config()

    proxy = config['proxy']

    connection = config['connection']
    base_url = connection['url']
    user_id = connection['user_id']
    password = connection['password']

    session = Session.new(user_id, password, logger)

    base_url = Session::DEFAULT_API_URL if (base_url == nil)
    session.reconnect(key, base_url, proxy)

    if (block_given?)
      yield(session)
    end

    session.disconnect()
  end
    
end
