module Register
  class Protocol

    attr_reader :instance
    def initialize(instance)
      @instance = instance
    end

    class <<self
      def register_api
        "/addRMIports"
      end
      
      def register_method
        "post"
      end

      def unregister_method
        "delete"
      end

      def unregister_api
        "/delRMIports"
      end

      def create_api
        "/addServiceName"
      end
 
      def create_method
        "post"
      end
    end     

    #Generate register message for instance.
    def register_protocol
       return unless instance
       app_group, app_version = parse_app_version(instance['app_name'])
       prod_ports = parse_bns_ports(instance['instance_meta']['prod_ports'])
       instance_http_port = prod_ports.size < 1? instance[:instance_host_port]\
                                 : prod_ports.values_at(prod_ports.keys[0])[0]
       app_uri = instance['app_uri']? convert_array_to_str(instance['app_uri'])\
                                       : instance['instance_tags']['bns_node']
       instance_cluster = instance['cluster'] || DEFAULT_APP_CLUSTER
       message = {
          :app_uri => app_uri,
          :app_id => instance['app_id'],
          :app_name => instance['app_name'],
          :app_group => app_group,
          :app_version => app_version,
          :instance_user => instance[:instance_user] || DEFAULT_APP_USER,
          :instance_index => instance['instance_index'],
          :instance_id => instance['instance_id'],
          :instance_ip => instance['instance_ip'],
          :instance_http_port => instance_http_port,
          :instance_rmi_ports => convert_hash_to_str(prod_ports),
          :instance_path => instance['instance_path'] || DEFAULT_APP_PATH,
          :instance_cluster=> instance_cluster,
        }
       message
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

    #Parse the ports to be registered
    #@Param [Hash] ports: ports dispatched for the instance
    #@Return [Array] ports to register
    def parse_bns_ports(ports)
      return {} unless ports
      port_to_register = {}
      ports.each_pair do |port_name, port_des| 
         port_to_register["#{port_name}"] = port_des["host_port"] if port_des["port_info"]["bns"]
      end
      port_to_register
    end

    #Unregister instance protocol
    def unregister_protocol
      app_uri = instance['app_uri']? convert_array_to_str(instance['app_uri'])\
                                       : instance['instance_tags']['bns_node']   
      instance_cluster = instance['cluster'] || DEFAULT_APP_CLUSTER
      message = {
	:app_id => instance['app_id'],
        :app_uri => app_uri,
	:instance_index => instance['instance_index'],
        :instance_cluster=> instance_cluster,
      }
      message
    end

    #Convert hash to string, just to satisfy the bridge interface.
    def convert_hash_to_str(json)
       return '{}' unless json && json.class == Hash
       port_arr = []
       json.each_pair { |port_name, port|
	 port_arr << "\"#{port_name}\":#{port}"
       }
       port_str = port_arr.join(',')
       '{' + port_str +'}'
    end

    #Convert array to string, just to satisfy the bridge interface.
    def convert_array_to_str(arr)
       return '' unless arr && arr.class == Array
       arr.join(',')
    end   

    #Create bns protocal for instance
    def create_protocol
        app_uri = instance['app_uri']? convert_array_to_str(instance['app_uri'])\
                                       : instance['instance_tags']['bns_node']
        instance_cluster = instance['cluster'] || DEFAULT_APP_CLUSTER
        message = { 
           :app_uri => app_uri<<".jpaas."<<instance_cluster,
         }
        message
     end
  end
end
