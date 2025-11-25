# command_parser.rb
require_relative 'commands/job_list_command'
require_relative 'commands/job_start_command'
require_relative 'commands/wallet_command'

class CommandParser
  def initialize(mastodon_client, sheet_manager)
    @mastodon_client = mastodon_client
    @sheet_manager = sheet_manager
    
    @job_list_command = JobListCommand.new(mastodon_client, sheet_manager)
    @job_start_command = JobStartCommand.new(mastodon_client, sheet_manager)
    @wallet_command = WalletCommand.new(mastodon_client, sheet_manager)
  end

  def parse(notification)
    status = notification['status']
    return unless status
    
    account = notification['account']
    sender = account['acct'].split('@').first
    
    content = clean_html(status['content'])
    
    puts "[파서] @#{sender}: #{content}"
    
    case content
    when /\[알바목록\]/i
      @job_list_command.execute(sender, status)
      
    when /\[알바시작\/(.+?)\]/i
      job_name = $1.strip
      @job_start_command.execute(sender, job_name, status)
      
    when /\[지갑\]/i
      @wallet_command.execute(sender, status)
      
    else
      puts "[무시] 알 수 없는 명령어"
    end
    
  rescue => e
    puts "[에러] 명령어 처리 실패: #{e.message}"
    puts e.backtrace.first(3)
  end

  private

  def clean_html(html)
    html.gsub(/<[^>]*>/, '').strip
  end
end
