from django.db import models
from django.db.models.query import QuerySet
from django.contrib.contenttypes.models import ContentType
from picklefield.fields import PickledObjectField

# Implementation of http://djangosnippets.org/snippets/1034/
class JobQuerySet(QuerySet):
    def __getitem__(self, k):
        result = super(JobQuerySet, self).__getitem__(k)
        if isinstance(result, models.Model) :
            return result.as_leaf_class()
        else :
            return result
    def __iter__(self):
        for item in super(JobQuerySet, self).__iter__():
            yield item.as_leaf_class()

class JobManager(models.Manager):
    def get_query_set(self):
        return JobQuerySet(self.model)

class Job(models.Model):
   objects = JobManager()
   def __unicode__(self):
    return self.name
   def save(self, *args, **kwargs):
       if(not self.content_type):
           self.content_type = ContentType.objects.get_for_model(self.__class__)
       super(Job, self).save(*args, **kwargs)
   def as_leaf_class(self):
       content_type = self.content_type
       model = content_type.model_class()
       if (model == Job):
           return self
       return model.objects.get(id=self.id)
	
   content_type = models.ForeignKey(ContentType,editable=False,null=True)
   name = models.CharField(max_length=1024)
   STATUSC = ( ('new','New'), ('disp','Dispatched'), ('done', 'Done'), ('err', 'Error') )
   status = models.CharField(choices=STATUSC,default='new',max_length=10)
   output = models.TextField()
   SCHEDULEC = ( ('once','Once'), ('perm','Permanent'))
   schedule = models.CharField(choices=STATUSC,default='once',max_length=9)
   data = PickledObjectField()
   timestamp = models.DateTimeField(auto_now=True)
   class Meta: 
     get_latest_by = 'timestamp'
#    abstract = True

class ShellJob(Job):
   objects = JobManager()
   def __unicode__(self):
    return self.name
   def execText(self):
    #return self.shell+' -c'+self.command+' '+self.args
    return self.command
   command = models.CharField(max_length=1024)

class PuppetJob(Job):
   objects = JobManager()
   def __unicode__(self):
    return self.name
#TBD: MODULESC = ls git/modules/ + new
   def execText(self):
    return "puppet apply -e 'include " + self.module + "'"
   module = models.CharField(max_length=1024)

class HieraJob(Job):
   objects = JobManager()
   def __unicode__(self):
    return self.name
   def execText(self):
     return '/bin/false'
   sourcetype = models.CharField(max_length=16)
   filename = models.CharField(max_length=1024, default=sourcetype)
