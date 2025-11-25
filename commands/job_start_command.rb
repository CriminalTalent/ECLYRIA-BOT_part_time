# commands/job_start_command.rb
require 'time'

class JobStartCommand
  # 쿨타임 관리 (user_id => 마지막 알바 시간)
  @@last_job_time = {}
  COOLDOWN_HOURS = 2

  JOBS = {
    "도서관 사서 보조" => {
      base_pay: 10,
      description: "마담 핀스를 도와 책을 정리합니다",
      stat: :luck,
      events: [
        "책을 정리하던 중 오래된 마법서를 발견했습니다",
        "먼지가 많아 재채기가 나왔지만 열심히 했습니다",
        "금지된 서가 근처를 조심스럽게 정리했습니다",
        "마담 핀스가 만족스러워 하십니다"
      ]
    },
    "온실 관리 조수" => {
      base_pay: 15,
      description: "스프라우트 교수의 식물들을 돌봅니다",
      stat: :agility,
      events: [
        "만드레이크가 소리를 질렀지만 잘 대처했습니다",
        "물을 주다가 악마의 올가미에 살짝 걸렸습니다",
        "식물들이 건강하게 자라고 있습니다",
        "스프라우트 교수님께 칭찬을 들었습니다"
      ]
    },
    "우편배달" => {
      base_pay: 12,
      description: "부엉이 우편을 분류하고 배달합니다",
      stat: :agility,
      events: [
        "부엉이가 발을 물었지만 배달은 완료했습니다",
        "비 오는 날이었지만 무사히 배달했습니다",
        "편지를 깔끔하게 분류했습니다",
        "부엉이들과 친해진 것 같습니다"
      ]
    },
    "퀴디치 용품 관리" => {
      base_pay: 13,
      description: "후치 선생님의 장비를 정리합니다",
      stat: :attack,
      events: [
        "빗자루를 깔끔하게 정비했습니다",
        "공을 정리하다가 블러저에 맞을 뻔했습니다",
        "장비들을 완벽하게 정돈했습니다",
        "후치 선생님께서 고맙다고 하셨습니다"
      ]
    }
  }

  def initialize(mastodon_client, sheet_manager)
    @mastodon_client = mastodon_client
    @sheet_manager = sheet_manager
  end

  def execute(user_id, job_name, reply_status)
    user = @sheet_manager.find_user(user_id)
    
    unless user
      @mastodon_client.reply(
        "@#{user_id} 아직 입학하지 않으셨네요!",
        reply_status['id']
      )
      return
    end

    # 쿨타임 체크
    if on_cooldown?(user_id)
      remaining = cooldown_remaining(user_id)
      @mastodon_client.reply(
        "@#{user_id} 아직 피곤하시군요! #{remaining}분 후에 다시 올 수 있어요.",
        reply_status['id']
      )
      return
    end

    # 작업 찾기
    job = JOBS[job_name]
    unless job
      @mastodon_client.reply(
        "@#{user_id} 그런 아르바이트는 없는데요? [알바목록]으로 확인해보세요!",
        reply_status['id']
      )
      return
    end

    # 아르바이트 실행
    result = perform_job(user, job, job_name)
    
    # 쿨타임 기록
    @@last_job_time[user_id] = Time.now
    
    # 결과 메시지 전송
    message = build_result_message(user_id, user[:name] || user_id, job_name, result)
    @mastodon_client.reply(message, reply_status['id'])
  end

  private

  def on_cooldown?(user_id)
    return false unless @@last_job_time[user_id]
    
    elapsed = Time.now - @@last_job_time[user_id]
    elapsed < (COOLDOWN_HOURS * 3600)
  end

  def cooldown_remaining(user_id)
    elapsed = Time.now - @@last_job_time[user_id]
    remaining_seconds = (COOLDOWN_HOURS * 3600) - elapsed
    (remaining_seconds / 60).ceil
  end

  def perform_job(user, job, job_name)
    stat_value = get_stat_value(user, job[:stat])
    
    # 4번의 작업 판정
    rolls = []
    total_performance = 0
    
    4.times do |i|
      roll = rand(1..20)
      modified_roll = roll + (stat_value / 5)  # 스탯 보너스
      
      # 크리티컬/대실패
      critical = (roll == 20)
      fumble = (roll == 1)
      
      performance = calculate_performance(modified_roll, critical, fumble)
      total_performance += performance
      
      event = job[:events].sample
      
      rolls << {
        number: i + 1,
        roll: roll,
        modified: modified_roll,
        performance: performance,
        critical: critical,
        fumble: fumble,
        event: event
      }
    end
    
    # 평균 작업 능률
    avg_performance = total_performance / 4.0
    
    # 최종 급여 계산
    base_pay = job[:base_pay]
    final_pay = (base_pay * (avg_performance / 100.0)).round
    
    # 3연속 고득점 보너스 체크
    bonus = check_streak_bonus(rolls)
    final_pay += bonus if bonus > 0
    
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
    
    # 수정된 굴림값을 백분율로 변환 (1-25 범위를 0-100%로)
    performance = ((modified_roll - 1) * 100.0 / 24.0).round
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
    
    return 5 if max_consecutive >= 3
    0
  end

  def get_stat_value(user, stat)
    case stat
    when :luck then (user[:luck] || user["행운"] || 0).to_i
    when :agility then (user[:agility] || user["민첩"] || 0).to_i
    when :attack then (user[:attack] || user["공격"] || 0).to_i
    when :defense then (user[:defense] || user["방어"] || 0).to_i
    else 0
    end
  end

  def build_result_message(user_id, name, job_name, result)
    lines = []
    lines << "@#{user_id}"
    lines << "━━━━━━━━━━━━━━━━━━"
    lines << "#{job_name} 완료!"
    lines << "━━━━━━━━━━━━━━━━━━"
    lines << ""
    
    result[:rolls].each do |roll|
      status = if roll[:critical]
                 "대성공!"
               elsif roll[:fumble]
                 "실패..."
               elsif roll[:performance] >= 80
                 "훌륭함"
               elsif roll[:performance] >= 50
                 "괜찮음"
               else
                 "아쉬움"
               end
      
      lines << "작업 #{roll[:number]}: [#{roll[:roll]}+보너스] = #{roll[:modified]} → #{roll[:performance]}% #{status}"
      lines << "   #{roll[:event]}"
      lines << ""
    end
    
    lines << "━━━━━━━━━━━━━━━━━━"
    lines << "평균 작업 능률: #{result[:avg_performance]}%"
    lines << "기본 보수: #{result[:base_pay]}갈레온"
    
    if result[:bonus] > 0
      lines << "연속 우수 보너스: +#{result[:bonus]}갈레온"
    end
    
    lines << "최종 급여: #{result[:final_pay]}갈레온"
    lines << "━━━━━━━━━━━━━━━━━━"
    lines << ""
    lines << "다음 알바: #{COOLDOWN_HOURS}시간 후"
    
    lines.join("\n")
  end
end
