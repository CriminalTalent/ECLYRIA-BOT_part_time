# story_manager.rb
class StoryManager
  def initialize(mastodon_client, sheet_manager)
    @mastodon_client = mastodon_client
    @sheet_manager = sheet_manager
  end

  # 특정 순서의 스토리 발송
  def send_story(schedule_id, story_order)
    story = get_story(schedule_id, story_order)
    
    unless story
      puts "[에러] 스토리를 찾을 수 없습니다: #{schedule_id} - #{story_order}"
      return false
    end

    content = story["내용"]
    visibility = story["가시성"] || "public"
    mentions = story["멘션"]
    attachment_url = story["첨부파일"]

    return false if content.nil? || content.empty?

    begin
      # 멘션 처리
      if mentions && !mentions.empty?
        # 멘션이 있으면 내용 앞에 추가
        mention_text = mentions.split(/[,\s]+/).map { |m| m.start_with?('@') ? m : "@#{m}" }.join(' ')
        content = "#{mention_text} #{content}"
      end

      # 툿 발송
      toot_result = @mastodon_client.create_story_toot(
        content: content,
        visibility: visibility,
        attachment_url: attachment_url
      )

      if toot_result
        # 발송 완료 표시
        mark_story_sent(schedule_id, story_order)
        
        puts "[발송완료] #{schedule_id} - #{story_order}: #{content[0..50]}..."
        return true
      else
        puts "[발송실패] #{schedule_id} - #{story_order}: 툿 발송 실패"
        return false
      end

    rescue => e
      puts "[에러] 스토리 발송 중 에러: #{e.message}"
      return false
    end
  end

  # 모든 스토리 일괄 발송 (테스트용)
  def send_all_stories(schedule_id, delay_seconds = 5)
    stories = get_all_stories(schedule_id)
    
    if stories.empty?
      puts "[에러] 스케줄 #{schedule_id}에 스토리가 없습니다."
      return false
    end

    puts "[일괄발송] #{schedule_id}: #{stories.length}개 스토리 발송 시작"
    
    stories.each do |story|
      story_order = story["순서"].to_i
      
      success = send_story(schedule_id, story_order)
      
      if success
        puts "[진행] #{story_order}/#{stories.length} 발송 완료"
      else
        puts "[실패] #{story_order}번째 스토리 발송 실패"
        return false
      end
      
      # 다음 스토리까지 대기
      sleep(delay_seconds) if story_order < stories.length
    end
    
    puts "[완료] 모든 스토리 발송 완료"
    true
  end

  # 특정 스토리 재발송
  def resend_story(schedule_id, story_order)
    puts "[재발송] #{schedule_id} - #{story_order} 재발송 시도"
    send_story(schedule_id, story_order)
  end

  # 예약된 스토리 목록 조회
  def get_story_list(schedule_id)
    stories = get_all_stories(schedule_id)
    
    if stories.empty?
      return "스케줄 #{schedule_id}에 등록된 스토리가 없습니다."
    end

    list_text = "=== #{schedule_id} 스토리 목록 ===\n"
    stories.each do |story|
      status = story["발송완료"] == "Y" ? "✅" : "⏳"
      preview = story["내용"][0..30].gsub("\n", " ")
      list_text += "#{story['순서']}. #{status} #{preview}...\n"
    end
    
    list_text
  end

  private

  # 특정 스토리 조회
  def get_story(schedule_id, story_order)
    values = @sheet_manager.read_values("스토리!A:H")
    return nil if values.nil? || values.empty?
    
    headers = values[0]
    
    values.each_with_index do |row, index|
      next if index == 0 # 헤더 스킵
      
      if row[0] == schedule_id && row[1]&.to_i == story_order
        story = {}
        headers.each_with_index do |header, col_index|
          story[header] = row[col_index]
        end
        return story
      end
    end
    
    nil
  end

  # 스케줄의 모든 스토리 조회
  def get_all_stories(schedule_id)
    values = @sheet_manager.read_values("스토리!A:H")
    return [] if values.nil? || values.empty?
    
    headers = values[0]
    stories = []
    
    values.each_with_index do |row, index|
      next if index == 0 # 헤더 스킵
      
      if row[0] == schedule_id
        story = {}
        headers.each_with_index do |header, col_index|
          story[header] = row[col_index]
        end
        stories << story
      end
    end
    
    # 순서대로 정렬
    stories.sort_by { |story| story["순서"].to_i }
  end

  # 스토리 발송 완료 표시
  def mark_story_sent(schedule_id, story_order)
    values = @sheet_manager.read_values("스토리!A:H")
    return unless values && values.length > 1
    
    values.each_with_index do |row, index|
      next if index == 0
      
      if row[0] == schedule_id && row[1]&.to_i == story_order
        row_num = index + 1
        current_time = Time.now.strftime('%Y-%m-%d %H:%M:%S')
        
        # G열: 발송완료
        @sheet_manager.update_values("스토리!G#{row_num}", [["Y"]])
        
        # H열: 발송시간
        @sheet_manager.update_values("스토리!H#{row_num}", [[current_time]])
        
        break
      end
    end
  end

  # 스토리 발송 완료 취소 (재발송용)
  def unmark_story_sent(schedule_id, story_order)
    values = @sheet_manager.read_values("스토리!A:H")
    return unless values && values.length > 1
    
    values.each_with_index do |row, index|
      next if index == 0
      
      if row[0] == schedule_id && row[1]&.to_i == story_order
        row_num = index + 1
        
        # G열: 발송완료 취소
        @sheet_manager.update_values("스토리!G#{row_num}", [["N"]])
        
        # H열: 발송시간 초기화
        @sheet_manager.update_values("스토리!H#{row_num}", [[""]])
        
        break
      end
    end
    
    puts "[취소] #{schedule_id} - #{story_order} 발송 완료 표시 취소"
  end

  # 스토리 통계
  def get_story_statistics(schedule_id)
    stories = get_all_stories(schedule_id)
    
    if stories.empty?
      return "스케줄 #{schedule_id}에 스토리가 없습니다."
    end

    total_count = stories.length
    sent_count = stories.count { |story| story["발송완료"] == "Y" }
    pending_count = total_count - sent_count
    
    first_sent = stories.find { |story| story["발송완료"] == "Y" && !story["발송시간"].to_s.empty? }
    last_sent = stories.reverse.find { |story| story["발송완료"] == "Y" && !story["발송시간"].to_s.empty? }
    
    stats = "=== #{schedule_id} 통계 ===\n"
    stats += "전체 스토리: #{total_count}개\n"
    stats += "발송 완료: #{sent_count}개\n"
    stats += "대기 중: #{pending_count}개\n"
    stats += "진행률: #{(sent_count.to_f / total_count * 100).round(1)}%\n"
    
    if first_sent
      stats += "첫 발송: #{first_sent['발송시간']}\n"
    end
    
    if last_sent
      stats += "마지막 발송: #{last_sent['발송시간']}\n"
    end
    
    stats
  end

  # 스토리 내용 미리보기
  def preview_story(schedule_id, story_order)
    story = get_story(schedule_id, story_order)
    
    unless story
      return "스토리를 찾을 수 없습니다: #{schedule_id} - #{story_order}"
    end

    preview = "=== 스토리 미리보기 ===\n"
    preview += "스케줄 ID: #{schedule_id}\n"
    preview += "순서: #{story_order}\n"
    preview += "가시성: #{story['가시성'] || 'public'}\n"
    preview += "멘션: #{story['멘션'] || '없음'}\n"
    preview += "첨부파일: #{story['첨부파일'] || '없음'}\n"
    preview += "발송완료: #{story['발송완료'] || 'N'}\n"
    preview += "내용:\n#{story['내용']}"
    
    preview
  end
end
