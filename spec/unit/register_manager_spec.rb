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

    it "should return the standard register uri" do
      @bridge_client.register_instance_uri.should == "#{@bridge_client.instance_variable_get(:@bridge)}/addRMIports"
    end

    it "should get teh application name and 0-0-0-0 if not standard name" do
      app_name = "appwithoutversion"
      @bridge_client.parse_app_version(app_name).should == ["appwithoutversion", "0-0-0-0"]
    end

    it "should get teh application name and version if standard name" do
      app_name = "app_1-0-0-0"
      @bridge_client.parse_app_version(app_name).should == ["app", "1-0-0-0"]
    end    
    
    it "should parse the application group and version" do
      @bridge_client.unregister_instance_uri.should == "#{@bridge_client.instance_variable_get(:@bridge)}/delRMIports"
    end

    it "should convert the rpc ports group to string" do
      @bridge_client.parse_bns_ports(rpc_ports).should == rpc_port_in_str
    end

    
    def make_bridge_agent(overide = {})
      config = {
        'logging' => { :file =>  File.join(UNIT_TESTS_DIR, 'register.log') },
        'rpc' => {
          'bridge' => 'http://127.0.0.1:8088',
	  'bridge_domain' => 'testjpaas.baidu.com',
	  'register_retry_delay' => 2,
	  'register_conn_timeout' => 3 ,      
	  'register_inactive_timeout' => 2 
        }
      }
      config.update(overide)
      VCAP::Logging.setup_from_config(config['logging'])
      logger = VCAP::Logging.logger('broker')
      Register::BridgeClient.new(config, logger)
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
