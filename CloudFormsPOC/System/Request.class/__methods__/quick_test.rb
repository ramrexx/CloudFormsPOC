# ServiceNow_Eccq_REST_Insert.rb
#
# Description: This method uses a REST call to post data to Service-Now's Ecc Queue
#
require 'base64'
require 'rest_client'
require 'xmlsimple'
require 'json'

def service_now_post(action, ref=nil, content_type=:xml, accept=:xml, body=nil)
  servername = nil
  servername ||= $evm.object['servername']

  username = 'manageiq'
  username ||= $evm.object['username']

  password = 'manageiq'
  password ||= $evm.object.decrypt('password')

  # if ref is a url then use that one instead
  unless ref.nil?
    url = ref if ref.include?('http')
  end
  url ||= "https://#{servername}#{ref}"

  params = {
    :method=>action,
    :url=>url,
    :user=>username,
    :password=>password,
    :headers=>{
      :content_type=>content_type,
      :accept=>accept
    }
  }
  if content_type == :json
    params[:payload] = JSON.generate(body) if body
  elsif content_type == :xml
    params[:payload] = XmlSimple.xml_out(body) if body
  else
    params[:payload] = body if body
  end
  $evm.log(:info, "Calling -> Service-Now: #{url} action: #{action} payload: #{params[:payload]}")

  #rest_response = RestClient::Request.new(params).execute
  # Follow redirections for all request types and not only for get and head
  # RFC : "If the 301, 302 or 307 status code is received in response to a request other than GET or HEAD,
  #        the user agent MUST NOT automatically redirect the request unless it can be confirmed by the user,
  #        since this might change the conditions under which the request was issued."
  RestClient.get(url){ |response, request, result, block|
    $evm.log(:info, "Inspecting response: #{response.inspect}")
    $evm.log(:info, "Inspecting request: #{request.inspect}")
    $evm.log(:info, "Inspecting result: #{result.inspect}")

    if [301, 302, 307].include? response.code
      response.follow_redirection(request, result, block)
    else
      response.return!(request, result, block)
    end
  }

  $evm.log(:info, "Inspecting -> Service-Now rest_response: #{rest_response.inspect}")
  $evm.log(:info, "Inspecting -> Service-Now headers: #{rest_response.headers.inspect}")
  unless rest_response.code == 200 || rest_response.code == 201 || rest_response.code == 202
    raise "Failure <- Service-Now Response: #{rest_response.code}"
  end
  # use XmlSimple to convert xml to ruby hash
  response_hash = XmlSimple.xml_in(rest_response)
  $evm.log(:info, "Inspecting response_hash: #{response_hash.inspect}")
  return response_hash
end


payload = {'VM' => 'vm123'}

body = {
  :agent             => 'EVM Agent',
  :agent_correlator  => 'EVM agent_correlator',
  :from_host         => 'EVM Host',
  :name              => 'EVM Name',
  :payload           => payload,
  :queue             => 'input',
  :source            => 'EVM Source',
  :topic             => 'EVM Topic',
}

service_now_post(:post, '/api/now/table/ecc_queue', :json, :xml, body)
