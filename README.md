# Using Puppet to launch a Docker Swarm

[Docker Swarm](https://docs.docker.com/swarm/) is part of the official
Docker orchestration effort, and allows for managing containers across a
fleet of hosts rather than just on a single host.

The [Puppet Docker module](https://forge.puppetlabs.com/garethr/docker)
supports installing and managing Docker, and running individual docker
containers. Given Swarm is packaged as containers, that means we can
install a Swarm cluster using Puppet.

Swarm supports a number of [discovery
backends](http://docs.docker.com/swarm/discovery/). For this example
I'll be using [Consul](https://www.consul.io/), again all managed by
Puppet.

## Usage

    vagrant up --provider virtualbox

This will launch 2 virtual machines, install Consul and register a
cluster, install Docker and Swarm and then establish the swarm.

You can access the swwarm using a docker client, either from you local
machine or from one of the virtual machines. For instance:

    docker -H tcp://10.20.3.11:3000 info

If you don't have docker installed locally you can run the above command
from one of the virtual machines using:

    vagrant ssh swarm-1 -c "docker -H tcp://localhost:3000 info"

This should print something like:

    Containers: 4
    Nodes: 2
     swarm-1: 10.20.3.11:2375
      └ Containers: 3
      └ Reserved CPUs: 0 / 1
      └ Reserved Memory: 0 B / 490 MiB
     swarm-2: 10.20.3.12:2375
      └ Containers: 1
      └ Reserved CPUs: 0 / 1
      └ Reserved Memory: 0 B / 490 MiB

## Growing the cluster

We can also automatically scale the cluster by launching additional
virtual machines.

    INSTANCES=4 vagrant up --provider virtualbox

This will give us a total of 4 virtual machines, 2 new ones and the 2
existing machines we already launched. Once the machines have launched
you should be able to run the above commands again, this time you'll get
something like:

    Containers: 6
    Nodes: 4
     swarm-1: 10.20.3.11:2375
      └ Containers: 3
      └ Reserved CPUs: 0 / 1
      └ Reserved Memory: 0 B / 490 MiB
     swarm-2: 10.20.3.12:2375
      └ Containers: 1
      └ Reserved CPUs: 0 / 1
      └ Reserved Memory: 0 B / 490 MiB
     swarm-3: 10.20.3.13:2375
      └ Containers: 1
      └ Reserved CPUs: 0 / 1
      └ Reserved Memory: 0 B / 490 MiB
     swarm-4: 10.20.3.14:2375
      └ Containers: 1
      └ Reserved CPUs: 0 / 1
      └ Reserved Memory: 0 B / 490 MiB

## The Tour

More features added to this project include

* gliderlabs/registrator
* dnsmasq
* consul ui

Quick recap on consul API - create

    # docker run -d -p 8080:8080 --name="hello" mrbarker/python-flask-hello
    # docker run -d -p 8081:8080 -p 8443:8443 --name="hello2" mrbarker/python-flask-hello
    <id>

    # docker logs registrator

This demonstrates the automatic registration of services into consul. The
following shows the registration and the subsequent DNS requests.

    # curl localhost:8500/v1/catalog/services
    {"consul":[],"python-flask-hello":[],"python-flask-hello-8080":[],"python-flask-hello-8443":[],"swarm":[]}

    # curl localhost:8500/v1/catalog/nodes
    [{"Node":"swarm-1","Address":"10.20.3.11"}]

Check DNS by appending .service.consul to the service names,

    # dig python-flask-hello-8443.service.consul +short
    172.17.0.5
    # dig python-flask-hello-8443.service.consul -t srv +short
    1 1 8443 swarm-1.node.dc1.consul.
    # dig python-flask-hello-8443.service.consul -t srv +short

Reverse DNS - (XXX double check long vs short name returned)

    # dig swarm-1.node.dc1.consul +short
    10.20.3.11
    # dig -x 10.20.3.11 +short
    swarm-1.

## Implementation details

The example uses the Docker module to launch the swarm containers. First
we run the main swarm container on all hosts.

```puppet
::docker::run { 'swarm':
  image   => 'swarm',
  command => "join --addr=${::ipaddress_eth1}:2375 consul://${::ipaddress_eth1}:8500/swarm_nodes"
}
```

Then on one host we run the swarm manager:

```puppet
::docker::run { 'swarm-manager':
  image   => 'swarm',
  ports   => '3000:2375',
  command => "manage consul://${::ipaddress_eth1}:8500/swarm_nodes",
  require => Docker::Run['swarm'],
}
```

Consul is managed by the excellent [Consul
module](https://github.com/solarkennedy) from [Kyle
Anderson](https://github.com/solarkennedy). Much of the Consul
configuration is in the hiera data, for example:

```yaml
consul::config_hash:
  data_dir: '/opt/consul'
  client_addr: '0.0.0.0'
  bind_addr: "%{::ipaddress_eth1}"
```

## Testing

Install vagrant-serverspec plugin

```
$ vagrant plugin install vagrant-serverspec --plugin-version '1.0.1'
$ vagrant plugin install rspec_junit_formatter
```

Through the magic of vagrant-serverspec, running the tests is just a matter of
provisioning the test VM.

```
$ vagrant up test
```

This will write output to `rspec.xml` for Bamboo junit test parser.
