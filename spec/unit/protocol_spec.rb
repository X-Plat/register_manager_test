require 'spec_helper'

module Register
  describe 'protocol' do
    UNIT_TESTS_DIR = "/tmp/register_manager_unit_tests_#{Process.pid}_#{Time.now.to_i}"
    before :each do
      FileUtils.mkdir(UNIT_TESTS_DIR)
      File.directory?(UNIT_TESTS_DIR).should be_true
      @protocol = Protocol.new(rpc_instance)
    end
 
    after :each do
      FileUtils.rm_rf(UNIT_TESTS_DIR)
      File.directory?(UNIT_TESTS_DIR).should be_false
    end

    it "should return the standard register uri" do
      Protocol.register_api.should == "/addRMIports"
    end

    it "should return the standard unregister uri" do
      Protocol.unregister_api.should == "/delRMIports"
    end

    it "should return the standard register method" do
      Protocol.register_method.should == "post"
    end

    it "should return the standard register uri" do
      Protocol.unregister_method.should == "delete"
    end

    it "should return the standard register protocol" do
      @protocol.register_protocol.should == {
        :app_uri => "test.baidu.com",
        :app_id => "1",
        :app_name => "test",
        :app_group => "test",
        :app_version => "0-0-0-0",
        :instance_user => "app@baidu.com",
        :instance_index => "0",
        :instance_id => "cfab68ad72a1621079ff39b3b17884ed",
        :instance_ip => "127.0.0.1",
        :instance_http_port => 10041,
        :instance_rmi_ports => "{\"server\":10041}",
        :instance_path=>"N/A",
        :instance_cluster=>"app_cluster",
      }
    end

    it "should return the default name and version if without version" do
      app_name = "appwithoutversion"
      @protocol.parse_app_version(app_name).should == ['appwithoutversion', '0-0-0-0']
    end

    it "should return the name and version if with version" do
      app_name = "app_1-0-0-2"
      @protocol.parse_app_version(app_name).should == ['app', '1-0-0-2']
    end

    it "should parse the bns pors" do
      ports = rpc_ports
      @protocol.parse_bns_ports(ports).should == rpc_port_in_str
    end

    it "should return the standard unregister protocol" do
       @protocol.unregister_protocol.should == {
         :app_id => "1",
         :app_uri => "test.baidu.com",
         :instance_index => "0",
         :instance_cluster=>"app_cluster",
       }
    end

    it "should convert hash to string" do
      hash = {
        'a' => 1,
        'b' => 2
      }
      @protocol.convert_hash_to_str(hash).should == "{\"a\":1,\"b\":2}"
      fake_hash = "fake"
      @protocol.convert_hash_to_str(fake_hash).should == '{}'
    end

    it "should convert array to string" do
      array = ['a', 'b']
      @protocol.convert_array_to_str(array).should == "a,b"
      fake_array = 'abc'
      @protocol.convert_array_to_str(fake_array).should == ''
    end

    def rpc_instance
      {
        'app_uri' => [ "test.baidu.com" ] , 
        'app_id' => "1", 
        'app_name' => "test", 
        'instance_index' => "0", 
        'instance_id' => "cfab68ad72a1621079ff39b3b17884ed", 
        'instance_ip' => "127.0.0.1", 
        'instance_http_port' => 10041, 
        'instance_tags' => {},        
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
      {"port_1" => 8088}
    end
  end
end
