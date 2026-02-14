# command_parser.rb
# encoding: UTF-8
require 'cgi'
require_relative 'commands/job_start_command'

module CommandParser
  def self.parse(client, sheet_manager, notification)
    content_raw = notification.dig("status", "content") || ""
    sender = notification.dig("account", "acct") || ""
    
    content = clean_html(content_raw)
    
    puts "[파서] @#{sender}: #{content}"

    case content
    when /\[알바시작\/(.+?)\]/
      job_name = $1.strip
      JobStartCommand.new(client, sheet_manager, notification, sender, job_name).execute
    else
      puts "[파서] 인식 불가"
    end

  rescue => e
    puts "[에러] 명령어 처리 실패: #{e.message}"
    puts e.backtrace.first(5).join("\n")
  end

  def self.clean_html(html)
    return "" if html.nil?
    s = html.gsub(/<br\s*\/?>/i, "\n")
           .gsub(/<\/p>/i, "\n")
           .gsub(/<[^>]*>/, "")
    CGI.unescapeHTML(s).gsub("\u00A0", " ").strip
  rescue
    html.to_s
  end
end
