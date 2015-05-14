# .bashrc
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: /root/.bashrc to setup CloudForms aliases on the appliance. 
#

# User specific aliases and functions
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Directory aliases
alias vmdb='cd /var/www/miq/vmdb'
alias lib='cd /var/www/miq/lib'
alias log='cd /var/www/miq/vmdb/log'

# Tail aliases
alias auto='tail -f /var/www/miq/vmdb/log/automation.log'
alias evm='tail -f /var/www/miq/vmdb/log/evm.log'
alias prod='tail -f /var/www/miq/vmdb/log/production.log'
alias policy='tail -f /var/www/miq/vmdb/log/policy.log'
alias pglog='tail -f /opt/rh/postgresql92/root/var/lib/pgsql/data/pg_log/postgresql.log'

# Clean logging aliases
alias clean="echo Cleaned: `date` > /var/www/miq/vmdb/log/automation.log;echo Cleaned: `date` > /var/www/miq/vmdb/log/evm.log;echo Cleaned: `date` > /var/www/miq/vmdb/log/production.log;clear;echo Logs cleaned..."
alias clean_evm="echo Cleaned: `date` > /var/www/miq/vmdb/log/evm.log"
alias clean_aws="echo Cleaned: `date` > /var/www/miq/vmdb/log/aws.log"
alias clean_rhevm="echo Cleaned: `date` > /var/www/miq/vmdb/log/rhevm.log"
alias clean_fog="echo Cleaned: `date` > /var/www/miq/vmdb/log/fog.log"
alias clean_auto="echo Cleaned: `date` > /var/www/miq/vmdb/log/automation.log"
alias clean_prod="echo Cleaned: `date` > /var/www/miq/vmdb/log/production.log"
alias clean_policy="echo Cleaned: `date` > /var/www/miq/vmdb/log/policy.log"
alias clean_pgsql="echo Cleaned: `date` > /opt/rh/postgresql92/root/var/lib/pgsql/data/pg_log/postgresql.log"

# Black Console
alias black_console="LOCK_CONSOLE=false /bin/appliance_console"

# Rails Console
alias railsc="cd /var/www/miq/vmdb;echo '\$evm = MiqAeMethodService::MiqAeService.new(MiqAeEngine::MiqAeWorkspaceRuntime.new)'; script/rails c"

# Application Status
alias status='echo "EVM Status:";service evmserverd status;echo " ";echo "HTTP Status:";service httpd status'

# Ignore duplicate history commands
export HISTCONTROL=ignoredups

# Source global definitions
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi