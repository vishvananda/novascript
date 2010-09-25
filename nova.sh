#!/usr/bin/env bash
DIR=`pwd`
CMD=$1
SOURCE_BRANCH=lp:nova
if [ -n "$2" ]; then
    SOURCE_BRANCH=$2
fi
DIRNAME=nova
NOVA_DIR=$DIR/$DIRNAME
if [ -n "$3" ]; then
    NOVA_DIR=$DIR/$3
fi
# script symlinks to this directory
IMAGES_DIR=$DIR/images
USE_PPA=1
USE_VENV=0
TEST=0
USE_MYSQL=0
MYSQL_PASS=nova
USE_LDAP=0
LIBVIRT_TYPE=qemu

if [ "$USE_MYSQL" == 1 ]; then
    SQL_CONN=mysql://root:$MYSQL_PASS@localhost/nova
else
    SQL_CONN=sqlite:///$NOVA_DIR/nova.sqlite
fi

if [ "$USE_LDAP" == 1 ]; then
    AUTH=LdapDriver
else
    REDIS=redis-2.0.0-rc4
    REDIS_DIR=$DIR/$REDIS
    AUTH=FakeLdapDriver
fi

if [ "$USE_VENV" == 1 ]; then
    VENV="$NOVA_DIR/tools/with_venv.sh "
else
    VENV=""
fi

mkdir -p /etc/nova
cat >/etc/nova/nova-manage.conf << NOVA_CONF_EOF
--verbose
--nodaemon
--FAKE_subdomain=ec2
--max_networks=5
--sql_connection=$SQL_CONN
--auth_driver=nova.auth.ldapdriver.$AUTH
--libvirt_type=$LIBVIRT_TYPE
NOVA_CONF_EOF

