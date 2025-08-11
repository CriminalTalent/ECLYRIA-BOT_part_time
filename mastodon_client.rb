# mastodon_client.rb - 스토리 봇용 확장
require 'mastodon'
require 'uri'
require 'json'
require 'net/http'

class MastodonClient
  def initialize(base_url:, token:)
    @base_url = base_url
    @client = Mastodon::REST::Client.new(
      base_url: base_url,
      bearer_token: token
    )
    
    # Streaming 클라이언트 초기화를 지연시킴
    @streamer = nil
  end

  # 스트리밍 클라이언트 초기화 (필요할 때만)
  def get_streamer
    @streamer ||= Mastodon::Streaming::Client.new(
      base_url: @base_url,
      bearer_token: @client.instance_variable_get(:@bearer_token)
    )
  rescue => e
    puts "[경고] 스트리밍 클라이언트 초기화 실패: #{e.message}"
    nil
  end

  # 실시간 멘션 스트리밍 처리 (전투봇용)
  def stream_user(&block)
    puts "[마스토돈] 멘션 스트리밍 시작..."
    streamer = get_streamer
    return unless streamer
    
    streamer.user do |event|
      if event.is_a?(Mastodon::Notification) && event.type == 'mention'
        block.call(event)
      end
    end
  rescue => e
    puts "[에러] 스트리밍 중단됨: #{e.message}"
    sleep 5
    retry
  end

  # 스토리 툳 발송 (스토리 봇 전용)
  def create_story_toot(content:, visibility: 'public', attachment_url: nil)
    begin
      puts "[마스토돈] 스토리 툿 발송 시작"
      
      options = {
        visibility: visibility
      }
      
      # 첨부파일 처리
      if attachment_url && !attachment_url.empty?
        media_id = upload_media(attachment_url)
        options[:media_ids] = [media_id] if media_id
      end
      
      # 툿 발송
      result = @client.create_status(content, **options)
      
      puts "[성공] 툿 발송 완료: #{result.id}"
      return result
      
    rescue => e
      puts "[에러] 툿 발송 실패: #{e.message}"
      return nil
    end
  end

  # 미디어 업로드
  def upload_media(url_or_path)
    begin
      if url_or_path.start_with?('http')
        # URL에서 다운로드
        media_data = download_media(url_or_path)
        return nil unless media_data
        
        # 임시 파일로 저장
        temp_filename = "/tmp/story_media_#{Time.now.to_i}"
        File.open(temp_filename, 'wb') { |f| f.write(media_data) }
        
        # 업로드
        media = @client.upload_media(temp_filename)
        
        # 임시 파일 삭제
        File.delete(temp_filename) if File.exist?(temp_filename)
        
        return media.id
      else
        # 로컬 파일
        if File.exist?(url_or_path)
          media = @client.upload_media(url_or_path)
          return media.id
        else
          puts "[에러] 파일을 찾을 수 없습니다: #{url_or_path}"
          return nil
        end
      end
    rescue => e
      puts "[에러] 미디어 업로드 실패: #{e.message}"
      return nil
    end
  end

  # URL에서 미디어 다운로드
  def download_media(url)
    begin
      uri = URI(url)
      response = Net::HTTP.get_response(uri)
      
      if response.code == '200'
        return response.body
      else
        puts "[에러] 미디어 다운로드 실패: HTTP #{response.code}"
        return nil
      end
    rescue => e
      puts "[에러] 미디어 다운로드 에러: #{e.message}"
      return nil
    end
  end

  # 스케줄된 툿 생성 (미래 시점 발송)
  def create_scheduled_toot(content:, scheduled_at:, visibility: 'public', attachment_url: nil)
    begin
      puts "[마스토돈] 스케줄 툿 생성: #{scheduled_at}"
      
      options = {
        visibility: visibility,
        scheduled_at: scheduled_at.iso8601
      }
      
      # 첨부파일 처리
      if attachment_url && !attachment_url.empty?
        media_id = upload_media(attachment_url)
        options[:media_ids] = [media_id] if media_id
      end
      
      # 스케줄 툿 생성
      result = @client.create_status(content, **options)
      
      puts "[성공] 스케줄 툿 생성 완료: #{result.id}"
      return result
      
    rescue => e
      puts "[에러] 스케줄 툿 생성 실패: #{e.message}"
      return nil
    end
  end

  # 멘션에 답글 작성 (전투봇용)
  def reply(to_acct, message, in_reply_to_id: nil)
    begin
      puts "[마스토돈] → @#{to_acct} 에게 응답 전송"
      status_text = "@#{to_acct} #{message}".dup
      @client.create_status(
        status_text,
        visibility: 'unlisted',
        in_reply_to_id: in_reply_to_id
      )
    rescue => e
      puts "[에러] 응답 전송 실패: #{e.message}"
    end
  end

  # 전체 공지용 푸시 (전투봇용)
  def broadcast(message)
    begin
      puts "[마스토돈] → 전체 공지 전송"
      @client.create_status(
        message,
        visibility: 'public'
      )
    rescue => e
      puts "[에러] 공지 전송 실패: #{e.message}"
    end
  end

  # 일반 포스트 (전투봇용)
  def say(message)
    begin
      puts "[마스토돈] → 일반 포스트 전송"
      @client.create_status(
        message,
        visibility: 'public'
      )
    rescue => e
      puts "[에러] 포스트 전송 실패: #{e.message}"
    end
  end

  # DM 전송 (전투봇용)
  def dm(to_acct, message)
    begin
      puts "[마스토돈] → @#{to_acct} DM 전송"
      status_text = "@#{to_acct} #{message}".dup
      @client.create_status(
        status_text,
        visibility: 'direct'
      )
    rescue => e
      puts "[에러] DM 전송 실패: #{e.message}"
    end
  end

  # 계정 정보 확인
  def me
    @client.verify_credentials.acct
  end

  # 스케줄된 툿 목록 조회
  def scheduled_toots
    begin
      @client.scheduled_statuses
    rescue => e
      puts "[에러] 스케줄 툿 조회 실패: #{e.message}"
      []
    end
  end

  # 스케줄된 툿 삭제
  def cancel_scheduled_toot(scheduled_toot_id)
    begin
      @client.delete_scheduled_status(scheduled_toot_id)
      puts "[성공] 스케줄 툿 삭제: #{scheduled_toot_id}"
      true
    rescue => e
      puts "[에러] 스케줄 툿 삭제 실패: #{e.message}"
      false
    end
  end

  # 연결 상태 확인
  def connection_test
    begin
      me_info = @client.verify_credentials
      puts "[연결테스트] 성공 - @#{me_info.acct}"
      true
    rescue => e
      puts "[연결테스트] 실패 - #{e.message}"
      false
    end
  end
end
