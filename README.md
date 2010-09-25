Nova Installation Script
========================

This script will install and run nova on ubuntu.

Usage
-----

Unless you want to spend a lot of time fiddling with permissions and sudoers, you should probably run nova as root.

    sudo -i

If you are concerned about security, nova runs just fine inside a virtual machine.

You will need disk images for your cloud to run.  You can get one here, but you have to download it by hand:

    http://wiki.openstack.org/InstallInstructions?action=AttachFile&do=get&target=images.tgz

untar the file to create a usable images directory

    tar -zxf /path/to/images.tgz

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

The script starts nova-volume in fake mode, so it will not create any actual volumes.

if you want to USE_VENV because you have different versions of python packages on your system that you want to keep, you should run install before branch:

    ./nova.sh install
    ./nova.sh branch
    ./nova.sh run

Currently the script does not set up natting rules for instances and contacting the metadata api.  These will be part of nova soon.  In the meantime you can do it manually like so:

    iptables -t nat -A PREROUTING -d 169.254.169.254/32 -p tcp -m tcp --dport 80 -j DNAT --to-destination <host_ip_address>:8773
    iptables -t nat -A POSTROUTING -s 10.0.0.0/16 -j SNAT --to-source <host_ip_address>
    iptables -t nat -A POSTROUTING -s 10.0.0.0/16 -j MASQUERADE
    iptables -t nat -A POSTROUTING -s 10.0.0.0/16 -d 10.128.0.0/12 -j ACCEPT

If <host_ip_address> is on an interface that routes to the public internet, your instances should be able to communicate with the outside world.

Customization
-------------

You can make nova use mysql instead of sqlite with USE_MYSQL, it will attempt to install mysql with the specified root password and create a database called nova.

If you are running nova on bare metal that supports hardware virtualization, you should probably edit the libvirt line near the top

    LIBVIRT_TYPE=kvm

If you are running in a virtual machine and software emulation is too slow for you, you can use user mode linux.

    LIBVIRT_TYPE=uml

You will need a few bleeding edge packages to make it work, so you should make sure to use the PPA.

    USE_PPA=1

If you have any issues, there is usually someone in #openstack on irc.freenode.net that can help you out.
