# coding: UTF-8

module Register
  class BridgeClient
    DEFAULT_BRIDGE_RETRY_TIMES = 2
    DEFAULT_BRIDGE_RETRY_DELAY = 2
    DEFAULT_BRIDGE_PROCESS_DELAY = DEFAULT_BRIDGE_RETRY_TIMES * DEFAULT_BRIDGE_RETRY_DELAY * 2
    DEFAULT_BRIDGE_CONN_TIMEOUT = 3
    DEFAULT_BRIDGE_INACTIVE_TIMEOUT = 2
    SUPPORTED_BRIDGE_ACTION = ['register', 'unregister']

    attr_reader :logger, :waiting_bridge_queue

    def initialize(config, logger)
      @bridge = config['rpc']['bridge']
      @bridge_domain = config['rpc']['bridge_domain']
      @register_retry_delay          = config['rpc']['register_retry_delay'] || DEFAULT_BRIDGE_RETRY_DELAY
      @register_conn_timeout         = config['rpc']['register_conn_timeout'] || DEFAULT_BRIDGE_CONN_TIMEOUT
      @register_inactive_timeout     = config['rpc']['register_inactive_timeout'] || DEFAULT_BRIDGE_INACTIVE_TIMEOUT
      @logger = logger
      @waiting_bridge_queue = []
      
    end

    #Generate the uri to register instance.
    #@return [String]: uri to regisger instance.
    def register_instance_uri
      "#{@bridge}/addRMIports"
    end

    #Generate the uri to unregister instance.
    #return [String]: uri to unregister instance.
    def unregister_instance_uri
       "#{@bridge}/delRMIports"
    end
    
    #Parse the application name to application group and application version
    #@Param [String] app_name: application name;
    #@return [Array] app_group, app_version;
    def parse_app_version(app_name)
       
        app_info = /(^[a-z\d][a-z\d\-]*)_(([\d]\z)|([\d][a-z\d\-]*[a-z\d]\z))/i.match(app_name)

        if app_info
          app_group, app_version = app_info[1], app_info[2]
        else
          app_group, app_version = app_name, '0-0-0-0'
        end 
        [app_group, app_version]

    end

    def is_in_waiting_queue?(ins_id)
       return false unless ins_id
       @waiting_bridge_queue.include?(ins_id)
    end

    #Parse the ports to be registered
    #@Param [Hash] ports: ports dispatched for the instance
    #@Return [Array] ports to register
    def parse_bns_ports(ports)
      return [] unless ports
      port_to_register = {}
      ports.each_pair do |port_name, port_des| 
         port_to_register["#{port_name}"] = port_des["host_port"] if port_des["port_info"]["bns"] 
      end
      convert_hash_to_str(port_to_register)
    end

    
    #convert hash to string, just to satisfy the bridge interface.
    def convert_hash_to_str(json)
       return '' unless json && json.class == Hash
       port_arr = []
       json.each_pair { |port_name, port|
         port_arr << "\"#{port_name}\":#{port}"
       }
       port_str = port_arr.join(',')
       str = "{#{port_str}}"
       str
    end

    #Generate register message for instance.
    #@param [Hash] instance: instance need to register
    #@return [Hash] message: message body.
    def generate_register_message(instance)
       return unless instance
       app_group, app_version = parse_app_version(instance['app_name'])
       message = {
          #:app_uri => instance['app_uri'] || worker_app_uri(instance['app_name']),
          :app_uri => instance['instance_tags']['bns_node'] || worker_app_uri(instance['app_name']),
          :app_id => instance['app_id'],
          :app_name => instance['app_name'],
          :app_group => app_group,
          :app_version => app_version,
          :instance_user => 'clb-op',
          :instance_index => instance['instance_index'],
          :instance_id => instance['instance_id'],
          :instance_index => instance['instance_index'],
          :instance_ip => instance['instance_ip'],
          :instance_http_port => '8080',
          :instance_rmi_ports => parse_bns_ports(instance['instance_meta']['prod_ports']),
          :instance_path => 'n/a',          
        }
       message       
    end

    def worker_app_uri(app_name)
       "#{app_name}.#{@bridge_domain}"
    end

    #Generate register message for instance.
    #@param [Hash] instance: instance need to unregister.
    #@return [Hash] message: message body.
    def generate_unregister_message(instance)
       return unless instance
       message = {
          :app_id => instance['app_id'],
          :app_name => instance['app_name'],
          :instance_index => instance['instance_index']
       }
       message
    end

    def bridge_instance_id(instance)
      "#{instance['app_id']}_#{instance['instance_index']}"
    end

    def process_bridge_register(action, instance, &callback)
      p "instance is #{instance} action is #{action} "
      return unless instance 
      return unless SUPPORTED_BRIDGE_ACTION.include?(action)

      bid = bridge_instance_id(instance)
      
      logger.debug("[RPC] instance is #{instance}")
      p "DEFAULT_BRIDGE_PROCESS_DELAY is #{DEFAULT_BRIDGE_PROCESS_DELAY} @waiting_bridge_queue is #{@waiting_bridge_queue} id is #{bid}"
      if @waiting_bridge_queue.include?(bid)
         logger.debug("[RPC] instance [#{instance["instance_id"]}] is in queue, delay to process.")
         EM.add_timer(DEFAULT_BRIDGE_PROCESS_DELAY){
           process_bridge_register(action, instance)
         }
      else
         self.send("#{action}_instance", instance)
      end
    end

    #Register instance at bridge.
    #@param [Hash] instance: instance to register.
    #@param [Number] retries: retry times.
    #@param [Block] &callback: register callback function.
    def register_instance(instance, retries = 0, &callback)
      return unless instance
      bid = bridge_instance_id(instance)
      @waiting_bridge_queue << bid unless is_in_waiting_queue?(bid)
      reg_message = generate_register_message(instance)

      logger.debug("[RPC] Sending the #{retries} time register request #{reg_message}")

      head = { 'content-type' => 'application/json' }
      conn_options = {
        :connect_timeout => @register_conn_timeout,
        :inactivity_timeout => @register_inactive_timeout
      }
      http = EventMachine::HttpRequest.new(register_instance_uri, conn_options).post :head => head, :body=>reg_message

      http.callback {
        begin
          logger.debug("[RPC] Received bridge response #{http.response}")

          resp = Yajl::Parser.parse(http.response)

          if resp && resp["success"] == true
             logger.info("[RPC] Register instance with bridge succ, request data is #{reg_message}")
             @waiting_bridge_queue.delete(bid)
             callback.call('succ') if callback
          elsif retries < DEFAULT_BRIDGE_RETRY_TIMES
	     EM.add_timer(@register_retry_delay) { 
                register_instance(instance, retries += 1, &callback) 
             }
	  else
             logger.warn("[RPC] Sending register request succeed, while response error #{resp}, request data is #{reg_message}!")
             @waiting_bridge_queue.delete(bid)
             callback.call('failed') if callback
          end
        rescue => e
          logger.warn("[RPC] Register instance with exception #{e}, request data is #{reg_message}")
          callback.call('failed') if callback
        end
      }

      http.errback {
        if retries < DEFAULT_BRIDGE_RETRY_TIMES
           EM.add_timer(@register_retry_delay) {
             register_instance(instance, retries += 1, &callback)
           }
        else
           logger.warn("[RPC] Register instance with bridge failed with error #{http.error}, request data is #{reg_message}")
           @waiting_bridge_queue.delete(bid)
           callback.call('failed') if callback
        end
      }

    end
    
    #Unregister instance from bridge.
    #@param [Hash] instance: instance to unregister;
    #@param [Number] retries: retris times.
    #@param [Block] &callback: unregister callback function.
    def unregister_instance(instance, retries = 0, &callback)
      return unless instance
      bid = bridge_instance_id(instance)
      @waiting_bridge_queue << bid unless is_in_waiting_queue?(bid)
      unreg_message = generate_unregister_message(instance)
      logger.debug("[RPC] Sending the #{retries} time unregister request #{unreg_message}")

      head = { 'content-type' => 'application/json' }
      conn_options = {
        :connect_timeout => @register_conn_timeout,
        :inactivity_timeout => @register_inactive_timeout
      }
      http = EventMachine::HttpRequest.new(unregister_instance_uri, conn_options).delete :head => head, :body=>unreg_message
   
      http.callback {
        logger.debug("[RPC] Received bridge response #{http.response}")
        begin
          resp = Yajl::Parser.parse(http.response)
        
          if resp && resp["success"] == true
             logger.info("[RPC] Unregister instance with bridge succeeded, request data is #{unreg_message}!")
             @waiting_bridge_queue.delete(bid)
             callback.call('succ') if callback
	  elsif retries < DEFAULT_BRIDGE_RETRY_TIMES
             EM.add_timer(@register_retry_delay){
	       unregister_instance(instance, retries += 1, &callback)
             }
          else
             logger.warn("[RPC] Sending unregister request succeeded, while response error with #{resp}, request data is #{unreg_message}!")
             @waiting_bridge_queue.delete(bid)
	     callback.call('failed') if callback
          end
        rescue => e
          logger.warn("[RPC] Unregister instance with bridge with exception #{e}, request data is #{unreg_message}")
          callback.call('failed') if callback        
        end
      }

      http.errback {
        if retries < DEFAULT_BRIDGE_RETRY_TIMES
           EM.add_timer(@register_retry_delay){
             unregister_instance(instance, retries += 1, &callback)
           }
        else
           logger.warn("[RPC] Unregister instance with bridge failed, request data is #{unreg_message}.")
           @waiting_bridge_queue.delete(bid)
           callback.call('failed') if callback
        end
      }

    end
    
    #Convert array to string, just to satisfy the bridge interface.
    def convert_array_to_str(arr)
       return '' unless arr && arr.class == Array
       str = arr.join(',')
       str
    end
  end
end
