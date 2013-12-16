require 'spec_helper'

module Register
  describe 'register client' do
    UNIT_TESTS_DIR = "/tmp/register_manager_unit_tests_#{Process.pid}_#{Time.now.to_i}"
    before :each do
      FileUtils.mkdir(UNIT_TESTS_DIR)
      File.directory?(UNIT_TESTS_DIR).should be_true
      @bridge_client = make_bridge_agent
    end
 
    after :each do
      FileUtils.rm_rf(UNIT_TESTS_DIR)
      File.directory?(UNIT_TESTS_DIR).should be_false
    end

    it "should return the instance id" do
      @bridge_client.bridge_instance_id(rpc_instance).should == \
        "#{rpc_instance['app_id']}_#{rpc_instance['instance_index']}"
    end

    def make_bridge_agent(overide = {})
      config = {
        'logging' => { :file =>  File.join(UNIT_TESTS_DIR, 'register.log') },
        'rpc' => {
          'bridge' => 'http://127.0.0.1:8088',
	  'bridge_domain' => 'testjpaas.baidu.com',
	  'register_retry_delay' => 2,
	  'register_conn_timeout' => 3 ,      
	  'register_inactive_timeout' => 2, 
        'cluster' => 'app_cluster',
        }
      }
      config.update(overide)
      VCAP::Logging.setup_from_config(config['logging'])
      logger = VCAP::Logging.logger('broker')
      Register::BridgeClient.new(config, logger)
    end

    def rpc_instance
      {
        'app_uri' => "test.baidu.com", 
        'app_id' => "1", 
        'app_name' => "test", 
        'instance_index' => "0", 
        'instance_id' => "cfab68ad72a1621079ff39b3b17884ed", 
        'instance_ip' => "127.0.0.1", 
        'instance_http_port' => 10041, 
        'instance_meta' => {
           'prod_ports' => {
              'server'  => {
                 'host_port' => 10041,
                 'port_info' => {
                    'bns' => true
                  }
               }
            }
        }
      }
    end

    def rpc_ports
      {
        "port_1" => {
           "host_port" => 8088,
           "port_info" => {
              "bns" => true
           }
         },
        "port_2" => {
           "host_port" => 8088,
           "port_info" => {
              "bns" => false
           }
         }
      }
    end
    def rpc_port_in_str
      "{\"port_1\":8088}"
    end
  end
end
