#! /usr/bin/env ruby

require 'sensu-handler'
require 'dhoulmagus/version'
require 'mail'
require 'timeout'
require 'socket'
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

  def define_check_state_duration
    ''
  end

  def short_name
    "#{monitored_instance}/#{check_name}"
  end

  def define_notification_type
    case @event['action']
    when 'resolve'
      return 'CLEAR'
    when 'create'
      return 'ALERT'
    when 'flapping'
      return 'FLAPPING'
    else
      return 'NOTICE'
    end
  end

  def define_status
    case @event['check']['status']
    when 0
      return 'OK'
    when 1
      return 'WARNING'
    when 2
      return 'CRITICAL'
    when 3
      return 'UNKNOWN'
    when 127
      return 'CONFIG ERROR'
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
    elsif sensu_server.match(/^FOO/)
      return 'Stg: '
    elsif sensu_server.match(/^BAR/)
      return 'KitchenCI: '
    elsif sensu_server.match(/^vagrant/)
      return 'Vagrant: '
    else
      return 'Test: '
    end
  end

  def define_source
    'sensu'
  end

  def template_vars
    @config = {
      'monitored_instance'    => @event['client']['name'], # this will be the snmp host if using traps
      'sensu-client'          => @event['client']['name'],
      'incident_timestamp'    => Time.at(@event['check']['issued']),
      'instance_address'      => @event['client']['address'],
      'check_name'            => @event['check']['name'],
      'check_state'           => define_status,
      'check_data'            => '', # any additional user supplied data
      'notification_comment'  => '', # the comment added to a check to silence it
      'notification_author'   => '', # the user that silenced the check
      'check_output'          => @event['check']['output'],
      'sensu_env'             => define_sensu_env,
      'notification_type'     => define_notification_type,
      'source'                => define_source,
      'check_state_duration'  => define_check_state_duration
    }
  end

  def define_mail_settings
    @mail_settings = {
      'mail_to'                   => get_setting('mail_to'),
      'mail_from'                 => get_setting('mail_from'),

      'delivery_method'           => get_setting('delivery_method') || 'smtp',
      'smtp_address'              => get_setting('smtp_address') || 'localhost',
      'smtp_port'                 => get_setting('smtp_port') || '25',
      'smtp_domain'               => get_setting('smtp_domain') || 'localhost.localdomain',

      'smtp_username'             => get_setting('smtp_username') || nil,
      'smtp_password'             => get_setting('smtp_password') || nil,
      'smtp_authentication'       => get_setting('smtp_authentication') || :plain,
      'smtp_enable_starttls_auto' => get_setting('smtp_enable_starttls_auto') == 'false' ? false : true
    }
  end

  def handle
    define_mail_settings

    # YELLOW
    gem_base = `/opt/sensu/embedded/bin/gem environment gemdir`.gsub("\n", '')
    @template_path = "#{gem_base}/gems/dhoulmagus-#{Dhoulmagus::Version::STRING}/templates/sensu"
    template = "#{@template_path}/base_email.erb"
    template_vars
    renderer = ERB.new(File.read(template))
    msg = renderer.result(binding)
    subject = "#{define_sensu_env} #{define_notification_type}  #{@config['check_name']} on #{@config['monitored_instance']} is #{@config['check_state']}"

    Mail.defaults do
      delivery_options = {
        address: @mail_settings['smtp_address'],
        port: @mail_settings['smtp_port'],
        domain: @mail_settings['smtp_domain'],
        openssl_verify_mode: 'none',
        enable_starttls_auto: @mail_settings['smtp_enable_starttls_auto']
      }

      unless smtp_username.nil?
        auth_options = {
          user_name: @mail_settings['smtp_username'],
          password: @mail_settings['smtp_password'],
          authentication: @mail_settings['smtp_authentication']
        }
        delivery_options.merge! auth_options
      end

      delivery_method delivery_method.intern, delivery_options
    end

    begin
      timeout 10 do
        Mail.deliver do
          to @mail_settings['mail_to']
          from @mail_settings['mail_from']
          subject subject
          content_type 'text/html; charset=UTF-8'
          body msg
        end

        puts 'mail -- sent alert for ' + short_name + ' to ' + @mail_settings['mail_to'].to_s
      end
    rescue Timeout::Error
      puts 'mail -- timed out while attempting to ' + define_notification_type + ' an incident -- ' + short_name
    end
  end
end
