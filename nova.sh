#!/usr/bin/env bash
REDIS=redis-2.0.0-rc4
BRANCH=lp:nova
USE_VENV=0
TEST=0
LIBVIRT_TYPE=qemu

DIR=`pwd`
NOVA_DIR=$DIR/nova
REDIS_DIR=$DIR/$REDIS
IMAGES_DIR=$DIR/images
if [ "$USE_VENV" == 1 ]; then
    VENV="$NOVA_DIR/tools/with_venv.sh "
else
    VENV=""
fi
CMD=$1

if [ "$CMD" == "branch" ]; then
    apt-get install -y bzr
    if [ -n "$2" ]; then
        BRANCH=$2
    fi
    rm -rf $NOVA_DIR
    bzr branch $BRANCH $NOVA_DIR
    cd $NOVA_DIR
    mkdir $NOVA_DIR/instances
    ln -s $IMAGES_DIR $NOVA_DIR/images
    if [ "$USE_VENV" == 1 ]; then
        sudo apt-get build-dep -y python-m2crypto
        sudo easy_install virtualenv
        python $NOVA_DIR/tools/install_venv.py
        # libvirt isn't auto installed
        cp /usr/lib/python2.6/dist-packages/*libvirt* $NOVA_DIR/.nova-venv/lib/python2.6/site-packages/
        # libxml2 insn't auto installed
        cp /usr/lib/pymodules/python2.6/*libxml2* $NOVA_DIR/.nova-venv/lib/python2.6/site-packages/
        echo $NOVA_DIR > $NOVA_DIR/.nova-venv/lib/python2.6/site-packages/nova.pth
    fi
fi

# You should only have to run this once
if [ "$CMD" == "install" ]; then
    sudo apt-get install -y aoetools euca2ools vlan curl rabbitmq-server
    sudo apt-get install -y dnsmasq vblade-persist kpartx kvm libvirt-bin
    sudo modprobe aoe
    sudo modprobe kvm
    sudo apt-get install -y python-libvirt python-libxml2
    if [ "$USE_VENV" == 0 ]; then
        sudo apt-get build-dep -y python-m2crypto
        sudo easy_install pip
        sudo pip install -r $NOVA_DIR/tools/pip-requires
        sudo pip install  "http://nova.openstack.org/Twisted-10.0.0Nova.tar.gz"
        echo $NOVA_DIR | sudo tee /usr/lib/python2.6/dist-packages/nova.pth
    fi
    rm -rf $REDIS
    curl http://redis.googlecode.com/files/$REDIS.tar.gz -fo $REDIS.tar.gz
    tar xvfz $REDIS.tar.gz
    cd $REDIS
    make
    cd $DIR
fi

function screen_it {
    NL=`echo -ne '\015'`
    screen -S nova -X screen -t $1
    screen -S nova -p $1 -X stuff "$2$NL"
}

if [ "$CMD" == "run" ]; then
    killall dnsmasq
    rm nova.sqlite
    rm dump.rdb
    # start redis
    screen -d -m -S nova -t nova
    sleep 1
    screen_it redis "$DIR/$REDIS/redis-server"

    if [ "$TEST" == 1 ]; then
        cd $NOVA_DIR
        $VENVpython $NOVA_DIR/run_tests.py
        cd $DIR
    fi

    # create an admin user called 'admin'
    $VENV$NOVA_DIR/bin/nova-manage user admin admin
    # create a project called 'admin' with project manager of 'admin'
    $VENV$NOVA_DIR/bin/nova-manage project create admin admin
    # export environment variables for project 'admin' and user 'admin'
    $VENV$NOVA_DIR/bin/nova-manage project environment admin admin $NOVA_DIR/novarc

    # nova api crashes if we start it with a regular screen command,
    # so send the start command by forcing text into the window.
    screen_it api "$VENV$NOVA_DIR/bin/nova-api --verbose"
    screen_it objectstore "$VENV$NOVA_DIR/bin/nova-objectstore --verbose --nodaemon"
    screen_it compute "$VENV$NOVA_DIR/bin/nova-compute --verbose --nodaemon --libvirt_type=$LIBVIRT_TYPE"
    screen_it network "$VENV$NOVA_DIR/bin/nova-network --verbose --nodaemon"
    screen_it scheduler "$VENV$NOVA_DIR/bin/nova-scheduler --verbose --nodaemon"
    screen_it volume "$VENV$NOVA_DIR/bin/nova-volume --verbose --nodaemon"
    screen_it test ". $NOVA_DIR/novarc$NL"
    screen -x

    # shutdown screen
    # redis simply disconnects on screen kill so force it to die
    killall redis-server
    # nova-api doesn't like being killed, so try to ctrl-c it
    screen -S nova -p api -X stuff ""
    sleep 1
    screen -S nova -p api -X stuff ""
    screen -S nova -X quit
fi


