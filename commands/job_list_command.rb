# commands/job_list_command.rb

class JobListCommand
  # 일반 아르바이트 목록
  REGULAR_JOBS = [
    {
      name: "도서관 사서 보조",
      time: "2시간",
      base_pay: 10,
      description: "고서 정리와 금지 서가 목록 관리",
      stat: :luck
    },
    {
      name: "온실 관리 조수",
      time: "2시간",
      base_pay: 15,
      description: "3학년 실습용 마법 식물 관리",
      stat: :agility
    },
    {
      name: "우편배달",
      time: "2시간",
      base_pay: 12,
      description: "부엉이 우편 분류 및 긴급 배달",
      stat: :agility
    },
    {
      name: "퀴디치 용품 관리",
      time: "2시간",
      base_pay: 13,
      description: "경기용 장비 점검 및 정비",
      stat: :attack
    },
    {
      name: "물약 재료 준비",
      time: "2시간",
      base_pay: 14,
      description: "고급 물약 재료 세척과 보관",
      stat: :luck
    },
    {
      name: "마법 생물 돌보기",
      time: "2시간",
      base_pay: 16,
      description: "3학년 수업용 마법 생물 관리",
      stat: :defense
    },
    {
      name: "대강당 준비",
      time: "2시간",
      base_pay: 11,
      description: "행사 준비 및 식탁 배치 보조",
      stat: :attack
    },
    {
      name: "점성술 관측 보조",
      time: "2시간",
      base_pay: 17,
      description: "천체 망원경 설치 및 기록 정리",
      stat: :luck
    },
    {
      name: "변신술 교실 정리",
      time: "2시간",
      base_pay: 12,
      description: "변신된 물체 복구 및 교구 정리",
      stat: :agility
    },
    {
      name: "기숙사 순찰 보조",
      time: "2시간",
      base_pay: 13,
      description: "야간 복도 순찰 및 규율 확인",
      stat: :defense
    }
  ]

  def initialize(mastodon_client, sheet_manager)
    @mastodon_client = mastodon_client
    @sheet_manager = sheet_manager
  end

  def execute(user_id, reply_status)
    user = @sheet_manager.find_user(user_id)
    
    unless user
      @mastodon_client.reply(
        "@#{user_id} 아직 입학하지 않으셨네요. 먼저 교수님께 입학 신청을 해주세요!",
        reply_status['id']
      )
      return
    end

    message = build_job_list_message(user_id)
    @mastodon_client.reply(message, reply_status['id'])
  end

  private

  def build_job_list_message(user_id)
    lines = []
    lines << "@#{user_id}"
    lines << "━━━━━━━━━━━━━━━━━━"
    lines << "호그와트 아르바이트"
    lines << "━━━━━━━━━━━━━━━━━━"
    lines << ""

    REGULAR_JOBS.each do |job|
      stat_text = stat_korean(job[:stat])
      lines << "#{job[:name]}(#{job[:base_pay]}G/#{stat_text})"
    end

    lines << ""
    lines << "━━━━━━━━━━━━━━━━━━"
    lines << "[알바시작/이름]으로 시작"
    
    message = lines.join("\n")
    
    # 메시지 길이 체크 및 출력
    puts "[알바목록] 메시지 길이: #{message.length}자"
    
    message
  end

  def stat_korean(stat)
    case stat
    when :luck then "행운"
    when :agility then "민첩"
    when :attack then "공격"
    when :defense then "방어"
    else "행운"
    end
  end
end
