#imports
import notifiers
import datetime
from notifiers import get_notifier

class SlackNotifier:
    
    def __init__(self, hookfile):
        with open(hookfile) as hook:
            lines = hook.readlines()[0]

        self.webhook = ('https://hooks.slack.com/services/'+(lines.rstrip()))
        self.slack = get_notifier('slack')
	
    def notify(self,msg):
        self.slack.notify(message = str(datetime.datetime.now())+': '+msg, webhook_url = self.webhook)
