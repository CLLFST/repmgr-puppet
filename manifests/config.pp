class repmgr::config (

    $node_role = undef,
    $cluster_name = undef,
    $node_id = undef,
    $node_name = undef,
    $conninfo_host = undef,
    $repmgr_ssh_key = undef,
    $master_node = undef,
    $force_action = false,
){
    $conninfo_user = 'repmgr'
    $conninfo_dbname = 'repmgr'
    $pg_bindir = '/usr/lib/postgresql/9.1/bin'
    $master_response_timeout = 20
    $reconnect_attempts = 4
    $reconnect_interval = 10
    $failover = 'automatic'
    $promote_command = 'repmgr -f /etc/repmgr/repmgr.conf standby promote'
    $follow_command  = '/var/lib/postgresql/follow_command.sh'
    $loglevel = 'DEBUG'
    $monitor_interval = 5

    $pg_ctl = '/usr/lib/postgresql/9.1/bin/pg_ctl'
    $pg_logfile = '/var/log/postgresql/postgresql-9.1-main.log'
    $pg_data = '/var/lib/postgresql/9.1/main'
    $pg_configdir = '/etc/postgresql/9.1/main'    
    $pg_contribdir = '/usr/share/postgresql/9.1/contrib'

    $repmgr_config_file = '/etc/repmgr/repmgr.conf'
    #$repmgr_opts = join(['--force', '--verbose'], ' ')
    $repmgr_opts = join(['--force', '--verbose'], ' ')

    Account['postgres'] -> File['repmgr_config_file'] -> File['pg_ssh_config']

    # Create repmgr config dir
    file {'/etc/repmgr':
        ensure => 'directory',
        owner  => root,
        group  => root,
        mode   => '0755',
    }

    # Generate repmgr config file
    file {'repmgr_config_file':
        ensure    => present,
        owner     => postgres,
        group     => postgres,
        mode      => '0644',
        content   => template('repmgr/repmgr.conf.erb'),
        path      => $repmgr_config_file,
    }

    # Assert postgres user exists
    account {'postgres':
        ensure => present,
        home_dir   => '/var/lib/postgresql',
        ssh_keys         => {
            'repmgr_key' => {
                type     => 'ssh-rsa',
                key      => $repmgr_ssh_key,
             }
        }
    }

    file {'pg_ssh_config':
        path  => '/var/lib/postgresql/.ssh/config',
        owner => postgres,
        group => postgres,
        mode  => 644,
        content => 'StrictHostKeyChecking no',
    }


    if $node_role == 'master' {
        
        # Create the user and database to manage replication
        Exec['create_repmgr_db_user'] -> Exec['create_repmgr_db'] -> Exec['master_register']
        
        exec {'create_repmgr_db_user':
            path     => ['/bin/','/usr/bin'],
            command  => 'createuser -s repmgr',
            user     => 'postgres',
            onlyif   => '[ `psql template1 -c "\du" | grep -c repmgr` -eq "0" ]',
        }
        exec{'create_repmgr_db':
            path     => ['/bin', '/usr/bin'],
            command  => "createdb -O repmgr repmgr && psql -f $pg_contribdir/repmgr_funcs.sql repmgr",
            user     => 'postgres',
            onlyif   => '[ `psql -l | grep -c repmgr` -eq "0" ]',
        }

        exec {'master_register':
            path    => ['/bin', '/usr/bin'],
            command => "repmgr -f $repmgr_config_file master register",
            user    => 'postgres',
            onlyif  => [
                "psql -l | grep repmgr",
                "[ `repmgr -f $repmgr_config_file cluster show | grep -c master` -eq 0 ]"
            ],
        }
    }
    elsif $node_role in ['slave', 'witness'] {

        Exec['stop_standby'] -> Exec['clone_master']
        
        # Stop standby node if running
        exec {'stop_standby':
            path => ['/usr/bin', '/usr/lib/postgresql/9.1/bin'],
            command => "sudo -u postgres $pg_ctl -D $pg_data stop -l $pg_logfile",
            onlyif  => "[ killall -0 postgres | grep -c postgres` -eq 0 ]",
        }
        # Clone the master and start standby
        exec {'clone_master':
            path    => ['/usr/bin'],
            command => "sudo -u postgres repmgr -f $repmgr_config_file -D $pg_data -d repmgr -U repmgr -R postgres standby clone $master_node $repmgr_opts",
            notify  => Service['postgresql'],
        }
        # Register the standby server
        # Start repmgrd daemon
    }

}