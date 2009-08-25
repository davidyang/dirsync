#!/usr/bin/ruby
require 'rubygems'
require 'logger'
require 'benchmark'
require 'ping'
require 'fileutils'
require 'open3'

# Local Machine options === DIR OPTIONS ===

localdir = "/chroots/kashless/home/kashless"
remotedir = "/home/tech/gconomy/kashless"

sync_uni_to = [ "uploads" ]
sync_uni_from = [ "log", "processed" ]
sync_two_way = []

# === END OF DIR OPTIONS ===

# == Options for the remote machine.

SSH_USER      = 'tech'
SSH_SERVER    = '192.168.1.145'
SSH_PORT      = '' #Leave blank for default (port 22).
RSYNC_VERBOSE = '-v'
RSYNC_OPTS    = "--force --ignore-errors -az"
RSYNC_ONE_WAY_OPTS = "--remove-source-files"


#============================= OPTIONS ==============================#
# == Options for local machine.
SSH_APP       = 'ssh'
RSYNC_APP     = '/usr/bin/rsync'

#EXCLUDE_FILE  = '/path/to/.rsyncignore'
#DIR_TO_BACKUP = '/folder/to/backup'
LOG_FILE      = '/var/log/rrsync.log'
LOG_AGE       = 'daily'

EMPTY_DIR     = '/tmp/empty_rsync_dir/' #NEEDS TRAILING SLASH.
# == Options to control output
DEBUG         = true #If true output to screen else output is sent to log file.
SILENT        = false #Total silent = no log or screen output.
#========================== END OF OPTIONS ==========================#

if DEBUG && !SILENT
  logger = Logger.new(STDOUT, LOG_AGE)
elsif LOG_FILE != '' && !SILENT
  logger = Logger.new(LOG_FILE, LOG_AGE)
else
  logger = Logger.new(nil)
end
ssh_port = SSH_PORT.empty? ? '' : "-e 'ssh -p #{SSH_PORT}'"

#rsync_cleanout_cmd = "#{RSYNC_APP} #{RSYNC_VERBOSE} #{ssh_port} --delete -a #{EMPTY_DIR} #{SSH_USER}@#{SSH_SERVER}:#{BACKUP_DIR}"
#rsync_cmd = "#{RSYNC_APP} #{RSYNC_VERBOSE} #{ssh_port} #{RSYNC_OPTS} #{DIR_TO_BACKUP} #{SSH_USER}@#{SSH_SERVER}:#{BACKUP_ROOT}/current"

rsync_cmd = "#{RSYNC_APP} #{RSYNC_VERBOSE} #{ssh_port} #{RSYNC_OPTS}"
rsync_one_way_cmd = "#{rsync_cmd} #{RSYNC_ONE_WAY_OPTS}"

logger.info("Started running at: #{Time.now}")
run_time = Benchmark.realtime do
  begin
    raise Exception, "Unable to find remote host (#{SSH_SERVER})" unless Ping.pingecho(SSH_SERVER)

    # uni-to sync
    sync_uni_to.each do |dir| 
      rsync_uni_to = "#{rsync_one_way_cmd} #{localdir}/#{dir}/ #{SSH_USER}@#{SSH_SERVER}:#{remotedir}/#{dir}"
      Open3::popen3("#{rsync_uni_to}") { |stdin, stdout, stderr|
        tmp_stdout = stdout.read.strip
        tmp_stderr = stderr.read.strip
        logger.info("#{rsync_cmd}\n#{tmp_stdout}") unless tmp_stdout.empty?
        logger.error("#{rsync_cmd}\n#{tmp_stderr}") unless tmp_stderr.empty?
      }
    end

    # uni-from sync
    sync_uni_from.each do |dir| 
      rsync_uni_from = "#{rsync_one_way_cmd} #{SSH_USER}@#{SSH_SERVER}:#{remotedir}/#{dir}/ #{localdir}/#{dir}/"
      Open3::popen3("#{rsync_uni_from}") { |stdin, stdout, stderr|
        tmp_stdout = stdout.read.strip
        tmp_stderr = stderr.read.strip
        logger.info("#{rsync_cmd}\n#{tmp_stdout}") unless tmp_stdout.empty?
        logger.error("#{rsync_cmd}\n#{tmp_stderr}") unless tmp_stderr.empty?
      }
    end

    # bi sync
    sync_two_way.each do |dir| 
      rsync_two_way = "#{rsync_cmd} #{localdir}/#{dir}/ #{SSH_USER}@#{SSH_SERVER}:#{remotedir}/#{dir}"
      Open3::popen3("#{rsync_two_way}") { |stdin, stdout, stderr|
        tmp_stdout = stdout.read.strip
        tmp_stderr = stderr.read.strip
        logger.info("#{rsync_cmd}\n#{tmp_stdout}") unless tmp_stdout.empty?
        logger.error("#{rsync_cmd}\n#{tmp_stderr}") unless tmp_stderr.empty?
      }
    end
    
    
  rescue Errno::EACCES, Errno::ENOENT, Errno::ENOTEMPTY, Exception => e
    logger.fatal(e.to_s)
  end
end
logger.info("Finished running at: #{Time.now} - Execution time: #{run_time.to_s[0, 5]}")
