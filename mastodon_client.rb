# mastodon_client.rb
require 'net/http'
require 'json'
require 'uri'

class MastodonClient
  def initialize(base_url:, token:)
    @base_url = base_url.sub(/\/\z/, '')
    @token = token
  end

  # 멘션 가져오기
  def fetch_mentions(since_id: nil)
    uri = URI("#{@base_url}/api/v1/notifications?types[]=mention&limit=20")
    uri.query += "&since_id=#{since_id}" if since_id

    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = "Bearer #{@token}"

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end

    if res.is_a?(Net::HTTPSuccess)
      JSON.parse(res.body)
    else
      puts "[HTTP 오류] #{res.code} #{res.message}"
      []
    end
  rescue => e
    puts "[에러] 멘션 불러오기 실패: #{e.message}"
    []
  end

  # 답글 전송
  def reply(content, in_reply_to_id, visibility: 'unlisted')
    uri = URI("#{@base_url}/api/v1/statuses")
    req = Net::HTTP::Post.new(uri)
    req['Authorization'] = "Bearer #{@token}"
    req.set_form_data(
      'status' => content,
      'in_reply_to_id' => in_reply_to_id,
      'visibility' => visibility
    )

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end

    puts "[답글] #{res.code} - #{content[0..50]}..."
    res.code.to_i < 300
  rescue => e
    puts "[에러] 답글 전송 실패: #{e.message}"
    false
  end

  # 공개 포스트
  def post(content, visibility: 'public')
    uri = URI("#{@base_url}/api/v1/statuses")
    req = Net::HTTP::Post.new(uri)
    req['Authorization'] = "Bearer #{@token}"
    req.set_form_data(
      'status' => content,
      'visibility' => visibility
    )

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end

    puts "[포스트] #{res.code}"
    res.code.to_i < 300
  rescue => e
    puts "[에러] 포스트 전송 실패: #{e.message}"
    false
  end
end
