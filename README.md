Nova Installation Script
========================

This script will install and run nova on ubuntu.

Usage
-----

Unless you want to spend a lot of time fiddling with permissions and sudoers, you should probably run nova as root.

    sudo -i

If you are concerned about security, nova runs just fine inside a virtual machine.  Use the script to install and run the current trunk

    ./nova.sh branch
    ./nova.sh install
    ./nova.sh run

The run command will drop you into a screen session with all of the workers running.  You can use eucatools to run commands against the cloud.

    euca-add-keypair test > test.pem
    euca-run-instances -k test -t m1.tiny ami-tiny
    euca-describe-instances

When the instance is running, you should be able to ssh to it.

    chmod 600 test.pem
    ssh -i test.pem root@10.0.0.3

When you exit screen

    <ctrl-a> <ctrl-d>

nova will terminate.  You can edit files in the install directory or do a bzr pull to pick up new versions. You only need to do

    ./nova.sh run

to run nova after the first install.

Notes
-----

The script starts nova-volume in fake mode, so it will not create any actual volumes.

Customization
-------------

If you are running nova on bare metal that supports hardware virtualization, you should probably edit the libvirt line near the top

    LIBVIRT_TYPE=kvm

If you are running in a virtual machine and software emulation is too slow for you, you can use user mode linux.

    LIBVIRT_TYPE=uml

You will need a few bleeding edge packages to make it work.

    sudo apt-get install -y python-software-properties
    sudo add-apt-repository ppa:nova-core/ppa
    sudo apt-get update
    sudo apt-get install -y libvirt user-mode-linux
