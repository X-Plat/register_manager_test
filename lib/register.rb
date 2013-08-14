# coding: UTF-8
require "nats/client"
require "bridge_client"
require "em-http"
require 'vcap/logging'

module Register
  class Broker
    attr_reader :logger, :bridge_client
    def initialize(config)
      @config = config.dup
      VCAP::Logging.setup_from_config(@config['logging'])
      @logger = VCAP::Logging.logger('broker') 
      @nats_uri = @config['mbus']
    end

    def setup
      setup_nats
      setup_bridge_client(@config, logger)
    end

    def setup_nats
      NATS.on_error do |e|
        logger.error("EXITING! NATS error: #{e}")
        logger.error(e)
	exit!
      end

     EM.error_handler do |e|
	logger.error "Eventmachine problem, #{e}"
        logger.error(e)
     end 
 
      NATS.start(:uri => @nats_uri) do
	NATS.subscribe('broker.register', :queue => :bk) { |msg| 
          p "received register message"
          instance = Yajl::Parser.parse(msg)
          
          bridge_client.process_bridge_register('register', instance)
        }
        NATS.subscribe('broker.unregister',:queue => :bk) { |msg| 
          instance = Yajl::Parser.parse(msg)
          bridge_client.process_bridge_register('unregister', instance)
        }
        #NATS.subscribe('broker.unregister') { |msg|  process_broker_unregister(msg) }      
      end
    end

    def setup_bridge_client(config, logger)
      @bridge_client = Register::BridgeClient.new(config, logger)
    end 

    
    def process_broker_register(msg)
      instance = Yajl::Parser.parse(msg)
      logger.info("received register msg #{instance}")
      bridge_client.register_instance(instance)
    end

    def process_broker_unregister(msg)
      instance = Yajl::Parser.parse(msg)
      logger.info("received unregister msg #{instance}")
      bridge_client.unregister_instance(instance)
    end

    def start
      logger.info("Register manager started.")
    end
  end
end

