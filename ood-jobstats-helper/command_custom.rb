require 'open3'

class Command
  def to_s(jobid, cluster)
    "/usr/bin/sacct -P -n -X -o start,end,jobid,jobidraw -M %s -j %s" % [cluster, jobid]
  end

  def check_job_owner(jobid)
    # 如果功能关闭，直接返回 true
    return true, nil unless APP_CONFIG[:features][:job_owner_check] == 'on'
    
    # 获取作业所属用户
    cmd = "/usr/bin/sacct -P -n -o User -j #{jobid}"
    stdout_str, stderr_str, status = Open3.capture3(cmd)
    
    if status.success?
      job_user = stdout_str.strip
      current_user = ENV['USER']
      
      # 返回检查结果和错误信息（如果有）
      if job_user.empty?
        return false, "No job found with ID #{jobid}"
      elsif job_user != current_user
        return false, "Access Denied: Job #{jobid} belongs to user #{job_user}. Please enter your own job ID."
      else
        return true, nil
      end
    else
      return false, "Error checking job ownership: #{stderr_str}"
    end
  end

  AppProcess = Struct.new(:user, :pid, :pct_cpu, :pct_mem, :vsz, :rss, :tty, :stat, :start, :time, :command)

  # Parse a string output from the `ps aux` command and return an array of
  # AppProcess objects, one per process
  def parse(output)
    lines = output.strip.split("\n")
    lines.map do |line|
      AppProcess.new(*(line.split(" ", 11)))
    end
  end

  # Execute the command, and parse the output, returning and array of
  # AppProcesses and nil for the error string.
  #
  # returns [Array<Array<AppProcess>, String] i.e.[processes, error]
  def exec(jobid, cluster)
    # 首先检查作业所有权（如果功能开启）
    is_owner, error = check_job_owner(jobid)
    return nil, error unless is_owner

    # 如果是作业所有者或检查被关闭，继续获取作业信息
    stdout_str, stderr_str, status = Open3.capture3(
      {'SLURM_TIME_FORMAT' => '%s'},
      to_s(jobid, cluster)
    )

    if status.success?
      return stdout_str, nil
    else
      return nil, "Querying jobid #{jobid} for cluster #{cluster} exited with error: #{stderr_str}"
    end
  end
end