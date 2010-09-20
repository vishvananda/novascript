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
    sudo apt-get install -y libvirt-bin user-mode-linux

If you have any issues, there is usually someone in #openstack on irc.freenode.net that can help you out.
