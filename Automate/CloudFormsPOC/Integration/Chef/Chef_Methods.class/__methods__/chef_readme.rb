# chef_readme.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: Chef integration requires that the knife client be installed and 
#   properly configured on each appliance with the automate role
#
# Steps to install and configure knife:
#
# 1. Install knife
curl -L https://www.chef.io/chef/install.sh | sudo bash

# 2. Create the .chef directory
mkdir /root/.chef 
   
# 3. copy client_key (i.e. root.pem) file to the .chef directory. 

# 4. create /root/.chef/knife.rb file. 
#    NOTE: knife.rb must be correctly configured. More info: https://docs.chef.io/config_rb_knife.html
#    SAMPLE: below is a sample from a working knife.rb file with bare minimum settings
cat << EOF > /root/.chef/knife.rb
node_name                'root'
client_key               '/root/.chef/root.pem'
chef_server_url          'https://mychefserver.com:443'
ssl_verify_mode          :verify_none
EOF

# 4. Test the knife client - If the knife command below executes without error you are all set. 
knife  node   list

# 5. TroubleShooting:
If knife is not working it is most likely related to:
a) knife.rb file is not configured
b) client_key (i.e. root.pem) is not valid
