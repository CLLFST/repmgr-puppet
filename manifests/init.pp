# == Define: Repmgr
#
# A defined type for managing streaming replication (SR) in postgresql cluster.
#
# Features:
#  * Deploy postgresql cluster
#  * Configure SR on master node (with repmgr)
#  * Configure SR on slave node(s) (with repmgr)
#  * Configure witness node for cluster monitoring (needed for when master failover)
#
# == Parameters
#
# [*ensure*]
# 
# [*role*]
#
# [*name*]
# 
# [*id*]
#
# [*force*]
#   If true, force potentially dangerous operations to happen.
#   Using this option with :
#      master => force bringing the former master up as a standby
#      slave  => forced clone, which overwrites existing data rather than assuming
#                it starts with an empty database directory tree
#   Default to false.
#
# [*master*]
#   The short name (or the FQDN) of the master node that the slave will follow.
#
# [*cluster*]
#   The name of the cluster within you deploy postgresql nodes.
#   This parameter must be identical for all nodes in the same cluster.
#   Default to undef.
#
# [*subnet*]
#   The IP address of the subnet the postgres nodes are connected to (e.g '192.168.1.0/24').
#   The subnet value is used to set postgresql security access rules (pg_hba.conf).
#   Default to undef.
#
# [*ssh_key*]
#   The postgres user SSH public key.
#   Default to undef.
#
# == Examples
#
#   Postgresql Master Config
#
#   repmgr {'pg_master':
#       ensure     => present,
#       role       => master,
#       name       => 'node1',
#       id         => 1,
#       cluster    => 'pg_cluster_name',
#       subnet     => '192.168.1.0/24',
#       ssh_key    => 'AAAAB3Nza....M366wq5',
#   }
#
#   Postgresql Slave Config
#
#   repmgr {'pg_slave':
#       ensure     => present,
#       role       => slave,
#       name       => 'node2',
#       id         => 2,
#       master     => 'node1',
#       force      => true,
#       cluster    => 'pg_cluster_name',
#       subnet     => '192.168.1.0/24',
#       ssh_key    => 'AAAAB3Nza....M366wq5',
#   }
#
# == Authors
#
# Ahmed Bessifi <ahmed.bessifi@gmail.com>
#
# == Licence
#
# GNU GPLv2 - Copyright (C) 2014 Ahmed Bessifi
#

define repmgr(
    $ensure = 'present',
    $role = undef,
    $name = $title,
    $id = undef,
    $master = undef,
    $cluster = undef,
    $subnet = undef,
    $ssh_key = undef,
    $force = false, 
){

    # Some basic tests
    if $cluster == undef {
        fail("Cluster name is required !")
    }
    if $name == undef {
        fail("Node name is required !")
    }
    if $id == undef {
        fail("Node id is required !")
    }
    if $subnet == undef {
        fail("Cluster subnet IP address is not correct !")
    }
    if $ssh_key == undef {
        fail("repmgr public key is required to setup access between nodes !")
    }

    # Setting up repmgr regarding node's role
    case $role {

        'master' : {

            class { 'repmgr::install':
                node_role         => $role,
                pg_cluster_subnet => $subnet,
            } ->
            
            class { 'repmgr::config':
                node_role      => $role,
                cluster_name   => $cluster,
                node_id        => $id,
                node_name      => $name,
                conninfo_host  => $name,
                repmgr_ssh_key => $ssh_key,
            }
        }

        'slave' : {
            if  $master == undef {
                fail("Master node name required !")
            }
            class { 'repmgr::install':
                node_role         => $role,
                pg_cluster_subnet => $subnet,
            } ->
            class { 'repmgr::config':
                node_role      => $role,
                cluster_name   => $cluster,
                node_id        => $id,
                node_name      => $name,
                conninfo_host  => $name,
                repmgr_ssh_key => $ssh_key,
                master_node    => $master,
                force_action   => $force,
            }
        }

        default : { fail("Invalid value given for role : $role. Must be one of master|slave|witness")  }
    }
}
