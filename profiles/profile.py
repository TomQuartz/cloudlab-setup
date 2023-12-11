import geni.urn as urn
import geni.portal as portal
import geni.rspec.pg as rspec
import geni.aggregate.cloudlab as cloudlab
import json
import os

# The possible set of base disk-images that this cluster can be booted with.
# The second field of every tupule is what is displayed on the cloudlab
# dashboard.
images = [
    ("UBUNTU22-64-STD", "Ubuntu 22.04 (64-bit)"),
    ("UBUNTU20-64-STD", "Ubuntu 20.04 (64-bit)"),
    ("UBUNTU18-64-STD", "Ubuntu 18.04 (64-bit)"),
    ]

# The possible set of node-types this cluster can be configured with.
nodes = [
    ("xl170", "xl170 (2 x E5-2640v4, 64 GB RAM, Mellanox ConnectX-4)"),
    ("m510", "m510 (2 x Xeon-D, 64 GB RAM, Mellanox ConnectX-3)"),
    ("d430", "d430 (2 x Xeon E5 2630v3, 64 GB RAM, 10 Gbps Intel Ethernet)"),
    ]

# Allows for general parameters like disk image to be passed in. Useful for
# setting up the cloudlab dashboard for this profile.
context = portal.Context()

# Default the disk image to 64-bit Ubuntu 16.04
context.defineParameter("image", "Disk Image",
        portal.ParameterType.IMAGE, images[0], images,
        "Specify the base disk image that all the nodes of the cluster " +\
        "should be booted with.")

# Default the node type to the xl170.
context.defineParameter("type", "Node Type",
        portal.ParameterType.NODETYPE, nodes[0], nodes,
        "Specify the type of nodes the cluster should be configured with.")

# Default the cluster size to 7 nodes.
context.defineParameter("size", "Cluster Size",
        portal.ParameterType.INTEGER, 7, [],
        "Specify the size of the cluster.")

context.defineParameter("names", "hostnames for each node",
        portal.ParameterType.STRING, "", [],
        "Specify the hostnames of the cluster, except for the first node, which is always named gatway. \
            Should be a valid json str, example: \{ \"controller\": 3, \"worker\": 3\}")

context.defineParameter("user", "cloudlab user account",
        portal.ParameterType.STRING, "", [],
        "Specify the cloudlab user account name")

context.defineParameter("script", "cloudlab setup script",
        portal.ParameterType.STRING, "", [],
        "Specify the script path, relative to github repo")

context.defineParameter("storage", "The size for / (GB)", portal.ParameterType.INTEGER, 64)

params = context.bindParameters()

names_json = json.loads(params.names)
hostnames = ["gateway"]
for name, cnt in names_json.items():
    for i in range(cnt):
        hostnames.append(name + str(i+1))

assert params.size == len(hostnames), "The number of hostnames must match the cluster size."

ip_base = "10.10.1."
etc_hosts = '\n'.join(f'{ip_base}{i+1}  {name}' for i, name in enumerate(hostnames))
ssh_hosts = '\n'.join(f"""
Host {name}
    Hostname {ip_base}{i+1}
    User {params.user}
    IdentityFile ~/.ssh/cloudlab_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
""" for i, name in enumerate(hostnames))

request = rspec.Request()

# Create a local area network over a 10 Gbps.
lan = rspec.LAN()
lan.bandwidth = 10000000 # This is in kbps.

# Setup the cluster one node at a time.
for i in range(params.size):
    node = rspec.RawPC(hostnames[i])

    node.hardware_type = params.type
    node.disk_image = urn.Image(cloudlab.Utah, "emulab-ops:%s" % params.image)

    bs = node.Blockstore(str(i), "/")
    bs.size = str(params.storage) + 'GB'

    # Install and run the startup scripts.
    node.addService(rspec.Install(
            url="https://github.com/TomQuartz/cloudlab-setup/archive/main.tar.gz",
            path="/local"))
    node.addService(rspec.Execute(
            shell="sh", command="sudo mv /local/cloudlab-setup-main /local/cloudlab-setup"))
    node.addService(rspec.Execute(
            shell="sh",
            command=f'sudo /local/cloudlab-setup/ssh/setup.sh "{etc_hosts}" "{ssh_hosts}" >/local/logs/ssh_setup.log 2>&1'))
    
    if len(params.script) > 0:
        script = os.path.join("/local/cloudlab-setup", params.script)
        node.addService(rspec.Execute(
            shell="sh",
            command=f'sudo {script} >/local/logs/custom_setup.log 2>&1'))

    request.addResource(node)

    # Add this node to the LAN.
    iface = node.addInterface("eth0")
    lan.addInterface(iface)

# Add the lan to the request.
request.addResource(lan)

# Generate the RSpec
context.printRequestRSpec(request)