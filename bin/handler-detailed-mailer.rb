#! /usr/bin/env ruby

require 'sensu-handler'
require 'dhoulmagus/version'
require 'mail'
require 'timeout'
require 'socket'
require 'json'
require 'erb'

# patch to fix Exim delivery_method: https://github.com/mikel/mail/pull/546
module ::Mail
  class Exim < Sendmail
    def self.call(path, arguments, _destinations, encoded_message)
      popen "#{path} #{arguments}" do |io|
        io.puts encoded_message.to_lf
        io.flush
      end
    end
  end
end

class DetailedMailer < Sensu::Handler
  def get_setting(name)
    settings['devops-mailer'][name]
  end

  def short_name(check_ouput)
    check_ouput['client']['name'] + '/' + check_ouput['check']['name']
  end

  def action_to_string
    @event['action'].eql?('resolve') ? 'RESOLVED' : 'ALERT'
  end

  def define_status(status)
    case status
    when '0'
      return 'OK'
    when '1'
      return 'WARNING'
    when '2'
      return 'CRITICAL'
    when '3'
      return 'UNKNOWN'
    else
      return 'ERROR'
    end
  end

  def define_sensu_env
    sensu_server = Socket.gethostname
    if sensu_server.match(/^prd/)
      return 'Prod: '
    elsif sensu_server.match(/^dev/)
      return 'Dev: '
    else
      return 'Test: '
    end
  end

  def template_vars(check_ouput)
    @config = {
      monitored_instance    => check_ouput['client']['name'],
      incident_timestamp    => Time.at(input['check']['issued']),
      instance_address      => check_ouput['client']['address'],
      check_name            => check_ouput['check']['name'],
      check_command         => check_ouput['check']['command'],
      check_state           => define_status(check_ouput['check']['status']),
      num_occurrences       => check_ouput['occurrences'],
      notification_comment  => '#YELLOW', # the comment added to a check to silence it
      notification_author   => '#YELLOW', # the user that silenced the check
      condition_duration    => "#{input['check']['duration']}s",
      check_output          => '#YELLOW',
      sensu_env             => define_sensu_env,
      alert_type            => action_to_string,
      notification_type     => alert_type,
      orginator             => 'sensu-monitoring',
      flapping              => '#YELLOW' # is the check flapping
    }
  end

  def acquire_template(input)
    File.read(input)
  end

  def handle
    check_output = JSON.parse(STDIN.read)

    mail_to                   = get_setting('mail_to')
    mail_from                 = get_setting('mail_from')

    delivery_method           = get_setting('delivery_method') || 'smtp'
    smtp_address              = get_setting('smtp_address') || 'localhost'
    smtp_port                 = get_setting('smtp_port') || '25'
    smtp_domain               = get_setting('smtp_domain') || 'localhost.localdomain'

    smtp_username             = get_setting('smtp_username') || nil
    smtp_password             = get_setting('smtp_password') || nil
    smtp_authentication       = get_setting('smtp_authentication') || :plain
    smtp_enable_starttls_auto = get_setting('smtp_enable_starttls_auto') == 'false' ? false : true

    subject = "#{define_sensu_env} #{action_to_string}  #{check_output['check']['name']} on #{check_output['client']['name']} is #{check_output['check']['status']}"

    # YELLOW
    gem_base = `/opt/sensu/embedded/bin/gem environment gemdir`.gsub("\n", '')
    template_path = "#{gem_base}/gems/dhoulmagus-#{Dhoulmagus::Version::STRING}/templates"

    Mail.defaults do
      delivery_options = {
        address: smtp_address,
        port: smtp_port,
        domain: smtp_domain,
        openssl_verify_mode: 'none',
        enable_starttls_auto: smtp_enable_starttls_auto
      }

      unless smtp_username.nil?
        auth_options = {
          user_name: smtp_username,
          password: smtp_password,
          authentication: smtp_authentication
        }
        delivery_options.merge! auth_options
      end

      delivery_method delivery_method.intern, delivery_options
    end

    begin
      template_vars(check_output)
      timeout 10 do
        Mail.deliver do
          to mail_to
          from mail_from
          subject subject
          content_type 'text/html; charset=UTF-8'
          template = "#{template_path}/sensu/base_email.erb"
          body ERB.new(File.read(template)).result
        end

        puts 'mail -- sent alert for ' + short_name + ' to ' + mail_to.to_s
      end
    rescue Timeout::Error
      puts 'mail -- timed out while attempting to ' + check_output['action'] + ' an incident -- ' + short_name(check_output)
    end
  end
end
