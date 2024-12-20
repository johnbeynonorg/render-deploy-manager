# myapp.rb
require 'sinatra'
require 'json'
require 'uri'
require 'net/http'

get '/health' do
  status 200
end

get '/deploy' do
  config = File.read('config.json')
  parsed_data = JSON.parse(config)
  api_key = parsed_data['api_key']
  results = []

  target_group = parsed_data['groups'].find { |group| group['deploy_key'] == params['deploy_key'] }
 
  if target_group
    puts "Triggering deploys for #{target_group["name"]}"

    on_failure = target_group["failure"]

    if target_group["strategy"] == "sequential" # handle sequential deploys
      puts "Deploying #{target_group["services"].count} services sequentially"
      target_group["services"].each do |service|
        deployment = trigger_deployment(service["service_id"], api_key) 
        result = wait_for_successful_deploy(service["service_id"], deployment["id"], api_key)
        results << {service_id: service["service_id"], deploy_id: deployment["id"], result: result}
        if result == "failed"
          puts "Deploy #{deployment["id"]} failed ❌"
          break # Stop any more deployments if one fails
        end
      end
    elsif target_group["strategy"] == "parallel" # handle parallel deploys
      puts "Deploying #{target_group["services"].count} services in parallel"
      target_group["services"].each do |service|
        deployment = trigger_deployment(service["service_id"], api_key)
      end
    end

    failed_count = results.count { |result| result[:result] == "failed" }
    if failed_count > 0 # Did we have any failures?
      if on_failure == "rollback" # Handle any rollbacks
        results.each_with_index do |result, index|
          # need to find where in the results was the failure. If it's the first one, we don't need to do anything
          if result[:result] == "failed"
            if index > 0
              puts "#{results[index-1][:service_id]} needs to be rolled back"

              # What was the last deployment that was deactivated?
              last_deactivated_deployment = get_last_deactivated_deployment(results[index-1][:service_id], api_key)
              last_deactivated_deployment_id = last_deactivated_deployment['deploy']['id']

              # Trigger the rollback and get a new deployment id for the rollback
              rollback_deployment = rollback_deploy(results[index-1][:service_id], last_deactivated_deployment_id, api_key)
              puts "Rolling back #{results[index-1][:service_id]} to #{last_deactivated_deployment_id} because #{result[:service_id]} failed"
              wait_for_successful_deploy(results[index-1][:service_id], rollback_deployment["id"], api_key)
            else
              puts "No need to rollback service #{result[:service_id]} as it was the first in the group to fail"
              break
            end
          end
        end
      end
    else
      puts "All services in the group were deployed successfully! 🚀"
    end
    
  else
    status 404
    "Deploy Key not found"
  end
end















##### API Helper methods follow #####

def trigger_deployment(service_id, api_key)
  url = URI("https://api.render.com/v1/services/#{service_id}/deploys")

  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true

  request = Net::HTTP::Post.new(url)
  request["accept"] = 'application/json'
  request["content-type"] = 'application/json'
  request["authorization"] =  "Bearer #{api_key}"
  request.body = "{\"clearCache\":\"do_not_clear\"}"

  response = JSON.parse(http.request(request).read_body)
  puts "Triggered deploy #{response["id"]} for service #{service_id}"

  response
end

def get_last_deactivated_deployment(service_id, api_key)
  url = URI("https://api.render.com/v1/services/#{service_id}/deploys?status=deactivated&limit=1")

  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true

  request = Net::HTTP::Get.new(url)
  request["accept"] = 'application/json'
  request["content-type"] = 'application/json'
  request["authorization"] =  "Bearer #{api_key}"

  JSON.parse(http.request(request).read_body).first
end

def get_deployment(service_id, deploy_id, api_key)
  url = URI("https://api.render.com/v1/services/#{service_id}/deploys/#{deploy_id}")

  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true

  request = Net::HTTP::Get.new(url)
  request["accept"] = 'application/json'
  request["content-type"] = 'application/json'
  request["authorization"] =  "Bearer #{api_key}"

  JSON.parse(http.request(request).read_body)
end

def rollback_deploy(service_id, deploy_id, api_key)
  url = URI("https://api.render.com/v1/services/#{service_id}/rollback")

  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true

  request = Net::HTTP::Post.new(url)
  request["accept"] = 'application/json'
  request["content-type"] = 'application/json'
  request["authorization"] =  "Bearer #{api_key}"
  request.body = {deployId: deploy_id}.to_json

  puts "Rollback triggered for #{service_id} to #{deploy_id}"
  JSON.parse(http.request(request).read_body)
end

def wait_for_successful_deploy(service_id, deploy_id, api_key)
  failure_statuses = ["build_failed", "update_failed", "canceled", "pre_deploy_failed"]

  loop do
    deployment_status = get_deployment(service_id, deploy_id, api_key)
    puts "--> Current deployment status: #{deployment_status["status"]}"
    if deployment_status["status"] == "live"
      puts "Deploy #{deploy_id} is live! ✅"
      break "success"
    elsif deployment_status["status"] == "build_in_progress"
      puts "Deploy #{deploy_id} is still in progress" 
    elsif failure_statuses.include? deployment_status["status"]
      puts "Deploy #{deploy_id} failed!"
      break "failed"
    end
    sleep 10
  end
end