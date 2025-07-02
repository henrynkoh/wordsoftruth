#!/usr/bin/env ruby
require 'net/http'
require 'uri'
require 'json'

puts "🔐 YOUTUBE TOKEN EXCHANGE HELPER"
puts "=" * 50

client_id = ENV['GOOGLE_CLIENT_ID'] || 'your-google-client-id'
client_secret = ENV['GOOGLE_CLIENT_SECRET'] || 'your-google-client-secret'
redirect_uri = "urn:ietf:wg:oauth:2.0:oob"

puts "📋 Step 1: Visit this URL to get authorization code:"
puts ""
auth_url = "https://accounts.google.com/o/oauth2/auth?" + 
           "client_id=#{client_id}&" +
           "redirect_uri=#{redirect_uri}&" +
           "scope=https://www.googleapis.com/auth/youtube.upload&" +
           "response_type=code&" +
           "access_type=offline&" +
           "prompt=consent"

puts auth_url
puts ""
puts "📝 Step 2: After authorization, you'll see a page with an authorization code."
puts "📝 Step 3: Copy that code and enter it below."
puts ""
print "Enter authorization code: "
auth_code = gets.chomp

if auth_code.empty?
  puts "❌ No authorization code provided"
  exit 1
end

puts ""
puts "🔄 Exchanging authorization code for tokens..."

# Exchange code for tokens
uri = URI('https://oauth2.googleapis.com/token')
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Post.new(uri)
request['Content-Type'] = 'application/x-www-form-urlencoded'

params = {
  'client_id' => client_id,
  'client_secret' => client_secret,
  'code' => auth_code,
  'grant_type' => 'authorization_code',
  'redirect_uri' => redirect_uri
}

request.body = URI.encode_www_form(params)

begin
  response = http.request(request)
  
  if response.code == '200'
    data = JSON.parse(response.body)
    
    puts "✅ SUCCESS! Tokens received:"
    puts ""
    puts "🔑 Access Token:"
    puts data['access_token']
    puts ""
    puts "🔄 Refresh Token:"
    puts data['refresh_token']
    puts ""
    puts "📋 To use these tokens, set environment variables:"
    puts "export YOUTUBE_ACCESS_TOKEN=\"#{data['access_token']}\""
    puts "export YOUTUBE_REFRESH_TOKEN=\"#{data['refresh_token']}\""
    puts ""
    puts "🎯 Now you can upload YouTube videos!"
    
  else
    puts "❌ Token exchange failed:"
    puts "Status: #{response.code}"
    puts "Response: #{response.body}"
  end
  
rescue => e
  puts "❌ Error: #{e.message}"
end