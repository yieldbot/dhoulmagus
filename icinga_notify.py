#! /usr/bin/env python

'''

    icinga_notify.py
    Matt Jones caffeinatedengineering@gmail.com
    Created 02.26.14
    Last Update 04.09.14n

    Notes:


    Usage:


    ToDo:


'''

import os
import argparse
import sys
import smtplib
import socket
from email.MIMEMultipart import MIMEMultipart
from email.MIMEText import MIMEText
from email.MIMEImage import MIMEImage
import jinja2

HostName = socket.gethostname()
HostName = HostName.split('.')
HostName = HostName[0]
IcingaServer = HostName

if 'test' in IcingaServer:
  Header = 'IcingaTest: '

elif 'qa' in IcingaServer:
  Header = 'IcingaQA: '
elif 'prod' in IcingaServer:
  Header = 'IcingaProd: '
else:
  Header = 'Icinga:'

reply_to_address = 'alerts-goc@monster.com'

def create_msg(template_vars, alert, _To):
  MailSender = 'Icinga Monitoring <svcicinga@' + HostName +'.be.monster.com>'
  msg = MIMEMultipart()
  msg['From'] = MailSender
  msg['To'] = _To
  msg.add_header('reply-to', reply_to_address)
  templateLoader = jinja2.FileSystemLoader( searchpath="/" )
  templateEnv = jinja2.Environment( loader=templateLoader )
  if alert == "service":
    msg['Subject'] = Header + g_NotificationType +  g_ServiceName + " on " + g_HostName + " is " + g_ServiceState
    template_file = "/usr/local/icingadata/store/icinga_management_scripts/templates/service_email.jinja"
  elif alert == "host":
    msg['Subject'] = Header + g_NotificationType + ' Host ' + g_HostName + ' is ' +  g_HostState
    template_file = "/usr/local/icingadata/store/icinga_management_scripts/templates/host_email.jinja"
  template = templateEnv.get_template( template_file )
  output_text = template.render( template_vars )
  body = MIMEText(output_text, 'HTML')
  msg.attach(body)
  send_msg(msg, MailSender, _To)

def send_msg(msg, MailSender, _To):
    s = smtplib.SMTP('localhost')
    s.sendmail(MailSender, _To, msg.as_string())
    s.quit()

def main():

  global g_NotificationType
  global g_ServiceName
  global g_ServiceState
  global g_HostName
  global g_HostState

  parser = argparse.ArgumentParser(description='Icinga notification email')
  parser.add_argument('notification_type', help='The type (critical, warning, good, unknown)')
  parser.add_argument('host_name', help='The name of the host alerting')
  parser.add_argument('--host_state', help='The host state')
  parser.add_argument('host_group', help='The host groups')
  parser.add_argument('ip_address', help='The IP address of the host alerting')
  parser.add_argument('event_time', help='The time of the service check')
  parser.add_argument('escalated', help='Is this an escalated notification')
  parser.add_argument('to', help='This is who will receive the notification')
  parser.add_argument('contact_group', help='This is the group receiving the notification')
  parser.add_argument('--host_output', help='the short host output')
  parser.add_argument('--host_data', help='the long host output')
  parser.add_argument('--host_duration', help='The length of time a host has been in this state')
  parser.add_argument('--service_name', help='The name of the service alerting')
  parser.add_argument('--service_group', help='The service groups')
  parser.add_argument('--service_data', help='the long service output')
  parser.add_argument('--service_state', help='The state (critical, warning, good, unknown)')
  parser.add_argument('--service_output', help='The short service output')
  parser.add_argument('--service_duration', help='The length of time a service has been in this state')
  parser.add_argument('--notification_comment', help='The comment associated with the host ack')
  parser.add_argument('--notification_author', help='The author of the host ack')
  parser.add_argument('--business_hours_ins', help='GOC instructions for business hours')
  parser.add_argument('--after_hours_ins', help='GOC instructions for after hours')
  args = vars(parser.parse_args())

  if args['notification_type'] == 'PROBLEM':
      g_NotificationType = 'Alert'
  elif args['notification_type'] == 'RECOVERY':
      g_NotificationType = 'Clear'
  else:
      g_NotificationType = args['notification_type']

  g_ServiceName = args['service_name']
  _ServiceDuration = args['service_duration']
  _HostDuration = args['host_duration']
  _ServiceGroup = args['service_group']
  g_ServiceState = args['service_state']
  _ServiceOutput = args['service_output']

  if args['service_data']:
    _ServiceData = args['service_data']
  else:
    _ServiceData = 'None'

  g_HostName = args['host_name']
  _To = args['to']
  _ContactGroup = args['contact_group']
  g_HostState = args['host_state']
  _HostOutput = args['host_output']

  if args['host_data']:
    _HostData = args['host_data']
  else:
    _HostData = 'None'

  _HostGroup = args['host_group']
  _IPAddress = args['ip_address']
  _EventTime = args['event_time']

  if Header != 'IcingaProd: ':
    if args['escalated'] == '0':
      _Escalated = 'This message is NON-ACTIONABLE and has not been seen by the GOC'
    elif args['escalated'] == '1':
      _Escalated = 'This is ACTIONABLE and the app owner has been aware for 24 hours'
  else:
    _Escalated = 'This is an ACTIONABLE alert'

  if args['notification_comment']:
    _NotificationComment = args['notification_comment']
    _NotificationAuthor = args['notification_author']
  else:
    _NotificationComment = 'None'
    _NotificationAuthor = 'None'

  if args['business_hours_ins']:
    _BusinessHoursIns = args['business_hours_ins']
  else:
    _BusinessHoursIns = 'None'

  if args['after_hours_ins']:
    _AfterHoursIns = args['after_hours_ins']
  else:
    _AfterHoursIns = 'None'


  if not g_ServiceName:
    alert = "host"
    template_vars = { "NotificationType" : g_NotificationType,
                     "HostName" : g_HostName,
                     "HostState" : g_HostState,
                     "HostOutput" : _HostOutput,
                     "HostData" : _HostData,
                     "HostDuration" : _HostDuration,
                     "HostGroup" : _HostGroup,
                     "IPAddress" : _IPAddress,
                     "EventTime" : _EventTime,
                     "IcingaServer" : IcingaServer,
                     "NotificationComment" : _NotificationComment,
                     "NotificationAuthor" : _NotificationAuthor,
                     "AfterHoursIns" : _AfterHoursIns,
                     "BusinessHoursIns": _BusinessHoursIns,
                     "IcingaEnv": Header,
                     "ContactGroup": _ContactGroup,
                     "Escalated" : _Escalated }
  else:
    alert = "service"
    template_vars = { "NotificationType" : g_NotificationType,
                     "ServiceName" : g_ServiceName,
                     "ServiceGroup" : _ServiceGroup,
                     "ServiceState" : g_ServiceState,
                     "ServiceOutput" : _ServiceOutput,
                     "ServiceData" : _ServiceData,
                     "ServiceDuration" : _ServiceDuration,
                     "HostName" : g_HostName,
                     "AfterHoursIns" : _AfterHoursIns,
                     "BusinessHoursIns": _BusinessHoursIns,
                     "HostGroup" : _HostGroup,
                     "IPAddress" : _IPAddress,
                     "EventTime" : _EventTime,
                     "ContactGroup": _ContactGroup,
                     "IcingaServer" : IcingaServer,
                     "NotificationComment" : _NotificationComment,
                     "NotificationAuthor" : _NotificationAuthor,
                     "IcingaEnv": Header,
                     "Escalated" : _Escalated }

  create_msg(template_vars, alert, _To)

if __name__ == '__main__':
  main()
