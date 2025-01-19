require 'erubi'
require 'rails/all'
require 'ood_core'
require 'ood_appkit'
require './command'

set :erb, :escape_html => true

if development?
  require 'sinatra/reloader'
  also_reload './command.rb'
end

# 应用配置
APP_CONFIG = {
  # 功能开关
  features: {
    job_owner_check: 'on'  # 设置 'on' 或 'off' 来控制作业所有权检查
  },
  
  # Grafana 配置
  grafana: {
    host: "https://polyu-studio.dongjunhpc.com.cn:64000",
    dashboard_id: "iuCOu9qMz",
    dashboard_name: "slurm-single-job-1-0",
    panels: [
      { id: 11, name: "CPU Usage" },
      { id: 20, name: "Memory Usage" }
    ]
  }
}

helpers do
  def dashboard_title
    "DJHPC-POLYU STUDIO"
  end

  def dashboard_url
    "/pun/sys/dashboard/"
  end

  def title
    "Job Stats Helper"
  end

  def grafana_base_url
    config = APP_CONFIG[:grafana]
    "#{config[:host]}/d-solo/#{config[:dashboard_id]}/#{config[:dashboard_name]}?orgId=1&refresh=30s&theme=light&kiosk&hideControls=1"
  end

  def generate_panel_iframe(url, panel_name)
    <<-HTML
      <div class="panel-container">
        <h4>#{panel_name}</h4>
        <iframe src="#{url}" 
                width="100%" 
                height="300" 
                frameborder="0" 
                style="border: none; background: transparent;">
        </iframe>
      </div>
    HTML
  end

  def generate_error_message(error)
    <<-HTML
      <div class="alert alert-danger" style="margin-top: 10px; padding: 10px; border-radius: 4px; background-color: #f8d7da; border: 1px solid #f5c6cb; color: #721c24;">
        <strong>Error:</strong> #{error}
      </div>
    HTML
  end
end

OODClusters = OodCore::Clusters.new(OodAppkit.clusters.select(&:allow?))

get '/' do
  erb :index
end

post '/' do
  @command = Command.new
  jobid = params[:jobid]
  cluster = params[:cluster]
  base_url = grafana_base_url
  
  if jobid
    @details, @error = @command.exec(jobid, cluster)
    if request.xhr?
      if @error
        generate_error_message(@error)
      else
        data = ""
        @details.strip.split(' ') do |line|
          sd = line.strip.split('|')
          if sd.size != 4
            data = generate_error_message("Invalid sacct output #{@details}")
          else
            sd[0] += "000"
            if sd[1] == 'Unknown'
              sd[1] = "now"
            else
              sd[1] += "000"
            end
            
            # 生成基本 URL（用于完整页面链接）
            full_url = "#{APP_CONFIG[:grafana][:host]}/d/#{APP_CONFIG[:grafana][:dashboard_id]}/#{APP_CONFIG[:grafana][:dashboard_name]}?orgId=1&refresh=30s&theme=light&from=#{sd[0]}&to=#{sd[1]}&var-job_id=#{sd[3]}"
            
            if sd[2] != sd[3]
              desc = "array job %s, raw job id %s" % [sd[2], sd[3]]
            else
              desc = "job id %s" % sd[3]
            end
            
            # 生成主链接
            data += '<p><a href="%s" target="_blank">Open webpage with stats for %s</a></p>' % [full_url, desc]
            
            # 生成所有面板
            data += '<div class="grafana-panels">'
            APP_CONFIG[:grafana][:panels].each do |panel|
              panel_url = "#{base_url}&from=#{sd[0]}&to=#{sd[1]}&var-job_id=#{sd[3]}&panelId=#{panel[:id]}"
              data += generate_panel_iframe(panel_url, panel[:name])
            end
            data += '</div>'
            
            # 添加样式
            data += <<-CSS
              <style>
                .grafana-panels {
                  display: flex;
                  flex-direction: column;
                  gap: 20px;
                  margin-top: 20px;
                }
                .panel-container {
                  background: #f8f9fa;
                  padding: 10px;
                  border-radius: 4px;
                  box-shadow: 0 1px 3px rgba(0,0,0,0.1);
                }
                .panel-container h4 {
                  margin: 0 0 10px 0;
                  color: #333;
                  font-size: 16px;
                  font-weight: 500;
                }
                .alert {
                  margin-bottom: 15px;
                }
                a {
                  color: #007bff;
                  text-decoration: none;
                }
                a:hover {
                  text-decoration: underline;
                }
              </style>
            CSS
          end
        end
        data
      end
    else
      @details
    end
  end
end