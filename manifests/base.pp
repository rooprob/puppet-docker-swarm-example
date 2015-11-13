class base {
  hiera_include('classes')

  sudo::conf { 'vagrant':
    priority => 30,
    content  => 'vagrant ALL=(ALL) NOPASSWD:ALL',
  }

  file { '/etc/update-motd.d':
    purge => true
  }

  ::docker::image { 'swarm:latest': }
  ::docker::image { 'busybox': }
  ::docker::image { 'gliderlabs/registrator:latest': }

  ::docker::run { 'swarm':
    image            => 'swarm:latest',
    command          => "join --addr=${::ipaddress_eth1}:2375 consul://${::ipaddress_eth1}:8500/swarm_nodes",
    extra_parameters => '--name swarm'
  }
  ::docker::run { 'registrator':
    image            => 'gliderlabs/registrator:latest',
    volumes          => [ '/var/run/docker.sock:/tmp/docker.sock' ],
    command          => "consul://${::ipaddress_eth1}:8500",
    extra_parameters => '--name registrator'
  }

  include dnsmasq
  dnsmasq::conf { 'consul':
    ensure  => present,
    content => 'server=/consul/127.0.0.1#8600',
  }

  package{'unzip':
    ensure => present
  }
}

node 'swarm-1' {
  include base

  ::docker::run { 'swarm-manager':
    image            => 'swarm',
    ports            => '3000:2375',
    command          => "manage consul://${::ipaddress_eth1}:8500/swarm_nodes",
    require          => Docker::Run['swarm'],
    extra_parameters => '--name swarm-manager'
  }
}

node default {
  include base

  exec { 'consul join swarm-1':
    path      => '/usr/local/bin/',
    require   => Class['consul'],
    before    => Class['docker'],
    tries     => 10,
    try_sleep => 1,
  }

}
