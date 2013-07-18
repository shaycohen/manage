from django.db import models
from dug.jobs import Job

class Client(models.Model):
   def __unicode__(self):
    return self.hwaddr
   jobs = models.ManyToManyField(Job)
   hwaddr = models.CharField(max_length=18)
   name = models.CharField(max_length=64)