if [ "$CMD" == "branch" ]; then
    sudo apt-get install -y bzr
    rm -rf $NOVA_DIR
    bzr branch $SOURCE_BRANCH $NOVA_DIR
    cd $NOVA_DIR
    mkdir -p $NOVA_DIR/instances
    mkdir -p $NOVA_DIR/networks
    ln -s $IMAGES_DIR $NOVA_DIR/images
    if [ "$USE_VENV" == 1 ]; then
        sudo apt-get build-dep -y python-m2crypto
        sudo easy_install virtualenv
        python $NOVA_DIR/tools/install_venv.py
        # libvirt isn't auto installed
        cp /usr/lib/python2.6/dist-packages/*libvirt* $NOVA_DIR/.nova-venv/lib/python2.6/site-packages/
        # libxml2 insn't auto installed
        cp /usr/lib/pymodules/python2.6/*libxml2* $NOVA_DIR/.nova-venv/lib/python2.6/site-packages/
    fi
fi

# You should only have to run this once
if [ "$CMD" == "install" ]; then
    if [ "$USE_PPA" == 1 ]; then
        sudo apt-get install -y python-software-properties
        sudo add-apt-repository ppa:nova-core/ppa
        sudo apt-get update
        sudo apt-get install -y user-mode-linux
    fi
    if [ "$USE_MYSQL" == 1 ]; then
        cat <<MYSQL_PRESEED | debconf-set-selections
mysql-server-5.1 mysql-server/root_password password $MYSQL_PASS
mysql-server-5.1 mysql-server/root_password_again password $MYSQL_PASS
mysql-server-5.1 mysql-server/start_on_boot boolean true
MYSQL_PRESEED
        apt-get install -y mysql-server python-mysqldb
    fi
    sudo apt-get install -y screen aoetools euca2ools vlan curl rabbitmq-server
    sudo apt-get install -y dnsmasq vblade-persist kpartx kvm libvirt-bin
    sudo modprobe aoe
    sudo modprobe kvm
    sudo apt-get install -y python-libvirt python-libxml2
    if [ "$USE_VENV" == 0 ]; then
        sudo apt-get build-dep -y python-m2crypto
        sudo easy_install pip
        sudo pip install -r $NOVA_DIR/tools/pip-requires
        sudo pip install  "http://nova.openstack.org/Twisted-10.0.0Nova.tar.gz"
    fi
    if [ "$USE_LDAP" == 0 ]; then
        rm -rf $REDIS
        curl http://redis.googlecode.com/files/$REDIS.tar.gz -fo $REDIS.tar.gz
        tar xvfz $REDIS.tar.gz
        cd $REDIS
        make
        cd $DIR
    fi
fi

NL=`echo -ne '\015'`

function screen_it {
    screen -S nova -X screen -t $1
    screen -S nova -p $1 -X stuff "$2$NL"
}

if [ "$CMD" == "run" ]; then
    killall dnsmasq
    screen -d -m -S nova -t nova
    sleep 1
    if [ "$USE_MYSQL" == 1 ]; then
        mysql -p$MYSQL_PASS -e 'DROP DATABASE nova;'
        mysql -p$MYSQL_PASS -e 'CREATE DATABASE nova;'
    else
        rm $NOVA_DIR/nova.sqlite
    fi
    if [ "$USE_LDAP" == 1 ]; then
        sudo $NOVA_DIR/nova/auth/slap.sh
    else
        rm dump.rdb
        screen_it redis "$DIR/$REDIS/redis-server"
    fi
    rm -rf $NOVA_DIR/instances
    mkdir -p $NOVA_DIR/instances
    rm -rf $NOVA_DIR/networks
    mkdir -p $NOVA_DIR/networks
    $NOVA_DIR/tools/clean-vlans
    ln -s $IMAGES_DIR $NOVA_DIR/images

    if [ "$TEST" == 1 ]; then
        cd $NOVA_DIR
        $VENVpython $NOVA_DIR/run_tests.py
        cd $DIR
    fi

    # create an admin user called 'admin'
    $VENV$NOVA_DIR/bin/nova-manage user admin admin admin admin
    # create a project called 'admin' with project manager of 'admin'
    $VENV$NOVA_DIR/bin/nova-manage project create admin admin
    # export environment variables for project 'admin' and user 'admin'
    $VENV$NOVA_DIR/bin/nova-manage project environment admin admin $NOVA_DIR/novarc

    # nova api crashes if we start it with a regular screen command,
    # so send the start command by forcing text into the window.
    screen_it api "$VENV$NOVA_DIR/bin/nova-api --flagfile=/etc/nova/nova-manage.conf"
    screen_it objectstore "$VENV$NOVA_DIR/bin/nova-objectstore --flagfile=/etc/nova/nova-manage.conf"
    screen_it compute "$VENV$NOVA_DIR/bin/nova-compute --flagfile=/etc/nova/nova-manage.conf"
    screen_it network "$VENV$NOVA_DIR/bin/nova-network --flagfile=/etc/nova/nova-manage.conf"
    screen_it scheduler "$VENV$NOVA_DIR/bin/nova-scheduler --flagfile=/etc/nova/nova-manage.conf"
    screen_it volume "$VENV$NOVA_DIR/bin/nova-volume --flagfile=/etc/nova/nova-manage.conf"
    screen_it test ". $NOVA_DIR/novarc"
    screen -x

if [ "$CMD" == "run" ] || [ "$CMD" == "terminate" ]; then
    # shutdown instances
    . $NOVA_DIR/novarc; euca-describe-instances | grep i- | cut -f2 | xargs euca-terminate-instances
    sleep 2
fi

if [ "$CMD" == "run" ] || [ "$CMD" == "clean" ]; then
    if [ "$USE_LDAP" == 0 ]; then
        # redis simply disconnects on screen kill so force it to die
        killall redis-server
    fi
    screen -S nova -X quit
fi

if [ "$CMD" == "scrub" ]; then
    /srv/cloud/nova/tools/clean-vlans
    if [ "$LIBVIRT_TYPE" == "uml" ]; then
        virsh -c uml:///system list | grep i- | awk '{print \$1}' | xargs -n1 virsh -c uml:///system destroy
    else
        virsh list | grep i- | awk '{print \$1}' | xargs -n1 virsh destroy
    fi
    vblade-persist ls | grep vol- | awk '{print \$1\" \"\$2}' | xargs -n2 vblade-persist destroy
fi
