# global
PRIMARY = 'swarm-1'
NETWORK = SecureRandom.hex(16)
C1 = "#{NETWORK}-c1"
C2 = "#{NETWORK}-c2"

RSpec.shared_examples 'docker' do
  describe command('docker version') do
    its(:stdout) { should match /Version:\s+1\.9/ }
  end
  describe port('2375') do
    it { should be_listening.with('tcp6') }
  end
  describe port('7946') do
    it { should be_listening.with('tcp') }
  end
  describe port('7946') do
    it { should be_listening.with('udp') }
  end
end

RSpec.shared_examples 'consul' do
  describe command('consul version') do
    its(:stdout) { should match /Consul v0\.5\.\d+/ }
  end
  describe port('8400') do
    it { should be_listening.with('tcp6') }
  end
  describe port('8500') do
    it { should be_listening.with('tcp6') }
  end
  describe port('8600') do
    it { should be_listening.with('tcp6') }
    it { should be_listening.with('udp6') }
  end
end

RSpec.shared_examples 'containers' do |c1,c2,network|
  context "container #{c1} has hostname" do
    describe command("docker -H :3000 exec -i #{c1} hostname") do
      its(:stdout) { should match c1 }
    end

    # XXX investigate docker run hostname and fqdn support
    xdescribe command("docker -H #{PRIMARY}:3000 exec -i #{c1} hostname -f") do
      its(:stdout) { should match "#{c1}.#{network}" }
    end
  end
  context "container #{c1} pings self" do
    describe command("docker -H #{PRIMARY}:3000 exec -i #{c1} ping -c 1 #{c1}") do
      its(:stdout) { should match /1 packets transmitted, 1 packets received, 0% packet loss/ }
    end
    xdescribe command("docker -H #{PRIMARY}:3000 exec -i #{c1} ping -c 1 #{c1}.#{network}") do
      its(:stdout) { should match /1 packets transmitted, 1 packets received, 0% packet loss/ }
    end
  end
  context "container #{c1} pings peer #{c2}" do
    describe command("docker -H #{PRIMARY}:3000 exec -i #{c1} ping -c 1 #{c2}") do
      its(:stdout) { should match /1 packets transmitted, 1 packets received, 0% packet loss/ }
    end
    describe command("docker -H #{PRIMARY}:3000 exec -i #{c1} ping -c 1 #{c2}.#{network}") do
      its(:stdout) { should match /1 packets transmitted, 1 packets received, 0% packet loss/ }
    end
  end
end

RSpec.shared_examples 'cluster' do
  # docker via swarm on primary
  describe command("docker -H #{PRIMARY}:3000 info") do
    its(:stdout) { should match /Nodes: 2/ }
  end
  describe command('consul members') do
    its(:stdout) do
      should match /swarm-1\s+\S+:8301\s+alive/
      should match /swarm-2\s+\S+:8301\s+alive/
    end
  end

  # running swarm and swarm manager (primary)
  describe 'swarm instances'  do
    subject { command('docker ps | grep swarm | wc -l').stdout.to_i }
    it { expect(subject).to be >= 1 }
  end

  # XXX returns one IP even if swarm & manger constainers are both running
  describe command('docker inspect --format \'{{ .NetworkSettings.IPAddress }}\' swarm') do
    its(:stdout) { should match /^\d+\.\d+\.\d+\.\d+$/ }
  end
end

RSpec.shared_examples 'cluster-primary' do
  include_examples 'cluster'

  # more consul ports
  describe 'consul primary' do
    describe port('8300') do
      it { should be_listening.with('tcp') }
    end
    describe port('8301') do
      it { should be_listening.with('tcp') }
      it { should be_listening.with('udp') }
    end
    describe port('8302') do
      it { should be_listening.with('udp') }
    end
  end

  describe 'swarm' do
    before :all do
      command("docker network create --driver overlay #{NETWORK}").stdout
      # launch container c1 through swarm server contrained to host swarm-1
      command("docker -H :3000 run -itd --net=#{NETWORK} --name #{C1} --hostname #{C1} --env='constraint:node==swarm-1' busybox").stdout
      # launch container c2 through swarm server contrained to host swarm-2
      command("docker -H :3000 run -itd --net=#{NETWORK} --name #{C2} --hostname #{C2} --env='constraint:node==swarm-2' busybox").stdout
    end
    describe 'containers' do
      it_behaves_like 'containers', C1, C2, NETWORK
    end
  end
end

RSpec.shared_examples 'cluster-non-primary' do
  include_examples 'cluster'

  describe 'containers' do
    it_behaves_like 'containers', C1, C2, NETWORK
  end
end
