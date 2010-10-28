Nova Installation Script
========================

This script will install and run nova on ubuntu.

Usage
-----

Unless you want to spend a lot of time fiddling with permissions and sudoers, you should probably run nova as root.

    sudo -i

If you are concerned about security, nova runs just fine inside a virtual machine.

Use the script to install and run the current trunk. You can also specify a specific branch by putting lp:~someone/nova/some-branch after the branch command

    ./nova.sh branch
    ./nova.sh install
    ./nova.sh run

The run command will drop you into a screen session with all of the workers running in different windows  You can use eucatools to run commands against the cloud.

    euca-add-keypair test > test.pem
    euca-run-instances -k test -t m1.tiny ami-tiny
    euca-describe-instances

To see output from the various workers, switch screen windows

    <ctrl-a> "

will give you a list of running windows.

When the instance is running, you should be able to ssh to it.

    chmod 600 test.pem
    ssh -i test.pem root@10.0.0.3

When you exit screen

    <ctrl-a> <ctrl-d>

nova will terminate.  It may take a while for nova to finish cleaning up.  If you exit the process before it is done because there were some problems in your build, you may have to clean up the nova processes manually.  If you had any instances running, you can attempt to kill them through the api:

    ./nova.sh terminate

Then you can destroy the screen:

    ./nova.sh clean

If things get particularly messed up, you might need to do some more intense cleanup.  Be careful, the following command will manually destroy all runnning virsh instances and attempt to delete all vlans and bridges.

    ./nova.sh scrub

You can edit files in the install directory or do a bzr pull to pick up new versions. You only need to do

    ./nova.sh run

to run nova after the first install.  The database should be cleaned up on each run.

Notes
-----

A sample image should be downloaded by the script, but if necessary you can download it by hand:

    wget http://c2477062.cdn.cloudfiles.rackspacecloud.com/images.tgz

untar the file to create a usable images directory

    tar -zxf /path/to/images.tgz

If you want to be able to contact the metadata server and route to the outside world from instances, you will need to make sure $HOST_IP is set properly.  The script attemps to grab it from ifconfig, but if you have multiple adapters set up, it may fail.  Fix it with export HOST_IP="<your public ip>":

Customization
-------------

You can make nova use mysql instead of sqlite with USE_MYSQL, it will attempt to install mysql with the specified root password and create a database called nova.

If you are running nova on bare metal that supports hardware virtualization, you should probably edit the libvirt line near the top

    LIBVIRT_TYPE=kvm

If you are running in a virtual machine and software emulation is too slow for you, you can use user mode linux.

    LIBVIRT_TYPE=uml

If you have any issues, there is usually someone in #openstack on irc.freenode.net that can help you out.
