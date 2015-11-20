# Base class for all nodes in the swarm
#
class base {
  hiera_include('classes')

  sudo::conf { 'vagrant':
    priority => 30,
    content  => 'vagrant ALL=(ALL) NOPASSWD:ALL',
  }

  file { '/etc/update-motd.d':
    purge => true,
  }

  ::docker::image { 'swarm:latest': }
  ::docker::image { 'busybox': }
  ::docker::image { 'gliderlabs/registrator:latest': }

  ::docker::run { 'swarm':
    image            => 'swarm:latest',
    command          => "join --addr=${::ipaddress_eth1}:2375 consul://${::ipaddress_eth1}:8500/swarm_nodes",
    extra_parameters => '--name swarm',
    require          => Class['docker::service'],
  }
  ::docker::run { 'registrator':
    image            => 'gliderlabs/registrator:latest',
    volumes          => [ '/var/run/docker.sock:/tmp/docker.sock' ],
    command          => "consul://${::ipaddress_eth1}:8500",
    extra_parameters => '--name registrator',
    require          => Class['docker::service'],
  }

  # Ensure dnsmasq is installed after package work for consul and docker;
  # otherwise DNS resolution issues if dnsmasq is installed but service hasn't
  # started yet; affects further package installations.
  class { '::dnsmasq':
    require => [
      Class['consul'],
      Class['docker'],
    ],
  }
  dnsmasq::conf { 'consul':
    ensure  => present,
    content => 'server=/consul/127.0.0.1#8600',
  }

  package{'unzip':
    ensure => present,
    before => Class['consul'],
  }
}

node 'swarm-1' {
  include ::base

  ::docker::run { 'swarm-manager':
    image            => 'swarm',
    ports            => '3000:2375',
    command          => "manage consul://${::ipaddress_eth1}:8500/swarm_nodes",
    extra_parameters => '--name swarm-manager',
    require          => Class['docker::service'],
  }
}

node default {
  include ::base

  exec { 'consul join swarm-1':
    path      => '/usr/local/bin/',
    require   => Class['consul'],
    before    => Class['docker'],
    tries     => 10,
    try_sleep => 1,
  }

}
