# commands/job_start_command.rb
require 'time'

class JobStartCommand
  @@last_job_time = {}
  COOLDOWN_HOURS = 2

  JOBS = {
    "도서관 사서 보조" => {
      base_pay: 10,
      description: "고서 정리와 금지 서가 목록 관리",
      stat: :luck,
      events: [
        "먼지 낀 고서를 조심스럽게 정리했습니다",
        "책들이 제자리를 찾아가고 있습니다",
        "금지 서가 근처를 신중하게 지나갔습니다",
        "오래된 마법서에서 희미한 빛이 났습니다",
        "목록 작성이 순조롭게 진행됩니다"
      ]
    },
    "온실 관리 조수" => {
      base_pay: 15,
      description: "3학년 실습용 마법 식물 관리",
      stat: :agility,
      events: [
        "물을 주던 중 덩굴이 살짝 움직였습니다",
        "식물들이 건강하게 자라고 있습니다",
        "가시에 찔릴 뻔했지만 잘 피했습니다",
        "온실 온도를 적절히 조절했습니다",
        "독성 식물을 안전하게 다뤘습니다"
      ]
    },
    "우편배달" => {
      base_pay: 12,
      description: "부엉이 우편 분류 및 긴급 배달",
      stat: :agility,
      events: [
        "부엉이들이 협조적이었습니다",
        "편지를 정확한 주소로 분류했습니다",
        "급한 우편을 빠르게 처리했습니다",
        "복도를 달려 제시간에 전달했습니다",
        "비 오는 날이었지만 우편은 무사합니다"
      ]
    },
    "퀴디치 용품 관리" => {
      base_pay: 13,
      description: "경기용 장비 점검 및 정비",
      stat: :attack,
      events: [
        "빗자루 손잡이를 깨끗이 닦았습니다",
        "공들이 제대로 작동하는지 확인했습니다",
        "낡은 장비를 교체 목록에 올렸습니다",
        "보호 장구를 점검하고 수리했습니다",
        "빗자루 빗살을 손질했습니다"
      ]
    },
    "물약 재료 준비" => {
      base_pay: 14,
      description: "고급 물약 재료 세척과 보관",
      stat: :luck,
      events: [
        "재료를 정확한 크기로 자르고 있습니다",
        "약초를 조심스럽게 세척했습니다",
        "보관 용기에 라벨을 붙였습니다",
        "희귀한 재료를 특별 보관했습니다",
        "측정이 정확하게 이루어졌습니다"
      ]
    },
    "마법 생물 돌보기" => {
      base_pay: 16,
      description: "3학년 수업용 마법 생물 관리",
      stat: :defense,
      events: [
        "생물들에게 먹이를 주었습니다",
        "우리를 청소하고 점검했습니다",
        "날카로운 발톱을 조심히 피했습니다",
        "생물들이 차분해졌습니다",
        "건강 상태를 확인하고 기록했습니다"
      ]
    },
    "대강당 준비" => {
      base_pay: 11,
      description: "행사 준비 및 식탁 배치 보조",
      stat: :attack,
      events: [
        "무거운 의자를 나르고 배치했습니다",
        "식탁보를 깔끔하게 펼쳤습니다",
        "장식을 정성껏 달았습니다",
        "촛불 위치를 조정했습니다",
        "바닥을 깨끗이 닦았습니다"
      ]
    },
    "점성술 관측 보조" => {
      base_pay: 17,
      description: "천체 망원경 설치 및 기록 정리",
      stat: :luck,
      events: [
        "망원경을 정확한 각도로 조정했습니다",
        "별의 위치를 차트에 기록했습니다",
        "구름이 걷히기를 기다렸습니다",
        "관측 장비를 점검했습니다",
        "밤하늘이 맑아 관측이 수월했습니다"
      ]
    },
    "변신술 교실 정리" => {
      base_pay: 12,
      description: "변신된 물체 복구 및 교구 정리",
      stat: :agility,
      events: [
        "변신된 물건을 원래대로 되돌렸습니다",
        "교구를 체계적으로 정리했습니다",
        "실수로 변신된 것들을 찾아냈습니다",
        "주문이 남아있는 물건을 조심히 다뤘습니다",
        "교실이 깔끔하게 정돈되었습니다"
      ]
    },
    "기숙사 순찰 보조" => {
      base_pay: 13,
      description: "야간 복도 순찰 및 규율 확인",
      stat: :defense,
      events: [
        "복도를 조용히 순찰했습니다",
        "통행금지 시간을 확인했습니다",
        "어두운 복도에서도 침착했습니다",
        "규칙을 어긴 학생을 발견했습니다",
        "문이 잘 잠겨있는지 확인했습니다"
      ]
    }
  }

  def initialize(client, sheet_manager, notification, sender, job_name)
    @client = client
    @sheet_manager = sheet_manager
    @notification = notification
    @sender = sender.gsub('@', '')
    @job_name = job_name
  end

  def execute
    user = @sheet_manager.find_user(@sender)
    
    unless user
      reply("@#{@sender} 아직 입학하지 않으셨네요!")
      return
    end

    if on_cooldown?(@sender)
      remaining = cooldown_remaining(@sender)
      reply("@#{@sender} 아직 피곤하시군요! #{remaining} 후에 다시 올 수 있어요.")
      return
    end

    job = JOBS[@job_name]
    unless job
      reply("@#{@sender} 그런 아르바이트는 없는데요?")
      return
    end

    result = perform_job(user, job)
    
    @@last_job_time[@sender] = Time.now
    
    message = build_result_message(result, job)
    puts "[알바결과] 메시지 길이: #{message.length}자"
    
    reply(message)
  end

  private

  def reply(text)
    status_id = @notification.dig("status", "id")
    return unless status_id
    
    @client.post_status(text, reply_to_id: status_id, visibility: "unlisted")
  rescue => e
    puts "[답글 에러] #{e.message}"
  end

  def on_cooldown?(user_id)
    return false unless @@last_job_time[user_id]
    elapsed = Time.now - @@last_job_time[user_id]
    elapsed < (COOLDOWN_HOURS * 3600)
  end

  def cooldown_remaining(user_id)
    elapsed = Time.now - @@last_job_time[user_id]
    remaining_seconds = (COOLDOWN_HOURS * 3600) - elapsed
    hours = (remaining_seconds / 3600).floor
    minutes = ((remaining_seconds % 3600) / 60).ceil
    
    hours > 0 ? "약 #{hours}시간 #{minutes}분" : "약 #{minutes}분"
  end

  def perform_job(user, job)
    stat_value = get_stat_value(user, job[:stat])
    
    rolls = []
    total_performance = 0
    
    4.times do |i|
      roll = rand(1..20)
      modified_roll = roll + (stat_value / 5)
      
      critical = (roll == 20)
      fumble = (roll == 1)
      
      performance = calculate_performance(modified_roll, critical, fumble)
      total_performance += performance
      
      rolls << {
        number: i + 1,
        roll: roll,
        modified: modified_roll,
        performance: performance,
        critical: critical,
        fumble: fumble,
        event: job[:events].sample
      }
    end
    
    avg_performance = total_performance / 4.0
    base_pay = job[:base_pay]
    final_pay = (base_pay * (avg_performance / 100.0)).round
    min_pay = (base_pay * 0.1).round
    final_pay = [final_pay, min_pay].max
    
    bonus = check_streak_bonus(rolls)
    final_pay += bonus if bonus > 0
    
    # 갈레온 증가량만 전달
    @sheet_manager.update_galleons(@sender, final_pay)
    
    {
      rolls: rolls,
      avg_performance: avg_performance.round(1),
      base_pay: base_pay,
      final_pay: final_pay,
      bonus: bonus
    }
  end

  def calculate_performance(modified_roll, critical, fumble)
    return 0 if fumble
    return 100 if critical
    
    max_roll = 25
    performance = ((modified_roll - 1) * 100.0 / (max_roll - 1)).round
    [0, [performance, 100].min].max
  end

  def check_streak_bonus(rolls)
    consecutive_high = 0
    max_consecutive = 0
    
    rolls.each do |roll|
      if roll[:performance] >= 80
        consecutive_high += 1
        max_consecutive = [max_consecutive, consecutive_high].max
      else
        consecutive_high = 0
      end
    end
    
    max_consecutive >= 3 ? 5 : 0
  end

  def get_stat_value(user, stat)
    case stat
    when :luck then user[:luck] || 0
    when :agility then user[:agility] || 0
    when :attack then user[:attack] || 0
    when :defense then user[:defense] || 0
    else 0
    end
  end

  def build_result_message(result, job)
    lines = []
    lines << "@#{@sender}"
    lines << "━━━━━━━━━━━━━━━━━━"
    lines << "#{@job_name} 완료"
    lines << "━━━━━━━━━━━━━━━━━━"
    lines << ""
    
    result[:rolls].each do |roll|
      status = if roll[:critical]
                 "[대성공]"
               elsif roll[:fumble]
                 "[실패]"
               elsif roll[:performance] >= 80
                 "[훌륭]"
               elsif roll[:performance] >= 50
                 "[양호]"
               else
                 "[부족]"
               end
      
      lines << "#{roll[:number]}차: [#{roll[:roll]}+보정]=#{roll[:modified]} (#{roll[:performance]}%) #{status}"
      lines << "#{roll[:event]}"
      lines << ""
    end
    
    lines << "━━━━━━━━━━━━━━━━━━"
    lines << "평균 작업률: #{result[:avg_performance]}%"
    lines << "기본급: #{result[:base_pay]}G"
    lines << "보너스: +#{result[:bonus]}G" if result[:bonus] > 0
    lines << "최종: #{result[:final_pay]}G"
    lines << "━━━━━━━━━━━━━━━━━━"
    lines << "쿨타임: #{COOLDOWN_HOURS}시간"
    
    lines.join("\n")
  end
end
